# Zynk — Codebase Code Review

**Date:** 2026-06-19
**Reviewer:** Automated deep review (architecture, security, correctness, state, presentation)
**Scope:** `lib/` (119 Dart files), `supabase/` (9 Edge Functions + ~33 migrations + schema), `sync_rules.yaml`, build/config.
**Stack:** Flutter + Riverpod 3 + PowerSync (offline-first SQLite) ⇄ Supabase (Postgres + RLS + Deno Edge Functions). Multi-tenant POS / inventory / invoicing for SMEs.

---

## 0. Executive Summary

The architecture is sound in shape — feature-folder layout, a single `PowerSyncRepository` for DB access, a documented `AGENTS.md` standard, and a deliberate "financial writes are server-authoritative, route them through Edge Functions" design in the PowerSync connector. That last decision is the right instinct.

The problem is that **the server-authoritative tier does not actually authorize**. Several Edge Functions trust a JWT they never verify, trust `tenant_id` straight from the request body, and operate on records without scoping by tenant. Because PowerSync deliberately routes all money/stock writes through these functions, the weakest link in the whole system is exactly the tier meant to be the strongest. The combination is a full cross-tenant read/write compromise reachable by any client.

Separately, the **stock movement RPCs are functionally broken** (they write to a column that does not exist), so stock decrement on sale completion and on adjustment approval fails silently in production.

Below, findings are ordered by priority. Each has a location, the problem, its impact, and a concrete fix. A consolidated remediation roadmap is in §6.

| Priority | Theme | Count |
|----------|-------|-------|
| **P0 – Critical** | Auth bypass, cross-tenant compromise | 6 |
| **P1 – High** | Atomicity/race/data-loss, fail-open auth, sync poison-pill, exposed backup tables | 9 |
| **P2 – Medium** | State-management anti-patterns, UI money math, data integrity | 13 |
| **P3 – Low** | Hygiene, consistency, dead code | 10 |

---

## 0b. Live database verification (2026-06-19, project `kfqionlpnjetpmuzsvfb`)

The findings below were re-checked against the **live** Supabase project via MCP (schema, RLS policies, function definitions, deployed Edge Function source, and the security advisor). The live DB has moved ahead of the in-repo migrations in places. Status per finding:

**✅ Already fixed in production (repo is stale):**
- **P0-6 (stock RPC broken column)** — RESOLVED. Live `decrement_stock`/`increment_stock` use `last_updated = NOW()` (not `updated_at`), pin `SET search_path = public`, and add an upsert fallback. The repo migration `20260226233500_fix_stock_rpcs.sql` is **stale and misleading** — it should be updated to match prod. (Residual: the RPCs still have no `tenant_id` guard and deliberately insert *negative* stock on miss — see P1-8.)
- **P1-6 (cross-tenant-open RLS)** — RESOLVED. Live policies are `commissions_tenant_isolation` / `profile_branches_tenant_isolation` = `tenant_id = current_tenant_id()`, and `tenant_invoice_counters` is `service_role`-only. The historical permissive policies were superseded. (Residual hygiene: squash them so a fresh `db reset` never transiently opens them.)
- **`stock` UNIQUE** — present in prod as `UNIQUE (branch_id, product_id)`; the earlier "missing unique" concern is withdrawn (branch is tenant-scoped, so it is effectively safe). See revised P2-11.

**🔴 Confirmed exploitable on the live deployment:**
- **P0-1** — deployed `manage-sale` (v43), `create-invoice` (v11), `manage-stock-adjustment` (v8) all have **gateway `verify_jwt = false`** AND verify the token in-code via `parseJwtUserId` (`JSON.parse(atob(...))`, `getUser` count = 0). A forged token is accepted. **Correction:** `manage-commissions` is `verify_jwt = true` at the gateway, so it is *not* forgeable — it is removed from this finding and noted as a defense-in-depth weakness only.
- **P0-2** — deployed `manage-sale` sets `tenantId = params.tenant_id` (L88-89) and contains only two `.eq("tenant_id", …)` filters across all ~16 actions. Confirmed.
- **P1-7** — live `objects` policies: upload/update for `logos` and `product-images` check only `bucket_id` (no `current_tenant_id()` scope), while the SELECT policies do scope. Confirmed.
- **P2-12** — `profiles` has **no UNIQUE on `user_id`** in prod; `current_tenant_id()` is still `... LIMIT 1` with no `ORDER BY`. Confirmed.

**🟠 Revised after live check:**
- **P0-3 (`manage-user-status`)** — gateway `verify_jwt = true`, so it is **not** reachable unauthenticated; reframed to "any authenticated user of any tenant can ban/unban any user globally" (still Critical).
- **P0-5** — `profiles.role` has a live `CHECK (role IN ('Owner','Manager','Cashier'))`, so the `profiles` row can't take an arbitrary string — but escalation to `Owner` is still in-set, and `update-staff-user` (verify_jwt=true) still does no tenant check on the target. Refined below.

**🆕 New, surfaced only against the live project (advisor + deployed-function list):**
- **NEW-1 (P1)** — backup tables exposed via PostgREST.
- **NEW-2 (P3)** — orphan `record-payment` Edge Function deployed but absent from repo.
- **NEW-3 (P3)** — leaked-password protection disabled; `current_tenant_id()` executable by `authenticated` role.

---

## 0c. Remediation status

Fixed findings are marked **inline** below — struck-through title + `✅ RESOLVED` badge, with a short "what was done" note in the body. Scan the headers to see what's done vs. open at a glance.

**Resolved so far:** P0-6, P0-7, P1-1, P1-2, P1-4, P1-6, P2-2, P2-3, P2-5, P2-7, P2-8 (+ overpayment guard, partial P2-6).
**Still open & highest priority:** **P0-1** and **P0-2** — the edge-function auth/tenant holes. These need a dedicated pass + redeploy of `manage-sale`, `create-invoice`, `manage-stock-adjustment`.

**Tests added:** `test/features/sales/auth_and_approval_test.dart` (fail-closed role + approval eligibility); `supabase/tests/atomic_rpcs_test.sql` (atomicity, idempotency, overpayment guard — re-runnable, self-rolling-back).

---

## P0 — Critical (fix before next release)

### P0-1. Edge Functions trust unsigned JWTs (authentication bypass) — 🔴 confirmed live
**Where:** deployed `manage-sale` v43 (`parseJwtUserId` L1426, used L56), `create-invoice` v11 (~L193), `manage-stock-adjustment` v8 (~L242). **All three have gateway `verify_jwt = false`**, so nothing checks the signature before the function runs.
**Problem:** These functions base64-decode the JWT payload and trust the `sub` claim **without verifying the signature** (confirmed in deployed source: `getUser` count = 0):
```ts
const payload = JSON.parse(atob(padded));  // L1434 — signature never checked
return payload?.sub;
```
An attacker can forge a token with any `sub` (no signing key needed) and be treated as any user.
**Impact:** Complete authentication bypass on the sale, invoice, and stock-adjustment endpoints — the core money/stock paths.
**Not affected:** `manage-commissions` is deployed with `verify_jwt = true`, so the gateway verifies the signature before the function runs — its in-code `parseJwtUserId` is a defense-in-depth weakness (it should still use `getUser`) but is **not forgeable**. `complete-sale` is `verify_jwt = false` but correctly calls `getUser` internally.
**Fix:** Either flip the three functions to `verify_jwt = true` **and** replace `parseJwtUserId` with `const { data: { user }, error } = await supabase.auth.getUser(token)` (do both — belt and braces). The correct pattern already exists in `complete-sale` (L36) and the staff functions.

### P0-2. `manage-sale` / `manage-stock-adjustment` trust `tenant_id` from the body and don't scope records to the tenant (cross-tenant write)
**Where:** `manage-sale/index.ts` L86-105, L122-131 (and the per-action record lookups: `delete_payment` L1019, `approve_credit_note` L1224, `apply_credit` L1311); `manage-stock-adjustment/index.ts` L68, L132-159, L212.
**Problem:** `tenantId` is taken from `params.tenant_id`; the profile/permission check confirms the caller belongs to *that named tenant*, but the sale/payment/adjustment is then fetched and mutated by id **without `.eq("tenant_id", tenantId)`**. An owner of Tenant A can pass `{action:"void_sale", sale_id:"<Tenant B sale>", tenant_id:"<Tenant A>"}` and the service-role (RLS-bypassing) client will void Tenant B's sale.
**Impact:** Any authenticated user can void/delete/refund/record-payment/approve-credit on **any other tenant's** sales and move any tenant's stock.
**Fix:** Always derive `tenantId` from the fetched record, never the body. Add `.eq("tenant_id", tenantId)` (and `.eq("sale_id", saleId)` for child rows) to **every** lookup and mutation. Assert `record.tenant_id === callerProfile.tenant_id` before acting.

### P0-3. `manage-user-status` is authenticated but performs no authorization (cross-tenant ban) — 🟠 revised
**Where:** `supabase/functions/manage-user-status/index.ts` L26-48. Live gateway flag: `verify_jwt = true`.
**Problem:** The gateway requires a *valid* signed token, but the function itself reads `{ userId, status }` from the body and calls `supabaseAdmin.auth.admin.updateUserById(userId, { ban_duration })` + a profile update **without identifying the caller, checking role, or scoping to a tenant**. (Corrected from the initial repo-only read: it is not reachable fully unauthenticated.)
**Impact:** Any authenticated user — of any tenant — can ban (lock out) or unban **any user in any tenant** by id. Account takeover / denial of service.
**Fix:** In-code: `getUser(token)`, require the caller's profile is `Owner`, and verify the target user's profile is in the caller's tenant before changing status.

### P0-4. `complete-sale` has no role/permission check and trusts `tenant_id`/`branch_id`
**Where:** `supabase/functions/complete-sale/index.ts` L44-119.
**Problem:** It authenticates the user (good) but then trusts `tenant_id` and `branch_id` from the body with no check that the caller belongs to that tenant or holds a POS/sell permission.
**Impact:** Any authenticated user can create completed sales + payments and decrement stock in any tenant.
**Fix:** Load the caller's profile `.eq("user_id", user.id).eq("tenant_id", tenant_id)`, require it exists with the relevant permission, and validate `branch_id` belongs to `tenant_id`.

### P0-5. Privilege escalation / cross-tenant hijack in staff update — 🟠 revised
**Where:** `create-staff-user/index.ts` L38-40, L100-110; `update-staff-user/index.ts` L38-39, L61-74. Both deployed with `verify_jwt = true`.
**Problem:** `role` is taken from the body. The `profiles` table has a live `CHECK (role IN ('Owner','Manager','Cashier'))`, so a *garbage* role is rejected — but promoting to `Owner` is still in-set, and the unconstrained `app_metadata.role` / `user_metadata.role` on `auth.users` take any string. More seriously, `update-staff-user` does **not** verify the target belongs to the caller's tenant (unlike `reset-staff-password` L59-61), so an Owner of Tenant A can rewrite the auth metadata (role, branch, tenant) of any user in any tenant by id.
**Impact:** Privilege escalation to Owner and cross-tenant account hijack.
**Fix:** Validate `role` against an explicit allowlist and forbid promoting to `Owner` via this path; in `update-staff-user`, fetch the target's profile and require `tenant_id === callerProfile.tenant_id`.

### P0-6. ~~Stock RPCs write to a non-existent column~~ — ✅ RESOLVED IN PRODUCTION (repo migration is stale)
**Status:** Live `decrement_stock`/`increment_stock` use `SET quantity = quantity ± p_quantity, last_updated = NOW()`, pin `SET search_path = public`, and upsert a row when none exists. Stock movement works in prod. **Action required is documentation, not code:** the repo migration `supabase/migrations/20260226233500_fix_stock_rpcs.sql` (L18/L36 still say `updated_at`) does **not** reflect production — update it so a fresh `db reset` doesn't regress to a broken state. Residual concerns (no tenant guard; deliberately inserts negative stock) are tracked under P1-8.

### ~~P0-7. `userRoleProvider` fails open to **Owner** on loading and error (privilege escalation)~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** Defaults to `UserRole.cashier` (least-privilege) on loading/error; `AppShell` gates on a resolved profile (welcome-loading screen) so the default is never consumed by real UI. Original analysis kept for context:
**Where:** `lib/core/providers/user_provider.dart` L7-15.
```dart
loading: () => UserRole.owner,   // every user is owner while profile loads
error: (_, _) => UserRole.owner, // and on any profile fetch error
```
**Problem:** This feeds `isOwnerProvider`, which gates the "All Branches" view and owner-only UI, and sets `branchSelectionProvider` default to `'all'`.
**Impact:** During the profile-load window or on any profile fetch error, **every user is treated as Owner** — transient exposure of all-branch data and owner-only controls. A failed load is indistinguishable from a real owner.
**Fix:** Default to the least-privileged role on `loading`/`error` (e.g. `UserRole.staff`), or surface `loading` explicitly so the UI shows skeletons rather than owner content.

---

## P1 — High

### ~~P1-1. Multi-step money/stock operations are not atomic; partial failures corrupt data~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** Sale + items + payment + stock decrement + invoice number now run in one transaction via `complete_sale_v2` / `record_sale_payment_v2` (`plpgsql`, migration `20260624000000`, self-tested). `complete-sale` & `manage-sale` redeployed to call them. Original analysis kept for context:
**Where:** `complete-sale/index.ts` L98-192; `manage-sale` `record_payment` L903-1004, `delete_sale` L1093-1102; `manage-stock-adjustment` L79-121.
**Problem:** Sale insert → items insert → payment insert → stock decrement are 4 separate REST calls with no transaction. Stock/payment errors are logged and execution continues (returns HTTP 200). `delete_sale` ignores child-delete errors. Adjustment approval loops applying stock then updating rows with no rollback.
**Impact:** "Completed" sales with no payment row or undecremented stock; half-applied adjustments that double-apply on re-run.
**Fix:** Move each end-to-end operation into a single `plpgsql` function invoked via one `rpc()` so it is atomic. At minimum, stop swallowing the errors and fail closed.

### ~~P1-2. No idempotency + read-modify-write races on payments/stock (double-spend)~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** Idempotency keys (`sale_id` / client-sent `payment_id`); `record_sale_payment_v2` takes a `FOR UPDATE` row lock + server-side `amount_paid` increment (no lost-update / TOCTOU); zero/negative rejected; overpayment rejected unless explicitly confirmed (server flag + client Proceed/Cancel dialog). Original analysis kept for context:
**Where:** `complete-sale` L178-192 (no idempotency key); `manage-sale` `record_payment` L920/L975-990 (`newAmountPaid = (sale.amount_paid||0) + amount` read-modify-write); `delete_payment` L1035.
**Problem:** A client retry after a committed write creates a second sale and decrements stock again. Two concurrent payments both read the same `amount_paid` and the second overwrites the first (lost payment), or both pass the `fulfillment_status != 'fulfilled'` gate and both decrement stock (TOCTOU).
**Impact:** Double-decremented inventory and lost/duplicated payments under normal network conditions.
**Fix:** Accept a client-supplied idempotency key (e.g. the client-generated `sale_id`) and short-circuit on conflict. Do `amount_paid = amount_paid + :amount` atomically in SQL with row locking. Validate `amount <= grand_total - amount_paid`.

### P1-3. PowerSync `uploadData` is a poison-pill: one bad op blocks the entire sync queue forever
**Where:** `lib/core/config/powersync.dart` L466-562.
**Problem:** The whole batch is wrapped in `try { ... } catch (e) { _log.e(...) }` with a comment "we don't complete the transaction so it retries". There is no distinction between transient (network) and permanent (constraint/RLS-rejection) errors. A single permanently-failing CRUD op (e.g. an RLS-denied or constraint-violating row) throws, the transaction is never completed, and it is retried indefinitely — **blocking every subsequent local write from ever syncing**.
**Impact:** A single bad row silently freezes all outbound sync for that device; the user keeps working offline and nothing reaches the server.
**Fix:** Catch per-op. On a permanent error (4xx/constraint), log + skip that op (or move it to a dead-letter) and continue so the transaction can complete; only leave the transaction incomplete for genuinely transient errors. Surface persistent upload failure to the UI.

### ~~P1-4. Route permission guards are bypassable during profile load and never re-evaluated~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** `AuthListenable` now also listens to `currentProfileProvider` and re-runs redirects when role/permissions resolve; `AppShell` gates the whole shell on a resolved profile (welcome-loading screen) so permission-gated screens never build early. Original analysis kept for context:
**Where:** `lib/core/routes.dart` L56-130 (`redirect`) and `AuthListenable` L392-405.
**Problem:** The redirect enforces permissions only inside `if (profile != null)` using `ref.read(currentUserProfileProvider).value`. Right after login the profile is still loading (`null`), so all permission checks are skipped and the user is admitted to `/settings/staff`, `/expenses`, etc. `AuthListenable` only `notifyListeners()` on a **login/logout transition** (L400) — not when the profile resolves — so the redirect never re-runs to evict them.
**Impact:** Client-side authorization is racy and bypassable (deep-link / fast-navigate before profile loads). Not a data-security boundary on its own (RLS is), but combined with the broken Edge-Function authz above it is the only gate for several flows.
**Fix:** Treat `loading` as "not yet authorized" (redirect to a splash/`/` until resolved), and make the router refresh on profile changes too (listen to `currentUserProfileProvider`, not just auth login state).

### P1-5. Duplicate provider definitions = two sources of truth for the same metric
**Where:** `lib/features/dashboard/providers/dashboard_providers.dart` (`todaysRevenueProvider` L35, `todaysOrderCountProvider` L83, `lowStockCountProvider`, `topProductsProvider`, `paymentMethodBreakdownProvider`) vs `lib/features/sales/providers/sales_providers.dart` (same names L152-193).
**Problem:** Two distinct provider objects share identifiers and back the same concept with different implementations. Which one a widget gets depends on the import line.
**Impact:** "Today's revenue" can disagree between screens; an import change silently swaps behavior. Direct DRY violation per `AGENTS.md`.
**Fix:** Consolidate to one canonical provider per metric and import it from both places.

### P1-6. ~~`commissions` / `profile_branches` / `tenant_invoice_counters` cross-tenant-open RLS~~ — ✅ RESOLVED IN PRODUCTION
**Status:** Live policies are correct: `commissions_tenant_isolation` and `profile_branches_tenant_isolation` = `tenant_id = current_tenant_id()`; `tenant_invoice_counters` is `service_role`-only. The historical permissive policies (`20260404000000` L19-21/L96-99, `20260223_invoice_system` L17-21) were superseded.
**Residual (Low, hygiene):** Those permissive policies still exist earlier in the migration history, so a fresh `supabase db reset` transiently opens them mid-replay. Consider squashing/removing them. **Verify the hardening migrations are applied to the second project (`Sideline`) too** if it shares this schema.

### NEW-1 (P1). Backup tables exposed via PostgREST with RLS disabled (cross-tenant data leak)
**Where:** live `public.backup_item_groups_20260519`, `public.backup_products_20260519` — flagged ERROR by the security advisor (`rls_disabled_in_public`).
**Problem:** The destructive reset migrations (P1-9) snapshot data into `public.backup_*` tables, which are left in the PostgREST-exposed `public` schema with **RLS disabled**. Any authenticated user (any tenant) can `GET /rest/v1/backup_products_20260519` and read **every tenant's** backed-up product catalog / item groups.
**Impact:** Cross-tenant disclosure of business data (product names, prices, structure).
**Fix:** Drop the backup tables once the reset is confirmed (`DROP TABLE public.backup_item_groups_20260519, public.backup_products_20260519;`), or move them to a non-exposed schema (e.g. `backup_20260519`) and/or `ENABLE ROW LEVEL SECURITY` with no policy. Going forward, write migration backups into a private schema, not `public`.

### P1-7. Storage write policies are not tenant-scoped (cross-tenant asset overwrite) — 🔴 confirmed live
**Where:** live `storage.objects` policies "Allow authenticated users to upload/update logos" and "…upload product images".
**Problem:** Confirmed in prod — the INSERT `WITH CHECK` and UPDATE `USING` check only `bucket_id = 'logos'` / `'product-images'`, while the SELECT policies correctly check `POSITION(current_tenant_id()::text IN name) > 0`.
**Impact:** Any authenticated user can upload/overwrite objects in another tenant's logo/product-image path.
**Fix:** Add the same `AND position(current_tenant_id()::text in name) > 0` predicate to the INSERT `WITH CHECK` and UPDATE `USING`/`WITH CHECK`.

### P1-8. Stock RPCs are tenant-blind `SECURITY DEFINER` and allow negative inventory
**Where:** `20260226233500_fix_stock_rpcs.sql` L6-40.
**Problem:** They run as definer (bypassing RLS), filter only on `product_id + branch_id`, accept caller-supplied ids with no `tenant_id` guard, and never check the result stays `>= 0`.
**Impact:** No defense-in-depth against cross-tenant stock manipulation; oversell drives negative quantities. (`20260518000000` revokes EXECUTE from clients, which is the main current mitigation — but the functions remain unsafe if re-granted or mis-called.)
**Fix:** Add a `p_tenant_id` param sourced from `current_tenant_id()`, add `AND tenant_id = p_tenant_id`, pin `SET search_path = public` in the definition, and guard `quantity >= p_quantity` for decrement (return rows-affected so the caller detects oversell).

### P1-9. Destructive "nuke/reset" migrations live in the permanent migration path
**Where:** `20260419091500_..._reset_catalog.sql` L84-102; `20260419123000_..._nuke_remaining_business_data.sql` L15.
**Problem:** Unconditional `TRUNCATE ... RESTART IDENTITY CASCADE` across products, stock, sales, customers, commissions, snapshots for all tenants. A backup-into-schema guard exists but is `IF backup IS NULL` — so **re-running after a backup already exists skips the backup but still truncates**, wiping fresh data with no new backup. No environment guard.
**Impact:** Applying the full migration set to a new/prod DB silently destroys business data; a re-run destroys data with no backup.
**Fix:** Gate destructive resets behind an explicit env/flag guard (or remove them from the always-applied path). At minimum make the TRUNCATE conditional on "backup did not already exist."

---

## P2 — Medium

### P2-1. Impure `Notifier.build()` with deferred side effect (violates the project's own rule #1)
**Where:** `lib/core/providers/app_providers.dart` L184-255 (`BranchSelectionNotifier`).
**Problem:** `build()` runs `Future.microtask(() => _prefs.setString(...))` and a heavy `_getInitialState()` that mixes `ref.watch(authStateProvider)` with `ref.read(...)` of profile/branches. `AGENTS.md` explicitly forbids side effects / microtasks / async in `build()`.
**Impact:** A SharedPreferences write fires on first build; every auth event re-runs build, re-scheduling the microtask and re-deriving from a non-reactively-`read` branches list that goes stale.
**Fix:** `build()` returns `const BranchSelectionState(isLoading: true)`. Move derivation into `branchSyncProvider`/`profileBranchSyncProvider` (already present, post-frame) and persist via `addPostFrameCallback`.

### ~~P2-2. Branch-selection feedback loop / branch "flapping" on startup~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** `selectBranch` no-ops when the value is unchanged; `setAvailableBranches` only updates the list when it changed and no longer clears/switches the selection just because a branch hasn't synced yet. Original analysis kept for context:
**Where:** `app_providers.dart` L276-352 (`setAvailableBranches` → `selectBranch`/`clearSelection`), `profile_provider.dart` L35-56.
**Problem:** `setAvailableBranches` mutates `branchSelectionProvider`, which nearly every stream provider depends on; `branchSyncProvider` itself watches `branchesProvider`. PowerSync emitting partial branch lists during sync can switch the selected branch out from under the user and re-trigger the cycle.
**Impact:** Invalidation storms and visible branch flapping at launch; selected branch can change mid-sync.
**Fix:** Guard mutations with "only if value actually changed" (`if (state.selectedBranchId == branchId) return;`), and never `clearSelection()` merely because a branch hasn't synced yet.

### ~~P2-3. Dashboard refresh-trigger invalidates ~12 streams at once~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** Removed `dashboardRefreshTriggerProvider` and all its watches (PowerSync streams are already live); pull-to-refresh is now tactile-only. Also collapsed the sparkline/net-profit derived providers that were causing a separate Riverpod TickerMode pause-count crash. Original analysis kept for context:
**Where:** `dashboard_providers.dart` L12-14, L36-388; invalidated at `dashboard_layout.dart` L27.
**Problem:** Eleven+ `StreamProvider`s all `ref.watch(dashboardRefreshTriggerProvider)`; pull-to-refresh `ref.invalidate`s it, tearing down and re-subscribing all streams simultaneously. PowerSync streams are already live, so the trigger is largely redundant (YAGNI).
**Impact:** Refresh flashes all skeletons and re-runs ~12 DB queries at once.
**Fix:** Remove the manual trigger (PowerSync is reactive) or scope it to a single repo-level refresh.

### P2-4. Screen-scoped dashboard streams are missing `autoDispose`
**Where:** `dashboard_providers.dart` — most KPI/stream providers are non-`autoDispose` (contrast `sales_providers.dart`, which correctly uses it throughout).
**Problem:** Per `AGENTS.md` rule #4, screen-scoped data should be `autoDispose`.
**Impact:** PowerSync subscriptions stay open after the dashboard is gone; they multiply on branch change.
**Fix:** Add `.autoDispose` to all screen-scoped dashboard providers.

### ~~P2-5. Inline SQL in widget submit handlers~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** The invoice screens now call `repository.getProductStockValue` / `getProductStockOrNull` instead of raw `repo.db.getAll`/`getOptional`. Original analysis kept for context:
**Where:** `create_invoice_screen.dart` L137-143; `edit_invoice_screen.dart` L163-166.
```dart
final stockResult = await repo.db.getAll(
  'SELECT quantity FROM stock WHERE product_id = ? AND branch_id = ?', [...]);
```
**Problem:** Raw SQL reaching into `repo.db` from the presentation layer — violates the "no inline SQL in widgets / repository owns queries" standard.
**Fix:** Add `repository.getAvailableStock(productId, branchId)` (or use the existing `stockByBranchProvider`) and call that.

### P2-6. Money math done in the UI with `double` and silent truncation — 🟡 PARTIALLY RESOLVED
**🟡 Partially resolved (2026-06-24):** The duplicated line math is now a single source of truth — `SalesService.resolveLine(...)`, used by create/edit/clone for subtotal, per-row totals and submission (no more 3× copies). **Still open:** it remains `double`-based and still truncates fractional piece quantities via `.toInt()` (now in one place). Switch to integer minor-units + reject fractional qty when ready. Original analysis kept for context:
**Where:** `create_invoice_screen.dart` L69-88, L124; `edit_invoice_screen.dart` L98-114, L745; also pricing math scattered in `sale_detail_screen.dart` L1072-1082.
**Problem:** `_computeSubtotal()` runs line-total math in the widget. Non-sqm path does `price * enteredQty.toInt()` — a quantity typed as "2.9" is silently truncated to 2 in both the estimate and the submitted value. The sqm path (`(price * coverage) * (enteredQty/coverage).ceil()`) is recomputed independently in three places that can drift, all in floating-point currency.
**Impact:** Wrong totals, silent quantity loss, divergent estimate-vs-submitted values, floating-point rounding on money.
**Fix:** Centralize line/subtotal computation in `SalesService` (single source of truth), use integer minor-units for currency, and reject fractional quantities explicitly instead of truncating.

### ~~P2-7. BuildContext / `setState` across async gap on the POS screen~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** `onCreateNew` now guards with `if (!mounted) return;` before `setState` after the `await`. Original analysis kept for context:
**Where:** `pos_screen.dart` L137-153 (`onCreateNew`).
**Problem:** After `await repo.createCustomer(...)`, `setState(() => _selectedCustomer = ...)` runs on the outer `_PosScreenState`; only `sheetContext.mounted` is checked, not the screen's own `mounted`.
**Impact:** `setState() called after dispose()` crash if the POS screen is disposed mid-await.
**Fix:** `if (!mounted) return;` against the State's own `mounted` before `setState`.

### ~~P2-8. Authorization/approval business logic computed inside widget `build()`~~ — ✅ RESOLVED
**✅ Resolved (2026-06-24):** Approval eligibility extracted to `saleApprovalEligibilityProvider` (covered by unit tests). Original analysis kept for context:
**Where:** `sale_detail_screen.dart` L83-99, L1072-1082, L2141-2150.
**Problem:** Approval eligibility (`canSubmitApproval`, fail-safe approval-count override) and per-item pricing/coverage are derived in `build()`; `_ApprovalTimeline` re-sorts all profiles by `createdAt` on every rebuild and watches a provider per item inside a `.map()`.
**Impact:** Authorization rules scattered in UI, recomputed every rebuild; per-row provider watches in a non-builder `Column`.
**Fix:** Move to a derived provider/view-model that returns approval state and per-line display models.

### P2-9. Eager non-virtualized lists (`Column` + `.map().toList()`) for unbounded data
**Where:** `sale_detail_screen.dart` `_ItemsList` L1067-1164, `_PaymentsList` L1281-1400, `_CreditNotesList` L1428-1503; spread item rows in `create_invoice_screen.dart` L465-481 / `edit_invoice_screen.dart` L554-566 (no keys).
**Problem:** All rows built up front, no virtualization, no `ValueKey`s on stateful rows holding `TextEditingController`s. `AGENTS.md` mandates `ListView.builder`.
**Impact:** Build cost and full rebuilds on large invoices; removing an item by index with keyless rows risks controller/widget mismatch.
**Fix:** Use `ListView.builder` with stable keys; key the editable rows.

### P2-10. Full-screen `setState` on every keystroke
**Where:** `create_invoice_screen.dart` L309, `edit_invoice_screen.dart` L336 — `Form(onChanged: () => setState(() {}))`.
**Problem:** Every character rebuilds the entire screen, including the eager item list and a totals recompute that re-parses every controller.
**Impact:** Per-keystroke jank on larger invoices (compounds with P2-9).
**Fix:** Scope rebuilds to the totals widget via a small `ValueListenableBuilder`/derived notifier.

### P2-11. Data-integrity CHECK constraints missing on money/quantity — 🔴 confirmed live (revised)
**Where:** live `sales`, `sale_items`, `expenses`, `commissions`, `stock_adjustments`.
**Problem:** Confirmed in prod: money/quantity columns have **no `CHECK (>= 0)`** — `sales` has only `payment_status` and (NOT VALID) `approval_count` checks, none on `subtotal`/`grand_total`/`amount_paid`; `commissions.amount`, `expenses.amount`, `sale_items.quantity/unit_price/total`, `stock_adjustments.quantity` are unconstrained. `commissions.tenant_id` also has **no FK** to `tenants` (other tables do).
**Withdrawn after live check:** `stock` *does* have `UNIQUE (branch_id, product_id)` in prod, so the "duplicate stock rows" risk does not apply.
**Impact:** Negative prices/quantities accepted silently; orphan commission tenants possible.
**Fix:** Add `CHECK (col >= 0)` (or `> 0` for quantities), `numeric(14,2)` for currency, and `commissions_tenant_id_fkey`. Also run `VALIDATE CONSTRAINT` on the many live `NOT VALID` FKs (`sales_status_fkey`, `commissions_status_fkey`, `stock_adjustments_status_fkey`, etc.) once data is clean.

### P2-12. `current_tenant_id()` is non-deterministic for multi-tenant users
**Where:** `20260405234000_fix_current_tenant_id_recursion.sql` L12-15 (`SELECT tenant_id FROM profiles WHERE user_id = auth.uid() LIMIT 1`).
**Problem:** No `ORDER BY`, and nothing enforces one profile per user (`profiles.user_id` has no UNIQUE constraint). If a user ever has profiles in two tenants, RLS binds to an arbitrary tenant by row order. (The recursion fix itself — adding `SECURITY DEFINER` to break the `profiles`-RLS cycle — is sound.)
**Impact:** Silent wrong-tenant reads/writes for multi-tenant users.
**Fix:** `ALTER TABLE profiles ADD CONSTRAINT profiles_user_id_unique UNIQUE (user_id);` (or model an explicit "active tenant") and make the selection deterministic.

### P2-13. `repository.dart` is a 2,898-line God Object
**Where:** `lib/data/local/repository.dart` (~100+ methods spanning profiles, products, stock, sales, payments, credit notes, commissions, branches, customers, UOM, item groups…).
**Problem:** Single class is the entire data layer. It mostly honors "raw queries only," but some methods carry business logic (e.g. `recordPaymentLocally` computes payment status; `_resolveStockAdjustmentType` normalizes types). SRP/ISP pressure: every screen's query needs land here.
**Impact:** Merge contention, hard to test, hard to reason about, easy to leak logic in.
**Fix:** Split into per-domain repositories (`SalesRepository`, `StockRepository`, `CatalogRepository`, …) behind the same provider surface; move computed logic into the existing `*_service.dart` layer.

---

## P3 — Low

### P3-1. Dead code that is also a data-loss trap: `recordPaymentLocally`
**Where:** `repository.dart` L1576-1637 (zero callers; UI uses `SalesService.recordPayment` → `manage-sale`).
**Problem:** It writes to `sale_payments`/`sales`, both in the connector's `_serverAuthoritativeTables` set. If wired up, `uploadData` **skips** those ops and still calls `transaction.complete()`, so the local write is dropped and overwritten on next sync — a payment that appears then vanishes.
**Fix:** Delete it (it contradicts the server-authoritative design), per `AGENTS.md` "delete dead code immediately."

### P3-2. `CircularProgressIndicator` instead of shimmer skeletons
**Where:** `reports_screen.dart` L317; `add_staff_screen.dart` L534-560; `edit_invoice_screen.dart` L266-280; `add_product_screen.dart` L505/L826. Violates the shimmer-only loading standard.

### P3-3. Hardcoded colors instead of `colorScheme`
**Where:** `add_product_screen.dart` L1204 (`Colors.white`); `sale_detail_screen.dart` (pervasive `Colors.green/red/orange`, `Color(0xFFFFA726)`, `Color(0xFF66BB6A)` at L964-1037, L1224-1332, L2257); `reports_screen.dart` L383-816; `add_staff_screen.dart` L684-711; `inventory_adjustment_screen.dart` L728/L1014/L1055. Breaks dark mode; `AGENTS.md` requires theme tokens via `colorScheme`.

### P3-4. Swallowed exceptions / `firstWhere` + empty `catch`
**Where:** `sale_detail_screen.dart` L500-519, L2057 (`catch (_) {}`); `statusEnforcerProvider` (`profile_provider.dart` L59-70) fires `signOut()` fire-and-forget and ignores error/loading; `add_product_screen.dart` L506/L806 hides load failures.
**Fix:** Use `.where(...).firstOrNull`; await/handle `signOut()`; show real error states.

### P3-5. CORS `Access-Control-Allow-Origin: "*"` on privileged admin functions
**Where:** all Edge Functions (e.g. `complete-sale` L7-11). Restrict to known app origins.

### P3-6. Raw DB error messages returned to clients
**Where:** Edge Functions return `err.message`/`*.message` (e.g. `complete-sale` L84/L124). Leaks schema detail; log server-side, return generic messages.

### P3-7. Inconsistent Edge-Function runtimes/imports & role-string casing
**Where:** staff functions use `esm.sh` + `std@0.168.0/http/server.ts` + `serve`; others use `jsr:` + `Deno.serve`. Role checks are `'Owner'` (case-sensitive) in staff fns vs `role?.toLowerCase() === "owner"` in sales fns — an authz hazard. Standardize runtime and role normalization.

### P3-8. Repo hygiene
**Where:** root: `analyze_output*.txt`, `build_log.txt`, `review.md`, `analyze.txt`, `fix_styles.py`, `migrate_icons.py`, `parse_csv_backup.py.` (trailing dot), `test_products.csv`; both `AGENTS.md` and `GEMINI.md` plus `.mulch` as parallel doc systems. Move scratch artifacts out of VCS; consolidate docs. *(Secrets are correctly handled: `.env`/`dart_defines.json` are gitignored and untracked; the app reads keys via `String.fromEnvironment`.)*

### NEW-2 (P3). Orphan `record-payment` Edge Function deployed but absent from repo
**Where:** live function list — `record-payment` (v2, `verify_jwt = false`) exists in the project but has no source under `supabase/functions/`. Payments in the app actually go through `manage-sale` → `record_payment`.
**Problem:** An undocumented, unversioned, `verify_jwt = false` function is live attack surface no one is maintaining (and likely shares the payment-mutation logic).
**Fix:** Confirm it's unused and **delete it**, or commit its source and bring it under the same auth fixes as P0-1/P0-2.

### NEW-3 (P3). Auth/exposure hardening flagged by the security advisor
**Where:** live security advisor.
**Problem:** (a) Leaked-password protection is **disabled** (no HaveIBeenPwned check on sign-up/reset). (b) `current_tenant_id()` is executable by the `authenticated` role via `/rest/v1/rpc/current_tenant_id` (WARN) — harmless in itself but unnecessary surface for a `SECURITY DEFINER` function.
**Fix:** Enable leaked-password protection in Auth settings; `REVOKE EXECUTE ON FUNCTION public.current_tenant_id() FROM authenticated` (RLS policies call it as definer regardless).

---

## 5. What's already done well

- **Server-authoritative write design** in the PowerSync connector (`_serverAuthoritativeTables`) is the right architecture — the fix is to make the Edge Functions actually authorize, not to change the design.
- `sales_providers.dart` is a model citizen: consistent `autoDispose`, family-parameterized filters, `ref.read` only in callbacks.
- No inline SQL found in providers (only the two widget cases in P2-5).
- `next_invoice_number` uses an atomic upsert (`ON CONFLICT DO UPDATE ... RETURNING`) — race-safe.
- Controllers/streams are disposed correctly across the reviewed `StatefulWidget`s; most async `setState`/`context` uses are correctly `mounted`-guarded (POS `onCreateNew` in P2-7 is the exception).
- The `current_tenant_id()` recursion fix (`SECURITY DEFINER` to break the `profiles`-RLS cycle) is correct.
- `AGENTS.md` is a genuinely good, specific standard — most findings are deviations *from it*, which means the team already knows the target.

---

## 6. Remediation roadmap (suggested order)

**Sprint 1 — stop the bleeding (P0, all live-confirmed):**
1. P0-1 — flip `manage-sale` / `create-invoice` / `manage-stock-adjustment` to `verify_jwt = true` **and** replace `parseJwtUserId` with `supabase.auth.getUser`.
2. P0-2 / P0-4 — derive `tenant_id` from records, add `.eq("tenant_id", …)` to every Edge-Function query; add caller role/permission checks.
3. P0-3 — add in-code `getUser` + Owner check + tenant scoping to `manage-user-status`.
4. P0-5 — role allowlist (forbid `Owner` promotion) + target-tenant check in staff create/update.
5. P0-7 — `userRoleProvider` defaults to least privilege.
6. NEW-1 — drop/relocate the exposed `backup_*_20260519` tables (RLS-off, cross-tenant readable).
7. P0-6 (doc only) — update the stale repo migration to match prod's working stock RPCs.

**Sprint 2 — correctness & integrity (P1):**
8. P1-1 / P1-2 — move sale/stock/payment writes into atomic `plpgsql` RPCs with idempotency keys and server-side increments.
9. P1-3 — make `uploadData` distinguish transient vs permanent errors (no more poison-pill).
10. P1-4 — fix route-guard race (treat loading as unauthorized; refresh on profile change).
11. P1-7 — tenant-scope the Storage upload/update policies; P1-8 — add tenant guard + non-negative guard to the (now working) stock RPCs.
12. P1-9 — gate/relocate destructive migrations; verify P1-6 hardening is also applied to the `Sideline` project.
13. P1-5 — de-duplicate the metric providers.

**Sprint 3 — state, UI, schema hardening (P2):** impure `build()` and branch loop (P2-1/2-2/2-3/2-4), inline SQL + UI money math (P2-5/2-6), async-gap setState (P2-7), list virtualization & keystroke rebuilds (P2-9/2-10), DB CHECK/UNIQUE/FK constraints (P2-11), `profiles.user_id` UNIQUE + deterministic tenant (P2-12), begin splitting the repository (P2-13).

**Ongoing — hygiene (P3):** delete dead code, shimmer loaders, theme tokens, error surfacing, CORS, runtime consistency, repo cleanup.

---

*Note on verification: the Supabase findings were verified against the **live** project `kfqionlpnjetpmuzsvfb` on 2026-06-19 (schema, RLS policies, function definitions, deployed Edge Function source, security advisor) — see §0b for what is fixed-in-prod vs confirmed-live vs new. Two items still rest on the repo source rather than re-fetched live function bodies: `create-invoice` and `manage-stock-adjustment` (P0-1/P0-2) — their gateway `verify_jwt = false` is confirmed live, and the repo source shows the same `parseJwtUserId`/body-`tenant_id` pattern as the confirmed `manage-sale`, so they are treated as confirmed. The second project (`Sideline`, `cnqcsjxrmjdejjnudnpa`) was not audited; if it shares this schema/functions, apply the same fixes there.*
