#!/usr/bin/env bash
# Rebuilds the local stack from migrations (live baseline + pending) and seeds,
# then runs the SQL tests. Start the stack first: supabase start
set -euo pipefail
cd "$(dirname "$0")/../.."

supabase db reset --local >/dev/null
db=$(supabase status --env | python3 -c 'import json,sys; print(json.load(sys.stdin)["DB_URL"])')
# atomic_rpcs_test.sql is a manual smoke test for the production SQL editor
# (it reports by RAISE so it always rolls back), so it isn't listed here.
for t in supabase/tests/stock_integrity_test.sql supabase/tests/invoice_edit_test.sql; do
  echo "== $t"
  psql "$db" -q -v ON_ERROR_STOP=1 -f "$t"
done
