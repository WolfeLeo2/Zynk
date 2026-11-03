#!/usr/bin/env bash
# End-to-end checks for the Edge Functions through the local gateway (so the
# verify_jwt settings in config.toml apply). Needs the stack running with
# functions enabled and the Acme seed loaded: supabase/tests/run_local.sh first.
set -euo pipefail
cd "$(dirname "$0")/../.."

env_json=$(supabase status --env)
get() { python3 -c "import json,sys; print(json.loads(sys.argv[1])['$1'])" "$env_json"; }
API=$(get API_URL); ANON=$(get ANON_KEY); SERVICE=$(get SERVICE_ROLE_KEY); DB=$(get DB_URL)
ACME=caf40f8e-d521-468d-820b-3408e354b1fb
EMAIL=edge-test@zynk.local; PASSWORD=edge-test-password
fail=0

# call <function> <token> <json> → prints "<status> <body>"
# One retry on no response (000): the local runtime's per_worker policy recycles
# a worker at its wall-clock limit and can drop a request in flight. A real
# failure always has a status code, so it isn't retried.
call() {
  local auth=() code; [ -n "$2" ] && auth=(-H "Authorization: Bearer $2")
  for _ in 1 2; do
    : > /tmp/zynk_edge_body
    code=$(curl -s --max-time 30 -o /tmp/zynk_edge_body -w '%{http_code}' -X POST "$API/functions/v1/$1" \
      -H "apikey: $ANON" -H 'Content-Type: application/json' ${auth[@]+"${auth[@]}"} -d "$3")
    [ "$code" != 000 ] && break
  done
  printf '%s %s' "$code" "$(cat /tmp/zynk_edge_body)"
}
expect() { # expect <name> <status> <body-substring> <actual>
  if [[ "$4" == "$2 "*"$3"* ]]; then echo "ok   $1"; else echo "FAIL $1: $4"; fail=1; fi
}

# A signed-in Owner of Acme.
curl -s -o /dev/null -X POST "$API/auth/v1/admin/users" -H "apikey: $SERVICE" -H "Authorization: Bearer $SERVICE" \
  -H 'Content-Type: application/json' -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"email_confirm\":true}"
USER_ID=$(psql "$DB" -Atc "select id from auth.users where email = '$EMAIL'")
psql "$DB" -qc "insert into profiles (user_id, tenant_id, role) select '$USER_ID', '$ACME', 'Owner'
  where not exists (select 1 from profiles where user_id = '$USER_ID')"
TOKEN=$(curl -s -X POST "$API/auth/v1/token?grant_type=password" -H "apikey: $ANON" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')

# Same claims as the real token, signature from somewhere else: what an attacker sends.
FORGED="$(cut -d. -f1-2 <<<"$TOKEN").$(printf 'forged' | base64 | tr -d '=' | tr '/+' '_-')"

read -r BRANCH PRODUCT < <(psql "$DB" -At -F' ' -c "select branch_id, product_id from stock
  where tenant_id = '$ACME' and quantity > 5 order by product_id limit 1")
OTHER_TENANT=$(psql "$DB" -Atc "insert into tenants (name) values ('Other') returning id" | head -1)
items="[{\"product_id\":\"$PRODUCT\",\"quantity\":1.5,\"unit_price\":33.33,\"product_name\":\"T\"}]"

# ── create-invoice (verify_jwt = true) ──
invoice="{\"tenant_id\":\"$ACME\",\"branch_id\":\"$BRANCH\",\"salesperson_id\":\"$USER_ID\",\"items\":$items,\"grand_total\":49.995}"
expect "create-invoice: valid token"        200 'INV-'          "$(call create-invoice "$TOKEN" "$invoice")"
expect "create-invoice: forged token"       401 ''              "$(call create-invoice "$FORGED" "$invoice")"
expect "create-invoice: no token"           401 ''              "$(call create-invoice '' "$invoice")"
expect "create-invoice: wrong total"        400 'TOTAL_MISMATCH' "$(call create-invoice "$TOKEN" "${invoice/49.995/10}")"
expect "create-invoice: other tenant"       403 'Profile not found' "$(call create-invoice "$TOKEN" "${invoice/$ACME/$OTHER_TENANT}")"

# ── manage-stock-adjustment (verify_jwt = true) ──
BUNDLE=$(psql "$DB" -Atc "select gen_random_uuid()")
psql "$DB" -qc "insert into stock_adjustments (tenant_id, branch_id, product_id, adjustment_type, quantity, bundle_id)
  values ('$ACME', '$BRANCH', '$PRODUCT', 'addition', 2, '$BUNDLE')"
before=$(psql "$DB" -Atc "select quantity from stock where branch_id = '$BRANCH' and product_id = '$PRODUCT'")
approve="{\"action\":\"approve_adjustment\",\"tenant_id\":\"$ACME\",\"bundle_id\":\"$BUNDLE\"}"
expect "stock-adjustment: forged token"     401 ''              "$(call manage-stock-adjustment "$FORGED" "$approve")"
expect "stock-adjustment: other tenant"     403 'Profile not found' "$(call manage-stock-adjustment "$TOKEN" "${approve/$ACME/$OTHER_TENANT}")"
expect "stock-adjustment: approve"          200 '"count":1'     "$(call manage-stock-adjustment "$TOKEN" "$approve")"
expect "stock-adjustment: approve twice"    500 'No pending'    "$(call manage-stock-adjustment "$TOKEN" "$approve")"
after=$(psql "$DB" -Atc "select quantity from stock where branch_id = '$BRANCH' and product_id = '$PRODUCT'")
expect "stock-adjustment: stock +2 once"    ok ''            "$(python3 -c "print('ok ' if abs($after - $before - 2) < 1e-9 else 'got $before -> $after')")"
expect "stock-adjustment: unapprove"        200 'unapproved'    "$(call manage-stock-adjustment "$TOKEN" "${approve/approve_adjustment/unapprove_adjustment}")"

# ── complete-sale (verify_jwt = true on live too) ──
sale="{\"tenant_id\":\"$ACME\",\"branch_id\":\"$BRANCH\",\"items\":$items,\"payment_method\":\"cash\",\"grand_total\":49.995}"
expect "complete-sale: valid token"         200 'RCT-'          "$(call complete-sale "$TOKEN" "$sale")"
expect "complete-sale: other tenant"        403 'Profile not found' "$(call complete-sale "$TOKEN" "${sale/$ACME/$OTHER_TENANT}")"
expect "complete-sale: forged token"        401 ''              "$(call complete-sale "$FORGED" "$sale")"

# ── manage-sale: invoice edit + tenant guard ──
INV=$(call create-invoice "$TOKEN" "$invoice" | sed -E 's/.*"sale_id":"([^"]+)".*/\1/')
edit="{\"action\":\"update_draft\",\"sale_id\":\"$INV\",\"tenant_id\":\"$ACME\",\"customer_id\":null,\"salesperson_id\":\"$USER_ID\",\"items\":[{\"product_id\":\"$PRODUCT\",\"quantity\":0.5,\"unit_price\":33.33,\"total\":999}]}"
edit=${edit/\"customer_id\":null/\"customer_id\":\"$(psql "$DB" -Atc "select id from customers where tenant_id = '$ACME' limit 1")\"}
expect "manage-sale: edit recomputes total" 200 '"grand_total":16.67' "$(call manage-sale "$TOKEN" "$edit")"
stored=$(psql "$DB" -Atc "select grand_total from sales where id = '$INV'")
expect "manage-sale: stored total"          ok ''               "$(python3 -c "print('ok ' if $stored == 16.67 else 'got $stored')")"
# Another tenant's invoice, with this user's own tenant_id: refused for every action.
OTHER_BRANCH=$(psql "$DB" -Atc "insert into branches (tenant_id, name) values ('$OTHER_TENANT', 'B') returning id" | head -1)
OTHER_SALE=$(psql "$DB" -Atc "insert into sales (tenant_id, branch_id, status, sale_type, grand_total) values ('$OTHER_TENANT', '$OTHER_BRANCH', 'pending_approval', 'invoice', 100) returning id" | head -1)
expect "manage-sale: edit other tenant's"   403 'does not belong' "$(call manage-sale "$TOKEN" "${edit/$INV/$OTHER_SALE}")"
approve_other=$(printf '{"action":"approve_sale","sale_id":"%s","tenant_id":"%s"}' "$OTHER_SALE" "$ACME")
approve_other_no_tenant=$(printf '{"action":"approve_sale","sale_id":"%s"}' "$OTHER_SALE")
expect "manage-sale: approve other tenant's" 403 'does not belong' "$(call manage-sale "$TOKEN" "$approve_other")"
expect "manage-sale: no tenant_id → own"    403 'Profile not found' "$(call manage-sale "$TOKEN" "$approve_other_no_tenant")"

exit $fail
