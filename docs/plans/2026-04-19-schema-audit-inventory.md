# 2026-04-19 Supabase Schema Audit Inventory

## Audit Scope

This inventory is based on:
- Live Supabase project type generation (`mcp_com_supabase__generate_typescript_types`) for project `kfqionlpnjetpmuzsvfb`.
- Live Supabase advisor diagnostics (`mcp_com_supabase__get_advisors`) for performance and security.
- Migration history and runtime usage analysis from app/repository/edge-function code.

Session note:
- Direct SQL table-content probes against the target Supabase project were not available through the current PostgreSQL connection profile in this session, so this audit uses authoritative schema/advisor artifacts plus code-path evidence. Add row-count/value-distribution SQL probes in implementation phase 0.5 before destructive drops.

## Executive Findings

1. Schema drift exists between migration intent and live schema.
2. A non-normalized dual-write pattern exists in credit notes.
3. Enum-like state fields are mostly raw text/varchar and should move to lookup-FK model.
4. Local PowerSync schema contract has multiple mismatches with live server schema.
5. Policy evolution is complex and needs an explicit reconciliation migration to prevent environment drift.

## Table-by-Table Classification

## Runtime Usage Matrix (Code + Edge + Sync)

Usage counts were computed by searching runtime artifacts (`lib/`, `supabase/functions/`, `sync_rules.yaml`, `lib/core/config/powersync.dart`) for table names.

- `products`: 131
- `sales`: 101
- `stock`: 87
- `branches`: 74
- `stock_adjustments`: 26
- `commissions`: 23
- `sale_payments`: 23
- `profiles`: 22
- `categories`: 22
- `sale_items`: 20
- `customers`: 17
- `credit_notes`: 14
- `staff_members`: 10
- `daily_kpi_snapshots`: 9
- `credit_note_items`: 8
- `stock_adjustment_reasons`: 8
- `item_groups`: 8
- `locations`: 5
- `units_of_measurement`: 5
- `profile_branches`: 5
- `daily_payment_method_snapshots`: 5
- `daily_product_sales_snapshots`: 5
- `composite_item_components`: 5
- `tenants`: 5
- `stock_item_groups`: 0
- `tenant_invoice_counters`: 0

Interpretation:
- `stock_item_groups` appears fully dead in runtime code and is a strong drop candidate.
- `tenant_invoice_counters` being 0 in app/runtime references is expected because it is reached through RPC (`next_invoice_number`) and edge function logic, not direct table CRUD.

## Keep (Core)

- `tenants`
- `branches`
- `profiles`
- `profile_branches`
- `staff_members`
- `customers`
- `categories`
- `item_groups`
- `units_of_measurement`
- `products`
- `stock`
- `stock_adjustments`
- `stock_adjustment_reasons`
- `sales`
- `sale_items`
- `sale_payments`
- `credit_notes`
- `credit_note_items`
- `composite_item_components`
- `commissions`
- `tenant_invoice_counters`
- `locations`
- `daily_kpi_snapshots`
- `daily_payment_method_snapshots`
- `daily_product_sales_snapshots`

## Keep But Normalize

- `credit_notes`
  - Problem: `items` JSON and `credit_note_items` are both written.
  - Current write evidence: [supabase/functions/manage-sale/index.ts](supabase/functions/manage-sale/index.ts#L655), [supabase/functions/manage-sale/index.ts](supabase/functions/manage-sale/index.ts#L684).
  - Action: make `credit_note_items` authoritative; deprecate/drop `credit_notes.items`.

- `products`
  - Problem: legacy fields still present in live schema despite prior simplification migration.
  - Simplification intent: [supabase/migrations/20260329_ph_simplify_item_groups.sql](supabase/migrations/20260329_ph_simplify_item_groups.sql#L6), [supabase/migrations/20260329_ph_simplify_item_groups.sql](supabase/migrations/20260329_ph_simplify_item_groups.sql#L17).
  - Conflicting later index migration: [supabase/migrations/20260404150000_phase5_fk_covering_indexes.sql](supabase/migrations/20260404150000_phase5_fk_covering_indexes.sql#L39).
  - Action: reconcile and remove legacy columns/tables after data safety checks.

## Deprecate/Drop Candidates

- `stock_item_groups`
  - Marked dead by migration intent and no active app usage.
  - Drop intent: [supabase/migrations/20260329_ph_simplify_item_groups.sql](supabase/migrations/20260329_ph_simplify_item_groups.sql#L17).

- Legacy `products` columns:
  - `group_id`
  - `product_type`
  - `variant_options`
  - `variant_images`

## Enum/State Audit (Lookup-FK Required)

These are currently raw text/varchar state surfaces and should be normalized into lookup tables plus FKs:

- `sales.status`
- `sales.payment_status`
- `sales.fulfillment_status`
- `sales.sale_type`
- `sale_payments.payment_method`
- `credit_notes.status`
- `commissions.status`
- `stock_adjustments.status`
- `staff_members.status`
- `daily_payment_method_snapshots.payment_method`

Current constraint posture:
- Only `stock_adjustments.adjustment_type` has explicit CHECK in migration history: [supabase/migrations/20260226112640_stock_adjustments.sql](supabase/migrations/20260226112640_stock_adjustments.sql#L9).
- Live type generation shows no native Postgres enums (`Enums: {}`) in current schema.

Recommended lookup tables:
- `invoice_statuses`
- `payment_statuses`
- `fulfillment_statuses`
- `sale_types`
- `payment_methods`
- `commission_statuses`
- `stock_adjustment_statuses`

Design rule:
- Tenants can reference lookup values, not author arbitrary state values.
- Lookup table mutations restricted to service/admin paths.

Seed values for lookup migrations (derived from current app and edge literals):

- `invoice_statuses`:
  - `pending_approval`
  - `approved`
  - `rejected`
  - `voided`
  - legacy: `partially_paid`, `paid`, `completed`, `draft`
- `payment_statuses`:
  - `unpaid`
  - `partially_paid`
  - `paid`
- `fulfillment_statuses`:
  - `unfulfilled`
  - `fulfilled`
- `sale_types`:
  - `invoice`
  - `pos_sale`
  - legacy compatibility: `sale`
- `payment_methods`:
  - `cash`
  - `mpesa`
  - `card`
  - `bank_transfer`
  - `credit_note`
  - compatibility bucket: `unknown`
- `credit_note_statuses`:
  - `draft`
  - `pending_approval`
  - `approved`
  - `applied`
  - `voided`
- `commission_statuses`:
  - `pending`
  - `paid`
  - compatibility (if present in data): `voided`
- `stock_adjustment_statuses`:
  - `pending`
  - `approved`
  - `rejected`
- `stock_adjustment_types`:
  - `addition`
  - `reduction`
  - `initial`
  - `damage`

Note:
- `item_groups.default_commission_type` currently uses `fixed`/`percentage` from migration logic while parts of UI use `fixed`/`percent`/`none`. This should be normalized as `commission_calculation_types` lookup plus one translation migration.

## PowerSync Contract Drift Findings

- `profiles.permissions`
  - DB migration uses JSONB: [supabase/migrations/20260223_invoice_system.sql](supabase/migrations/20260223_invoice_system.sql#L85)
  - Local PowerSync schema stores text: [lib/core/config/powersync.dart](lib/core/config/powersync.dart#L52)

- `composite_item_components`
  - Local schema includes `branch_id`: [lib/core/config/powersync.dart](lib/core/config/powersync.dart#L96)
  - Live generated schema currently exposes no `branch_id` for this table.

- `commissions`
  - Local schema includes `commission_type` + `commission_value`: [lib/core/config/powersync.dart](lib/core/config/powersync.dart#L276)
  - Live generated schema contract does not include these fields.

- `sales`
  - Local schema includes `customer_name`: [lib/core/config/powersync.dart](lib/core/config/powersync.dart#L183)
  - Live generated schema is customer-id centric.

## RLS and Policy Audit Notes

- Early broad authenticated policies existed on `commissions` and `profile_branches`:
  - [supabase/migrations/20260404000000_commissions_and_branches.sql](supabase/migrations/20260404000000_commissions_and_branches.sql#L19)
  - [supabase/migrations/20260404000000_commissions_and_branches.sql](supabase/migrations/20260404000000_commissions_and_branches.sql#L96)

- Later dynamic tenant-isolation normalization was introduced:
  - [supabase/migrations/20260404154000_phase3_auth_rls_initplan_optimization.sql](supabase/migrations/20260404154000_phase3_auth_rls_initplan_optimization.sql#L8)
  - [supabase/migrations/20260404154000_phase3_auth_rls_initplan_optimization.sql](supabase/migrations/20260404154000_phase3_auth_rls_initplan_optimization.sql#L40)

Action:
- Add explicit policy reconciliation migration and CI validation query so no environment keeps stale permissive policies.

## Security and Index Hygiene Signals

Live advisor highlights:
- Public bucket listing policies exist for `avatars`, `logos`, `product-images`.
- Leaked password protection is disabled.
- Many recently added indexes are still reported unused.

Action:
- Harden storage bucket policies.
- Enable leaked password protection.
- Re-evaluate index set after an observation window; keep only proven useful indexes.

## Recommended Migration Order

1. `20260419_status_lookup_tables.sql`
2. `20260419_credit_note_normalization.sql`
3. `20260419_drop_legacy_product_variant_schema.sql`
4. `20260419_rls_reconciliation.sql`
5. `20260419_index_hygiene.sql`

## Blocking Gate Before Production

Run this gate before merging cleanup:
- Verify no application queries still use dropped fields/tables.
- Verify PowerSync schema matches server contract.
- Verify all status writes route through lookup-FK constraints.
- Verify RLS policies are tenant-safe and non-duplicated.
