# Stock Adjustment — Focused Review

**Date:** 2026-06-25
**Scope:** the stock-adjustment flow only (creation → pending → approval → stock movement), not the whole app. Files: `inventory_adjustment_screen.dart`, `batch_stock_update_sheet.dart`, `adjustment_detail_screen.dart`, `adjustments_screen.dart`, `repository.dart` (adjust/batchAdjust/update), `supabase/functions/manage-stock-adjustment/index.ts`, `decrement_stock`/`increment_stock` RPCs, and the PowerSync connector upload path.

## How the flow works today (for context)
1. A user enters adjustments (a signed quantity delta per item) → `repository.batchAdjustStock` writes `stock_adjustments` rows with `status = 'pending'`, one shared `bundle_id`. **No stock moves yet.**
2. An owner/`approve_stock` user approves the bundle → `manage-stock-adjustment` (`approve_adjustment`) loops the rows and calls `increment_stock`/`decrement_stock` (by the **sign** of `quantity`), snapshots `previous_quantity`, and flips each row to `approved`.
3. Unapprove reverses the stock and returns rows to `pending`; reject/delete just change status / hard-delete.

---

## Bugs / correctness

### S1 — "Set to X" is computed at creation but applied at approval (stale target) 🔴 High
**Where:** `batch_stock_update_sheet.dart` — `_mode == 'set'`: `quantityChange = amount - current`, where `current = repo.getProductStockValue(...)` is read **now**, at creation. The resulting *delta* is stored and applied later at approval.
**Problem:** If stock changes between creation and approval (a sale, another adjustment), applying the stale delta does **not** land on `X`. e.g. set-to-10 when stock is 8 stores `+2`; if 3 sell before approval (stock 5), approval adds 2 → 7, not 10.
**Fix:** Make "set" a first-class intent: store the **target** (e.g. `adjustment_type = 'initial'`/a `target_quantity` column) and compute the delta from then-current stock **at approval time** (inside the approval RPC). If that's too big for now, at minimum apply set-adjustments immediately, or warn the user that "set to" is a snapshot that may drift before approval.

### S2 — Editing a pending adjustment's quantity doesn't update `adjustment_type` 🟠 Medium
**Where:** `repository.updateStockAdjustmentQuantity` runs `UPDATE stock_adjustments SET quantity = ? WHERE id = ?` — it changes **only** `quantity`.
**Problem:** `adjustment_type` was resolved from the sign at creation (`_resolveStockAdjustmentType`). Editing `+5 → -5` leaves `adjustment_type = 'addition'` with `quantity = -5`. The connector only re-normalizes `adjustment_type` when the patch *contains* it (`powersync.dart` patch branch), and this patch sends only `quantity` — so the server keeps the contradictory `addition / -5`. Stock still ends up correct (approval branches on the **sign**, `manage-stock-adjustment` L81-82, not on `adjustment_type`), but any report/label keyed on `adjustment_type` shows the wrong direction.
**Fix:** In `updateStockAdjustmentQuantity`, recompute and write `adjustment_type` alongside `quantity` (reuse `_resolveStockAdjustmentType`).

### S3 — Bundle approval is not atomic (partial application) 🔴 High
**Where:** `manage-stock-adjustment` `approve_adjustment` L79-121 — a JS `for` loop of separate `rpc()` + `update()` calls, no transaction.
**Problem:** If row 3 fails after rows 1-2 already moved stock + flipped to `approved`, the bundle is half-applied with no rollback. Re-approval skips the now-`approved` rows (status filter is `pending`), so row 3 can be retried, but the bundle is left inconsistent in the meantime, and an error is returned to the user after stock already moved. Same class as the main review's P1-1.
**Fix:** Move the whole bundle approval into one `plpgsql` function (loop + stock + status in a single transaction), invoked via one `rpc`.

### S4 — Approve/reject/delete/unapprove are not tenant-scoped 🔴 High (cross-tenant)
**Where:** `manage-stock-adjustment` — every query filters by `bundle_id`/`adjustment_id` + `status`, but **never** `.eq("tenant_id", tenant_id)` (L68-70, 132-143, 157-159, 212-218). The caller's *permission* is checked against `tenant_id`, but the rows acted on aren't constrained to that tenant.
**Problem:** An approver in Tenant A can approve/reject/delete/unapprove **Tenant B's** adjustments (and move B's stock) by passing B's `bundle_id`/`adjustment_id`. (This is the main review's M3, still live.)
**Fix:** Add `.eq("tenant_id", tenant_id)` to every `stock_adjustments` query here.

### S5 — Unsigned-JWT auth (shared with P0-1/P0-2) 🔴 Critical
**Where:** `manage-stock-adjustment` `parseJwtUserId` (L242-251) decodes the JWT without verifying the signature, and the function runs with gateway `verify_jwt = false`.
**Problem:** A forged token is accepted → combined with S4, full cross-tenant control of stock approval. This is the same hole as the main review's **P0-1/P0-2** — fix them together (verify via `supabase.auth.getUser`, flip `verify_jwt = true`).

### S6 — `decrement_stock` allows negative stock, unguarded 🟠 Medium
**Where:** live `decrement_stock` subtracts and even inserts a negative row when none exists; approval calls it with no floor check.
**Problem:** A reduction larger than on-hand silently produces negative inventory (e.g. reduce 10 from 3 → -7). No warning at entry or block at approval.
**Fix:** Guard at the RPC (`quantity = MAX(0, quantity - p_quantity)` or reject when it would go negative and return rows-affected), and/or preview the resulting value in the UI (see S10).

### S7 — reject/delete report success on zero rows matched 🟡 Low-Medium
**Where:** `reject_adjustment` (L132-148) and `delete_adjustment` (L212-223) run an `update`/`delete … WHERE status='pending' AND …` and return `{status:'rejected'/'deleted'}` regardless of affected count.
**Problem:** Rejecting/deleting an already-approved or wrong-id bundle returns 200 "done" while nothing changed — the UI then says it succeeded.
**Fix:** Check the affected-row count (use `.select()` on the mutation) and return 404 when zero.

---

## Ambiguity / UX improvements

### S8 — Two different mental models for the same action 🟠
The main screen (`inventory_adjustment_screen`) takes a **signed delta** ("+5 / -3", type `'auto'`), while `batch_stock_update_sheet` offers **Add / Subtract / Set to** modes. Same outcome, two paradigms — confusing and a source of S1. **Recommend:** standardise on explicit **Add / Reduce / Set** (a magnitude + a mode) everywhere, and drop signed input.

### S9 — Signed-number entry is ambiguous 🟠
On the main screen the user types a number; "5" could read as "add 5" or "set to 5". The only hint is the dialog helper text ("Positive for addition, negative for reduction"). **Recommend:** an Add/Reduce toggle with a positive magnitude removes the sign ambiguity entirely (and pairs with S8).

### S10 — No "resulting stock" preview, no negative warning 🟠
The entry UI doesn't show `current → new`. Users can't see they're about to go negative (S6) or that a "set" target differs from current. **Recommend:** show `current → resulting` per line as they type, highlight negative results, and block/confirm them.

### S11 — "Pending, not yet applied" isn't obvious at creation 🟡
Stock doesn't move until an owner approves, but the creation flow doesn't make that explicit — a cashier may assume the change took effect. The detail screen has a status badge, but the **submit** confirmation should say "Submitted for approval — stock changes once approved." (The detail screen's status is good; the creation toast is where it's missing.)

### S12 — "Adjuster" and "Salesperson" are now the same person (redundant) 🟡
After the salesperson→profile migration, `created_by` and `salesperson_id` both resolve to the current staffer. `adjustment_detail_screen` shows both `adjuster_display_name` (from `created_by`) and `staff_name` (from `salesperson_id`) — now duplicate info. **Recommend:** collapse to a single "Adjusted by" line. (Decide whether `salesperson_id` on adjustments is still meaningful now that it equals the creator — it may be droppable from the UI.)

---

## Suggested priority order
1. **S5 + S4** (auth + tenant scoping) — security; fold into the P0-1/P0-2 pass.
2. **S3** (atomic bundle approval RPC) and **S1** ("set to" target semantics) — correctness of stock.
3. **S2** (edit updates type), **S6** (negative guard), **S7** (zero-row success).
4. **S8–S12** (UX clarity) — the cheapest wins for "less ambiguous to the user" are **S10** (resulting-stock preview + negative warning) and **S9/S8** (Add/Reduce/Set instead of signed deltas).
