# 2026-04-15 Global Stock Reduction Plan

## Context

The business appears to run a mixed stock model:

- Some inventory behaves as shared/global across branches.
- Some inventory is truly branch-specific.

Current implementation is branch-scoped for sales decrements. We added an "Apply to all branches" stock-add path, but decrement behavior remains branch-only.

## Goal

Support both stock models safely and explicitly:

1. Shared stock products: one sale in any branch decrements the same shared pool.
2. Branch stock products: one sale decrements only the selling branch.

## Proposed Product Scope Model

Add a per-product stock scope:

- `stock_scope = 'branch' | 'shared'`
- Default for existing products: `branch` (backward-compatible).

Optional extension:

- `stock_pool_key` (nullable) for grouping multiple products into one shared pool when needed.

## Data & Schema Changes

1. Add `products.stock_scope text not null default 'branch'` with check constraint.
2. Keep existing `stock` table for branch-scoped rows (`product_id + branch_id`).
3. Add `shared_stock` table for global pools:
   - `id uuid pk`
   - `tenant_id uuid not null`
   - `product_id uuid not null unique` (or `stock_pool_key` unique)
   - `quantity int not null`
   - `last_updated timestamptz`
4. Add `stock_scope` to stock adjustment logs (`stock_adjustments`) if needed for audit clarity.

## Write Path Changes

### Inventory Adjustments

- Branch mode + branch product -> update `stock` for selected branch.
- All-branches mode + branch product -> fan-out to all branches.
- Shared product -> update `shared_stock` only.

### Sales Fulfillment / Decrements

- If product scope is `branch`: decrement `stock` by sale.branch_id.
- If product scope is `shared`: decrement `shared_stock`.
- Keep transactional rollback behavior for partial failures.

## Read Path Changes

1. Product lists and details show scope badge (`Shared` / `Branch`).
2. Quantity resolution:
   - Branch products: branch quantity.
   - Shared products: shared quantity shown consistently across branches.
3. Reports should aggregate using source of truth per scope.

## Migration Strategy

1. Migration A: add `stock_scope` column with default `branch`.
2. Migration B: create `shared_stock` table.
3. Backfill script:
   - No automatic promotion to shared initially.
   - Mark known shared SKUs manually (or via admin UI).
4. Release in read-compatible mode first, then enable shared decrements.

## Admin UX

1. Product form: add stock scope selector.
2. Inventory screens: show target scope/target pool in confirmation panel.
3. Bulk action: convert selected products to shared scope with optional initial shared quantity merge policy.

## Risk Controls

1. Feature flag for shared-stock decrements.
2. Dual-write logging during rollout for verification.
3. Guardrails against negative stock per scope.
4. End-to-end tests for both scope types.

## Test Plan

1. Branch product sale in Branch A does not affect Branch B.
2. Shared product sale in Branch A reflects reduced stock in Branch B immediately.
3. All-branches stock-add updates all branch rows for branch products.
4. Shared stock-add updates only shared pool and reflects everywhere.
5. Rollback checks on failed decrement path.

## Rollout Phases

1. Phase 1: Schema + read support + UI badges.
2. Phase 2: Shared-stock write paths behind flag.
3. Phase 3: Enable shared-stock decrements for selected tenants/products.
4. Phase 4: Default-on after monitoring.

## Open Decisions

1. Shared pool keyed by `product_id` only, or by configurable `stock_pool_key`?
2. Should shared products still keep branch-level shadow rows for reporting UX?
3. How to handle partial branch availability for shared products (visibility vs sellability rules)?
