# Zynk Multi-Branch + Workflow Review (2026-04-19)

## Scope Investigated

- Flutter client architecture and UX flows.
- PowerSync local schema and sync rules.
- Supabase edge functions and migrations.
- Current product/stock and invoice approval design viability for SaaS scale.

---

## Critical Findings

### 1) Shared catalog architecture is not consistently implemented yet

The desired model is: one product catalog, branch-specific stock. Current implementation is mixed:

- CSV all-branches import can create global products (`branch_id = null`) and fan stock per branch:
  - `lib/features/products/data/csv_import_service.dart:91`
  - `lib/features/products/data/csv_import_service.dart:103`
  - `lib/features/products/data/csv_import_service.dart:124`
- Standard add/edit product still writes branch-bound products:
  - `lib/features/products/presentation/providers/add_product_controller.dart:81`
  - `lib/features/products/presentation/providers/add_product_controller.dart:107`
  - `lib/features/products/presentation/providers/add_product_controller.dart:138`
- Product filtering still depends on `products.branch_id` plus fallback heuristics:
  - `lib/data/local/repository.dart:161`
  - `lib/data/local/repository.dart:172`

Impact:

- Duplicate catalog rows are still possible and currently present historically.
- Data model semantics depend on entry path, which is risky at scale.
- Last sampled tenant state (Prestine Homes) showed 2451 products, matching 817 x 3 branches.

### 2) Branch selection is globally enforced, not contextual

- Global guard blocks key write screens in All Branches mode:
  - `lib/core/widgets/branch_required_guard.dart:13`
  - `lib/core/routes.dart:109`
  - `lib/core/routes.dart:121`
  - `lib/core/routes.dart:143`
  - `lib/core/routes.dart:180`
  - `lib/core/routes.dart:198`
  - `lib/core/routes.dart:249`
- Owner has branch dropdown in dashboard top bar, but non-owner staff are forced into read-only branch badge even if assigned multiple branches:
  - `lib/features/dashboard/presentation/dashboard_layout.dart:401`
  - `lib/features/dashboard/presentation/dashboard_layout.dart:456`
  - `lib/features/dashboard/presentation/dashboard_layout.dart:479`
- Core write flows still require global current branch context:
  - `lib/features/products/presentation/providers/add_product_controller.dart:51`
  - `lib/features/sales/presentation/create_invoice_screen.dart:119`
  - `lib/features/sales/presentation/edit_invoice_screen.dart:104`

Impact:

- This conflicts with Zoho-style branch selection only where needed.
- Multi-branch staff cannot switch branch context despite backend support via `profile_branches`.

### 3) Invoice approval supports only one approver

- Sales model has a single `approved_by` field and no approval chain entity:
  - `lib/core/models/sales_models.dart` (single `approvedBy` property)
  - `supabase/functions/manage-sale/index.ts:262`
  - `supabase/functions/manage-sale/index.ts:768`
- Invoices are created directly as `pending_approval`, then one approval action flips state:
  - `supabase/functions/create-invoice/index.ts:128`
  - `supabase/functions/create-invoice/index.ts:174`

Impact:

- Cannot enforce 2-approver workflow (accountant + owner, or any two authorized approvers).

### 4) Invoice/receipt output does not match requested format

- Invoice template includes tenant email, salesperson ID label, tax column, and branded footer text:
  - `lib/features/sales/presentation/printing/invoice_template.dart:166`
  - `lib/features/sales/presentation/printing/invoice_template.dart:291`
  - `lib/features/sales/presentation/printing/invoice_template.dart:347`
  - `lib/features/sales/presentation/printing/invoice_template.dart:503`
- Receipt template shows salesperson ID directly and tax line when non-zero:
  - `lib/features/sales/presentation/printing/receipt_template.dart:98`
  - `lib/features/sales/presentation/printing/receipt_template.dart:220`

Impact:

- Violates your requested invoice branding/output standard.

---

## High Findings

### 5) Clone item flow is missing

- Product form supports create/edit only, not clone-as-new:
  - `lib/features/products/presentation/add_product_screen.dart:16`
  - `lib/features/products/presentation/add_product_screen.dart:64`
  - `lib/features/products/presentation/add_product_screen.dart:638`
- Product details only routes into edit-style add screen:
  - `lib/features/products/presentation/product_details_screen.dart:26`

### 6) Clone invoice flow is missing

- Sale detail action menu includes edit/approve/reject/void/release/delete, but no clone:
  - `lib/features/sales/presentation/sale_detail_screen.dart:88`
  - `lib/features/sales/presentation/sale_detail_screen.dart:96`

### 7) Cross-branch stock visibility for referrals is missing in UX

- Product detail stock view binds to single current context stock provider, not a branch breakdown matrix:
  - `lib/features/products/presentation/product_details_screen.dart:364`
  - `lib/features/products/presentation/product_details_screen.dart:394`
- Provider/repository currently expose per-context stock, not branch-by-branch stock list:
  - `lib/features/products/presentation/providers/product_providers.dart:42`
  - `lib/data/local/repository.dart:266`

### 8) Save invoice as image is not implemented

- Current print flow is PDF-only via Printing plugin:
  - `lib/features/sales/presentation/sale_detail_screen.dart:374`

Operational answer to your question:

- A receipt is currently rendered automatically only for `saleType == 'pos_sale'`.
- Invoice flows render invoice template instead of receipt template.

---

## Medium Findings

### 9) Backend branch-assignment security policy needs hardening review

- `profile_branches` was introduced with broad authenticated policies in migration:
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:95`
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:96`
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:97`
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:98`
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:99`
- No migration currently introduces `product_branches` mapping table.

### 10) UI maturity concerns are valid

- High density of bespoke containers/composite cards in critical screens can lead to visual inconsistency over time:
  - `lib/core/widgets/app_drawer.dart:237`
  - `lib/features/dashboard/presentation/dashboard_layout.dart:83`
  - `lib/features/dashboard/presentation/dashboard_layout.dart:429`
- Multiple screens still use `CircularProgressIndicator` where your AGENTS rules prefer shimmer skeletons:
  - `lib/features/products/presentation/inventory_adjustment_screen.dart:366`
  - `lib/features/products/presentation/inventory_adjustment_screen.dart:693`
  - `lib/features/sales/presentation/sale_detail_screen.dart:210`
  - `lib/features/sales/presentation/sale_detail_screen.dart:549`

---

## Supabase Schema Audit (Deep)

### A) Migration-to-live schema drift is present

- Migration intends to remove legacy product variant/group fields and dead table:
  - `supabase/migrations/20260329_ph_simplify_item_groups.sql:6`
  - `supabase/migrations/20260329_ph_simplify_item_groups.sql:17`
- Later migration still creates indexes on legacy column `products.group_id`, which implies cleanup was not consistently enforced across migration history:
  - `supabase/migrations/20260404150000_phase5_fk_covering_indexes.sql:39`
- App code has no active dependency on `stock_item_groups`, but live generated schema still exposes it.

Risk:

- Dirty schema persists indefinitely and can confuse future migrations and tooling.

### B) Non-normalized duplication exists in credit notes

- `manage-sale` writes both `credit_notes.items` (JSON blob) and `credit_note_items` (normalized table):
  - `supabase/functions/manage-sale/index.ts:655`
  - `supabase/functions/manage-sale/index.ts:684`

Risk:

- Two sources of truth can diverge and produce reporting inconsistencies.

### C) Enum-like business states are mostly raw text/varchar

Observed pattern:

- Business-critical state fields are free text (status/type/method), including sales lifecycle/payment/fulfillment, commission status, stock adjustment status, staff status, payment method snapshots.
- Migration evidence shows only limited CHECK enforcement (`stock_adjustments.adjustment_type`):
  - `supabase/migrations/20260226112640_stock_adjustments.sql:9`
- No native Postgres enums are present in generated live schema (`Enums: {}`).

Risk:

- Tenant-isolated RLS does not prevent invalid status value writes within tenant scope.
- Typos and unauthorized state transitions are possible unless app/service logic catches everything.

### D) App schema contract drift vs local PowerSync schema

- `profiles.permissions` is JSONB in database migration, but local PowerSync schema models it as text:
  - `supabase/migrations/20260223_invoice_system.sql:85`
  - `lib/core/config/powersync.dart:52`
- Local `composite_item_components` includes `branch_id`, while generated live schema does not currently expose it.
  - `lib/core/config/powersync.dart:96`
- Local `commissions` schema includes `commission_type`/`commission_value` columns that are not part of the current live commissions table contract.
  - `lib/core/config/powersync.dart:276`
  - `lib/core/config/powersync.dart:277`
- Local sales schema includes `customer_name`; live contract is centered on `customer_id`.
  - `lib/core/config/powersync.dart:183`

Risk:

- Sync/read behavior can be brittle when local and server column contracts diverge.

### E) RLS policy evolution has conflicting history

- `profile_branches` and `commissions` started with broad authenticated policies:
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:96`
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:19`
- Later hardening attempts to normalize tenant isolation for many tables via dynamic migration blocks:
  - `supabase/migrations/20260404154000_phase3_auth_rls_initplan_optimization.sql:8`
  - `supabase/migrations/20260404154000_phase3_auth_rls_initplan_optimization.sql:40`

Risk:

- Without explicit live policy validation in CI, environments can drift and retain stale permissive policies.

### F) Advisor diagnostics indicate schema hygiene debt

- Security advisor warnings currently include:
  - Public bucket listing policies on `avatars`, `logos`, `product-images`.
  - Leaked password protection disabled.
- Performance advisor shows many newly-added indexes still unused.

Risk:

- Security posture and index bloat should be actively managed, not left to accumulate.

### G) Commission type vocabulary is inconsistent across layers

- Trigger logic in migration uses `fixed` / `percentage`:
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:58`
  - `supabase/migrations/20260404000000_commissions_and_branches.sql:60`
- UI flows can emit `fixed` / `percent` / `none` patterns.

Risk:

- Commission calculations can silently diverge when type values drift.
- This should be normalized with a dedicated lookup and one canonical vocabulary.

---

## What Your Previous Plan Got Right

Your existing plan in `docs/plans/2026-04-15-product-branches-architecture-plan.md` is directionally correct for the client’s clarified requirement:

- Shared products across branches.
- Branch-specific stock quantities.
- Branch-scoped decrements retained.

This does not force global stock decrements as long as decrement calls remain branch-bound (which they currently are).

---

## Required Strategic Adjustment

Do not stop at data model normalization only. The fix must include:

1. Contextual branch selection UX (remove global guardrail pattern).
2. Clone flows (product + invoice).
3. Cross-branch stock visibility UI.
4. Print/template compliance changes.
5. 2-step approval workflow redesign.
6. Progressive migration toward native Material widgets and consistent loading states.

---

## Final Position

Your client requirement is correct and scalable:

- Product catalog should be shared (single source of truth).
- Stock should remain branch-specific.
- Branch decrement should remain branch-specific.

The current codebase partially supports this, but not end-to-end. A coordinated schema + PowerSync + repository + UI workflow migration is required.
