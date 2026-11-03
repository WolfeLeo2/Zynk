#!/usr/bin/env bash
# Re-sync the local stack with the live project (read-only on live):
#   1. migrations/<ts>_live_baseline.sql  <- live schema
#   2. seed.sql                           <- lookup tables (committed)
#   3. seed_acme.sql                      <- Acme test tenant + its auth users (gitignored)
# Then: supabase db reset --local
# Needs `supabase link`, the local stack running (for column lists), and a local
# pg_dump/psql >= the live Postgres major version.
set -euo pipefail
cd "$(dirname "$0")/.."

TENANT=caf40f8e-d521-468d-820b-3408e354b1fb # Acme
LOOKUPS="commission_calculation_types commission_statuses credit_note_statuses fulfillment_statuses
invoice_statuses payment_methods payment_statuses sale_types stock_adjustment_statuses stock_adjustment_types"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# `db dump --dry-run` prints a script with a short-lived login role; reuse its
# connection env so pg_dump runs locally instead of in the Supabase Docker image.
SUPABASE_EXPERIMENTAL_STACK=0 supabase db dump --linked --dry-run 2>/dev/null > "$tmp/dump.sh"
grep '^export PG' "$tmp/dump.sh" > "$tmp/env.sh"
baseline=$(ls supabase/migrations/*_live_baseline.sql)
{ sed -n '1,3p' "$baseline"; echo; bash "$tmp/dump.sh"; } > "$tmp/baseline.sql"
mv "$tmp/baseline.sql" "$baseline"

local_db=$(supabase status --env | python3 -c 'import json,sys; print(json.load(sys.stdin)["DB_URL"])')
tables=$(psql "$local_db" -At -c "select c.table_name from information_schema.columns c
  join information_schema.tables t using (table_schema, table_name)
  where c.table_schema = 'public' and c.column_name = 'tenant_id' and t.table_type = 'BASE TABLE'
    and c.table_name not like 'backup%' order by 1")
{
  echo "set default_transaction_read_only = on; set role postgres;"
  for t in $LOOKUPS; do echo "select 'lookup', 'public.$t', row_to_json(x) from public.$t x;"; done
  echo "select 'acme', 'public.tenants', row_to_json(x) from public.tenants x where id = '$TENANT';"
  for t in $tables; do echo "select 'acme', 'public.$t', row_to_json(x) from public.$t x where tenant_id = '$TENANT';"; done
  echo "select 'acme', 'auth.users', row_to_json(x) from auth.users x where id in (select user_id from public.profiles where tenant_id = '$TENANT');"
  echo "select 'acme', 'auth.identities', row_to_json(x) from auth.identities x where user_id in (select user_id from public.profiles where tenant_id = '$TENANT');"
} > "$tmp/export.sql"
(source "$tmp/env.sh"; psql -At -F $'\t' -q -v ON_ERROR_STOP=1 -f "$tmp/export.sql") > "$tmp/rows.tsv"
psql "$local_db" -At -F $'\t' -c "select table_schema || '.' || table_name, column_name from information_schema.columns
  where table_schema in ('public', 'auth') and is_generated = 'NEVER' order by table_schema, table_name, ordinal_position" > "$tmp/cols.tsv"

# json_populate_record maps by column name and the column list is the local one
# minus generated columns (auth.users.confirmed_at), so column-order or
# auth-version differences between live and local don't matter.
python3 - "$tmp/rows.tsv" "$tmp/cols.tsv" <<'PY'
import collections, json, sys
cols = collections.defaultdict(list)
for line in open(sys.argv[2]):
    table, col = line.rstrip('\n').split('\t')
    cols[table].append(col)
out = {'lookup': [], 'acme': []}
for line in open(sys.argv[1]):
    kind, table, js = line.rstrip('\n').split('\t', 2)
    keys = json.loads(js).keys()
    q = ', '.join(f'"{c}"' for c in cols[table] if c in keys)
    out[kind].append(f"INSERT INTO {table} ({q}) SELECT {q} FROM json_populate_record(NULL::{table}, $seed${js}$seed$) ON CONFLICT DO NOTHING;")
open('supabase/seed.sql', 'w').write(
    "-- Reference (lookup) rows copied from the live project. No tenant data.\n\n" + '\n'.join(out['lookup']) + '\n')
open('supabase/seed_acme.sql', 'w').write(
    "-- Acme test tenant, copied from live. Gitignored: contains tenant data and\n"
    "-- auth password hashes. FK checks are off so table order doesn't matter.\n"
    "SET session_replication_role = replica;\n\n" + '\n'.join(out['acme']) +
    "\n\nSET session_replication_role = DEFAULT;\n")
PY
echo "Refreshed. Run: supabase db reset --local"
