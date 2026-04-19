# Performance Baseline (2026-04-04)

## Scope

This baseline captures Phase 5 work for project `kfqionlpnjetpmuzsvfb`:

- Index hardening for critical app query paths
- Covering indexes for unindexed foreign keys reported by Supabase advisors
- Post-change query-plan snapshots for key repository queries

## Applied Migrations

Latest applied migration versions (descending):

- `20260404165939` `phase5_performance_baseline_indexes`
- `20260404155934` `phase3_security_policy_hardening`

Additional Phase 5 migration applied in this session:

- `phase5_fk_covering_indexes`

Repository migration files:

- `supabase/migrations/20260404142000_phase5_performance_baseline_indexes.sql`
- `supabase/migrations/20260404150000_phase5_fk_covering_indexes.sql`

## Performance Advisor Delta

- Before FK covering migration: `38` `unindexed_foreign_keys` lints
- After FK covering migration: `0` `unindexed_foreign_keys` lints

Note:

- Dataset size in production at measurement time is still very small; PostgreSQL may choose sequential scans despite indexes.
- This baseline is still useful as index-readiness and linter-hardening evidence for scale-up.

## Query-Plan Snapshots (Post-Index)

Tenant: `caf40f8e-d521-468d-820b-3408e354b1fb`
Branch: `7d86841a-0135-471d-b745-5bc7d67e56e3`

1. `watchSales` equivalent

- Query: `SELECT * FROM sales WHERE tenant_id=? AND branch_id=? ORDER BY created_at DESC LIMIT 50`
- Execution: `0.788 ms`
- Plan: `Seq Scan` (expected with tiny row counts)

2. `watchTodaysRevenue` equivalent

- Query: `SELECT COALESCE(SUM(amount),0) FROM sale_payments WHERE created_at>=day_start AND branch_id=?`
- Execution: `1.345 ms`
- Plan: `Seq Scan` (tiny row counts)

3. `watchTodaysOrderCount` equivalent

- Query: `SELECT COUNT(*) FROM sales WHERE status NOT IN (...) AND created_at>=day_start AND branch_id=?`
- Execution: `0.089 ms`
- Plan: `Seq Scan` (tiny row counts)

4. `watchLowStockCount` equivalent

- Query: `SELECT COUNT(*) FROM stock WHERE quantity <= reorder_level AND quantity >= 0 AND branch_id=?`
- Execution: `0.141 ms`
- Plan: `Seq Scan` (tiny row counts)

5. `watchTopProducts` equivalent

- Query: sales/sale_items/products join with `status='completed'`, grouped and ordered by `SUM(quantity)`
- Execution: `0.937 ms`
- Plan: nested loop + aggregate (tiny row counts)

## Added Index Families

1. Critical path indexes:

- sales: tenant/branch/date, payment status, fulfillment status
- sale_payments: tenant/sale/date and tenant/branch/date
- sale_items: tenant/sale
- commissions: tenant/salesperson/status/date and tenant/sale
- credit notes/items: tenant/date and tenant/credit_note
- profiles: user_id, tenant_id
- stock: tenant/branch/product

2. FK-covering indexes:

- Added covering indexes for all Supabase advisor-reported unindexed foreign keys at measurement time.

## Next Steps

1. Re-run these EXPLAINs after dataset growth (>=10k rows per core table) to capture index utilization transitions.
2. Keep branch-scoped aggregate snapshots in sync with dashboard/report requirements (implemented in Phase 6 via daily snapshot tables and pg_cron refresh jobs).
3. Add automated regression checks for advisor counts in release checklist.
