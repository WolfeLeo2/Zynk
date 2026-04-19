# 2026-04-15 Product Branches Architecture Plan

## Research Findings (Current State)

- `products.branch_id` is currently populated per branch (UUID), so a 3-branch tenant can end up with 3x duplicate catalog rows.
- For tenant `Prestine Homes` (`870a2a76-4a11-4b6f-a537-ee71d4f82037`):
  - `products`: 2451 rows
  - per-branch split: 817 each (Kitengela/Nakuru/Utawala)
  - `stock`: 0 rows
  - `stock_adjustments`: 0 rows
  - `sale_items`: 0 rows
- `product_branches` table does not exist yet.
- Flutter currently filters products by `products.branch_id`, with fallback logic for `branch_id IS NULL` and stock existence.

## Goal

Replace product duplication with:

1. Single product catalog row per logical item.
2. Dedicated branch availability mapping table (`product_branches`).
3. Branch-scoped stock rows remain branch-scoped (no global decrement).

## Proposed Schema Changes

1. Create `public.product_branches`:
   - `id uuid primary key default gen_random_uuid()`
   - `tenant_id uuid not null references tenants(id) on delete cascade`
   - `product_id uuid not null references products(id) on delete cascade`
   - `branch_id uuid not null references branches(id) on delete cascade`
   - `created_at timestamptz not null default now()`
   - `unique(product_id, branch_id)`
2. Add indexes:
   - `(tenant_id, branch_id)`
   - `(tenant_id, product_id)`
3. Add RLS policy:
   - tenant isolation using `current_tenant_id()`.

## Data Migration Strategy

### Option A (Requested reset path: Prestine only)

1. Backup Prestine product rows to a timestamped backup table.
2. Delete Prestine rows from `products` only (safe today because dependent rows are zero for this tenant).
3. Re-import CSV using new architecture:
   - create one `products` row per item
   - insert 3 `product_branches` rows per product
   - create branch-scoped `stock` rows per selected branch

### Option B (in-place dedupe path)

1. Keep one canonical product per logical key (`sku` fallback `name+category`).
2. Populate `product_branches` from legacy duplicated rows.
3. Update child references (`stock`, `sale_items`, `credit_note_items`) to canonical product IDs.
4. Delete duplicate products.

## Flutter / PowerSync Client Changes Required

1. **PowerSync schema**
   - Add local table definition for `product_branches` in `lib/core/config/powersync.dart`.
2. **Sync rules**
   - Add `SELECT * FROM product_branches WHERE tenant_id = bucket.tenant_id` in `sync_rules.yaml`.
3. **Repository query changes**
   - `watchProducts(branchId)` should use `product_branches` mapping for branch filtering.
   - Keep `branch_id IS NULL` compatibility only during transition.
4. **CSV import**
   - All-branches import:
     - create one product row (`branch_id = null`)
     - map product to each branch in `product_branches`
     - add stock per branch
   - Single-branch import:
     - create one product row
     - map to selected branch only
5. **Create/Edit Product flows**
   - Replace direct `product.branchId` dependence with branch mapping writes/reads.
6. **Local compat migration**
   - Add local DB migration for `product_branches` table in PowerSync compat path.

## Test Plan

1. CSV all-branches import creates 1 product + N product_branches + N stock rows.
2. CSV single-branch import creates 1 product + 1 mapping + 1 stock row.
3. Product list by branch shows mapped products only.
4. Stock decrement on sale fulfillment remains branch-scoped (existing behavior).

## Rollout Sequence

1. Apply Supabase migration for `product_branches` + policies.
2. Implement Flutter repository/provider/import updates.
3. Run `dart analyze` and targeted tests.
4. Perform Prestine reset + reimport.
5. Verify counts and branch behavior.

## Risks

1. Full-table truncate would affect all tenants. Avoid unless explicitly requested.
2. Legacy code paths still reading `products.branch_id` can show inconsistent branch lists until all queries migrate.
3. Sync rules and local schema must be updated together to avoid missing table sync.

## Open Questions (Need Answers Before Execution)

1. Scope of deletion: Prestine tenant only, or truly all tenants in `products`?
2. For single-branch CSV import, should products also be global catalog rows + one mapping, or stay legacy branch-bound?
3. Should categories also move to global + branch mapping, or remain as-is for now?
4. Keep branch-scoped decrement behavior unchanged? (recommended: yes)
