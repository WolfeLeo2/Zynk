# Shared Catalog + Branch Workflow Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move Zynk to a shared-product catalog with branch-specific stock, remove global branch guard friction, and deliver operational-grade workflows (clone item/invoice, cross-branch stock visibility, 2-step approvals, print output compliance).

**Architecture:** Product identity is global per tenant; branch availability is mapped through a dedicated junction table; stock remains branch-scoped and sales decrements remain branch-scoped. Branch context becomes contextual per workflow screen rather than globally blocking routes.

**Tech Stack:** Flutter + Riverpod + PowerSync + Supabase Postgres + Supabase Edge Functions.

---

## Constraints and Non-Goals

- Keep branch-scoped stock decrement semantics (no global stock pool in this phase).
- Do not run full-table destructive operations across all tenants.
- Do not break existing invoice numbering and payment lifecycle logic.
- Do not mix this overhaul with unrelated refactors.

---

## Phase 0.5: Supabase Schema Hygiene Track (Added)

### Task 0.5.1: Baseline and drift inventory

**Files:**
- Create: `docs/plans/2026-04-19-schema-audit-inventory.md`
- Modify: `review.md`

- [x] Capture table-by-table matrix: keep, normalize, deprecate, drop.
- [x] Reconcile migration intent vs live schema for legacy product fields (`group_id`, `product_type`, `variant_*`) and `stock_item_groups`.
- [x] Confirm live policy state for all tenant tables (avoid migration-history-only assumptions).

### Task 0.5.2: Enum/state normalization via lookup tables (per your requirement)

**Files:**
- Create: `supabase/migrations/20260419_status_lookup_tables.sql`

- [x] Create dedicated lookup tables and FK references for business states (not raw free-text writes):
  - `invoice_statuses`
  - `payment_statuses`
  - `fulfillment_statuses`
  - `sale_types`
  - `payment_methods`
  - `credit_note_statuses`
  - `commission_statuses`
  - `stock_adjustment_statuses`
  - `stock_adjustment_types`
  - `commission_calculation_types`
- [x] Backfill existing rows and enforce FKs.
- [x] Make lookup rows immutable for tenants (service-role/admin controlled writes only).
- [x] Seed lookup values from current app/runtime literals (including legacy compatibility values).

### Task 0.5.2b: Commission-type vocabulary reconciliation

**Files:**
- Create: `supabase/migrations/20260419_commission_type_reconciliation.sql`
- Modify: `lib/features/products/presentation/add_product_screen.dart`
- Modify: `lib/data/local/repository.dart`
- Modify: `supabase/migrations/20260404000000_commissions_and_branches.sql`

- [x] Normalize commission type vocabulary (`fixed`, `percentage`, `none`) and remove `percent`/`percentage` drift.
- [x] Update trigger logic and UI persistence paths to one canonical value set.

### Task 0.5.3: Remove non-normalized duplication

**Files:**
- Create: `supabase/migrations/20260419_credit_note_normalization.sql`
- Modify: `supabase/functions/manage-sale/index.ts`

- [x] Make `credit_note_items` the sole source of truth.
- [x] Backfill/rebuild `credit_notes.items` consumers and deprecate/drop `credit_notes.items` JSON field after compatibility window.

### Task 0.5.4: Remove dead/legacy schema safely

**Files:**
- Create: `supabase/migrations/20260419_drop_legacy_product_variant_schema.sql`

- [x] Gate with safety assertions (no active references/non-null data).
- [x] Drop legacy columns/tables only after verification:
  - `products.group_id`
  - `products.product_type`
  - `products.variant_options`
  - `products.variant_images`
  - `stock_item_groups`
- [x] Drop stale indexes targeting dropped columns.

### Task 0.5.5: PowerSync/schema contract alignment

**Files:**
- Modify: `lib/core/config/powersync.dart`
- Modify: `lib/core/models/schema_models.dart`
- Modify: `lib/core/models/schema_models.g.dart`

- [x] Align `profiles.permissions` local handling with DB JSONB contract.
- [x] Remove local-only columns that are not in live server schema.
- [x] Ensure each synced table column exists and matches compatible type.

### Task 0.5.6: RLS hardening verification + cleanup

**Files:**
- Create: `supabase/migrations/20260419_rls_reconciliation.sql`

- [x] Enforce tenant-isolation policy consistency for all tenant tables.
- [x] Remove stale permissive policies left from earlier migrations.
- [ ] Add regression SQL checks for policy coverage in CI.

### Task 0.5.7: Index hygiene

**Files:**
- Create: `supabase/migrations/20260419_index_hygiene.sql`

- [x] Keep high-value indexes for known query paths.
- [x] Drop truly-unused indexes only after observation window and query-plan validation.
- [x] Add partial indexes for filtered hot paths where appropriate.

---

## Phase 0: Product Decisions (Required Before Implementation)

- [x] Confirm deletion strategy for legacy duplicates:
  - Recommended: tenant-scoped backup + dedupe/migrate for `Prestine Homes` only.
  -User decision - Can delete for all tenants. I am starting a fresh. but keep profiles/users (so tenants/staff/humanStaff etc)
- [x] Confirm category model:
  - Recommended: keep `categories.branch_id` compatibility in this phase, normalize later.
  -User decision - Yes.Keep it
- [x] Confirm who can switch branches:
  - Recommended: owner + staff with more than one assigned branch.
  - User decision - Yes, keep it this way
- [x] Confirm 2-approver policy:
  - Recommended: minimum 2 distinct approvers with `approve_invoices` permission.
  -User decision -  Yes, this way

---

## Phase 1: Supabase Schema Migration

### Task 1.1: Add branch availability mapping

**Files:**
- Create: `supabase/migrations/20260419_add_product_branches.sql`

- [x] Create table `public.product_branches`:
  - `id uuid primary key default gen_random_uuid()`
  - `tenant_id uuid not null references tenants(id) on delete cascade`
  - `product_id uuid not null references products(id) on delete cascade`
  - `branch_id uuid not null references branches(id) on delete cascade`
  - `created_at timestamptz not null default now()`
  - `unique(product_id, branch_id)`
- [x] Create indexes:
  - `(tenant_id, branch_id)`
  - `(tenant_id, product_id)`
- [x] Enable RLS and add tenant isolation policy using `current_tenant_id()`.

### Task 1.2: Add invoice approval chain tables

**Files:**
- Modify: `supabase/migrations/20260419_add_product_branches.sql`

- [x] Create `public.sale_approvals`:
  - `id uuid pk`
  - `sale_id uuid not null references sales(id) on delete cascade`
  - `tenant_id uuid not null references tenants(id) on delete cascade`
  - `approver_user_id uuid not null`
  - `decision text not null check (decision in ('approved','rejected'))`
  - `notes text null`
  - `created_at timestamptz default now()`
  - Unique `(sale_id, approver_user_id)`
- [x] Add `required_approvals int not null default 2` and `approval_count int not null default 0` to `sales`.
- [x] Add RLS policies for `sale_approvals` using tenant isolation.

### Task 1.3: Data migration for duplicate products

**Files:**
- Create: `supabase/migrations/20260419_prestine_product_dedupe.sql`

- [x] Backup tenant rows into backup tables.
- [x] Build canonical product map by deterministic key (prefer SKU, fallback name+category).
  - Superseded by approved global fresh-start reset (catalog/transaction data wiped).
- [x] Populate `product_branches` for canonical products.
  - Superseded by approved global fresh-start reset (new catalog starts empty).
- [x] Repoint dependent FKs (`stock`, `stock_adjustments`, `sale_items`, `credit_note_items`, `composite_item_components`) where needed.
  - Superseded by approved global fresh-start reset (dependent rows truncated).
- [x] Delete duplicate product rows for target tenant.

---

## Phase 2: PowerSync + Sync Rules Alignment

### Task 2.1: Add local table schema

**Files:**
- Modify: `lib/core/config/powersync.dart`

- [x] Add `Table('product_branches', ...)` with columns:
  - `tenant_id`, `product_id`, `branch_id`, `created_at`

### Task 2.2: Update sync rules

**Files:**
- Modify: `sync_rules.yaml`

- [x] Add sync stream entry:
  - `SELECT * FROM product_branches WHERE tenant_id = bucket.tenant_id`
- [x] Keep `products` and `stock` streams unchanged for compatibility.

### Task 2.3: Local cleanup and bootstrap

**Files:**
- Modify: `lib/core/config/powersync.dart`

- [x] Extend startup cleanup logic for stale branch artifacts if required.
- [x] Verify upload pipeline still completes transactions for new table writes.

---

## Phase 3: Repository and Provider Refactor

### Task 3.1: Product read paths

**Files:**
- Modify: `lib/data/local/repository.dart`
- Modify: `lib/features/products/presentation/providers/product_providers.dart`

- [x] Replace `watchProducts(branchId)` filtering with `product_branches` mapping logic.
- [x] Keep legacy fallback (`products.branch_id`) temporarily during migration window.
- [x] Add `watchProductBranchStocks(productId)` returning all branch quantities.

### Task 3.2: Product write paths

**Files:**
- Modify: `lib/features/products/presentation/providers/add_product_controller.dart`
- Modify: `lib/features/products/data/csv_import_service.dart`

- [x] New products are created as shared catalog rows (`branch_id = null`).
- [x] Create `product_branches` mapping rows based on selected target branches.
- [x] Ensure stock adjustments only target real branch UUID rows in `stock`.

---

## Phase 4: Branch UX Overhaul (Contextual, Not Global Guard)

### Task 4.1: Remove global blocking pattern

**Files:**
- Modify: `lib/core/routes.dart`
- Modify: `lib/core/widgets/branch_required_guard.dart`

- [x] Remove route-level `BranchRequiredGuard` wrappers for core write flows.
- [x] Retain guard only for truly branch-required atomic operations if still needed.

### Task 4.2: Remove top-level branch dropdown and move branch selection inline

**Files:**
- Modify: `lib/features/dashboard/presentation/dashboard_layout.dart`
- Modify: `lib/core/providers/app_providers.dart`

- [x] Remove global owner branch dropdown from dashboard app bar.
- [x] Add `canSwitchBranchProvider` based on assigned branch count.
- [x] Preserve selected branch state for scoped screens only.

### Task 4.3: Add contextual branch selector widgets

**Files:**
- Modify: `lib/features/products/presentation/add_product_screen.dart`
- Modify: `lib/features/sales/presentation/create_invoice_screen.dart`
- Modify: `lib/features/sales/presentation/edit_invoice_screen.dart`
- Modify: `lib/features/pos/presentation/pos_screen.dart`

- [x] Add explicit branch pickers where action context requires one.
- [x] Owner defaults:
  - Item listing can show all branches.
  - Creation/edit forms ask for explicit branch target when needed.

---

## Phase 5: Clone Workflows

### Task 5.1: Clone item

**Files:**
- Modify: `lib/features/products/presentation/product_details_screen.dart`
- Modify: `lib/features/products/presentation/add_product_screen.dart`

- [x] Add “Clone item” action in product details.
- [x] Open add screen prefilled from source item but with new ID on save.
- [x] Clone should inherit category/group/UOM/pricing/description/media and allow edits before save.

### Task 5.2: Clone invoice

**Files:**
- Modify: `lib/features/sales/presentation/sale_detail_screen.dart`
- Modify: `lib/core/services/sales_service.dart`
- Modify: `supabase/functions/manage-sale/index.ts`

- [x] Add “Clone Invoice” action for eligible invoices (including voided).
- [x] Clone writes a new pending approval sale + sale_items snapshot.
- [x] Exclude payment records and approval history from clone.

---

## Phase 6: Cross-Branch Stock Visibility (No Cross-Branch Selling)

**Files:**
- Modify: `lib/features/products/presentation/product_details_screen.dart`
- Modify: `lib/features/products/presentation/providers/product_providers.dart`
- Modify: `lib/data/local/repository.dart`

- [x] Add branch stock matrix card on item details.
- [x] Show all branch quantities for referral use.
- [x] Keep checkout and decrement strictly bound to selected branch.

---

## Phase 7: Invoice / Receipt Output Compliance

**Files:**
- Modify: `lib/features/sales/presentation/printing/invoice_template.dart`
- Modify: `lib/features/sales/presentation/printing/receipt_template.dart`
- Modify: `lib/features/sales/presentation/sale_detail_screen.dart`

- [x] Remove invoice tax column and tax total section per requirement.
- [x] Remove “Generated by Zynk POS”.
- [x] Show tenant/branch phone, remove tenant email from print output.
- [x] Resolve salesperson display name (not ID) in invoice/receipt templates.

### Task 7.2: Add save-as-image

**Files:**
- Modify: `lib/features/sales/presentation/sale_detail_screen.dart`
- Add: `lib/features/sales/presentation/printing/invoice_image_export.dart`

- [x] Add action: “Save as Image”.
- [x] Render document to image-compatible output and save/share.
- [x] Keep existing PDF print path intact.

---

## Phase 8: Two-Step Approval Workflow

**Files:**
- Modify: `supabase/functions/manage-sale/index.ts`
- Modify: `lib/core/services/sales_service.dart`
- Modify: `lib/features/sales/presentation/sale_detail_screen.dart`
- Modify: `lib/features/sales/providers/sales_providers.dart`

- [x] `approve_sale` should append approval record instead of immediately finalizing.
- [x] Final sale approval occurs when `approval_count >= required_approvals`.
- [x] Same approver cannot approve twice.
- [x] Add UI timeline chips for approval #1 / #2 with names and timestamps.

---

## Phase 9: Native UI Standardization Pass

**Files:**
- Modify: `lib/features/dashboard/presentation/dashboard_layout.dart`
- Modify: `lib/core/widgets/app_drawer.dart`
- Modify: `lib/features/products/presentation/inventory_adjustment_screen.dart`
- Modify: `lib/features/sales/presentation/sale_detail_screen.dart`

- [x] Replace bespoke container-heavy action controls with native Material components where possible.
- [x] Standardize primary/secondary actions with `FilledButton`, `OutlinedButton`, `TextButton`.
- [x] Replace `CircularProgressIndicator` placeholders in list/detail pages with shimmer skeletons per team standards.

---

## Phase 10: Testing and Validation

### Required tests

- [ ] Shared catalog:
  - Product create/import yields one product row + N product_branches mappings.
- [ ] Stock isolation:
  - Branch A decrement does not alter Branch B.
- [ ] Branch UX:
  - Owner and multi-branch staff can choose branch in-context.
  - Single-branch staff experiences no unnecessary branch prompts.
- [ ] Clone flows:
  - Product clone persists as new product.
  - Invoice clone creates new pending approval sale only.
- [ ] Approval chain:
  - Requires two distinct approvers before approved status.
- [ ] Printing:
  - Output excludes tax/email/“Generated by Zynk POS”; includes phone + salesperson name.

### Commands

- [ ] `dart analyze`
- [ ] Targeted tests under `test/features/products/` and `test/features/sales/`
- [ ] Manual UAT across owner + multi-branch staff + single-branch staff personas.

---

## Rollout Strategy

1. Run schema hygiene track first (Phase 0.5) on a branch database.
2. Deploy shared-catalog schema migration (product_branches + approvals).
3. Deploy app changes with backward-compatible read fallback.
4. Run tenant-scoped dedupe migration (Prestine first).
5. Enable 2-approver enforcement after UI rollout.
6. Monitor edge-function logs and stock integrity metrics.

---

## Rollback Strategy

- Keep tenant-level backup tables before dedupe.
- Feature-flag clone actions and 2-approver enforcement.
- If issues occur, revert app to legacy query path and restore tenant product data from backup.
