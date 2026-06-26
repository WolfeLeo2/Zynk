# Auto-Assign Salesperson Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Automatically assign the current authenticated user's `profile.id` as the salesperson for all new sales and stock adjustments, removing the manual dropdown selection, while gracefully supporting historical records that point to the `staff_members` table.

**Architecture:** We will remove the `staff_members` dropdowns from the UI (POS, Invoices, Adjustments). During checkout/save, we will inject the current `profile.id` into the `salespersonId` payload. To handle the dual-state database (where `salesperson_id` can be either a `staff_member` or a `profile`), we will update SQLite queries in `repository.dart` to `LEFT JOIN` both tables and `COALESCE` the display name, allowing historical data and commissions to render seamlessly alongside new data.

**Tech Stack:** Flutter, Riverpod, SQLite (PowerSync)

---

### Task 1: Update SQL Read Queries for Dual-State Salespersons

**Files:**
- Modify: `lib/data/local/repository.dart`

**Step 1: Write the minimal implementation**
We need to update queries that currently join `staff_members` to resolve the `salesperson_id` so that they check `profiles` as well.
In `repository.dart`, locate queries fetching `sales`, `stock_adjustments`, and `commissions`.
Update the `FROM` and `JOIN` clauses to:
```sql
LEFT JOIN staff_members sm ON sm.id = sa.salesperson_id
LEFT JOIN profiles p ON p.id = sa.salesperson_id
```
And update the `SELECT` clauses to resolve the name:
```sql
COALESCE(p.display_name, sm.name) AS salesperson_name
```
*(Apply this to `watchSales`, `watchSaleById`, `watchStockAdjustments`, `watchCommissions`, and `watchCommissionSummary`)*.

**Step 2: Commit**
```bash
git add lib/data/local/repository.dart
git commit -m "feat(db): support both profiles and staff_members for salesperson names"
```

### Task 2: Remove Salesperson Selection from UI

**Files:**
- Modify: `lib/features/sales/presentation/create_invoice_screen.dart`
- Modify: `lib/features/sales/presentation/edit_invoice_screen.dart`
- Modify: `lib/features/products/presentation/inventory_adjustment_screen.dart`

**Step 1: Write the minimal implementation**
- Remove the `DropdownButtonFormField` or custom dropdown widgets for `salespersonId`.
- Remove the `humanStaffProvider` usage from these screens.
- Replace the manually selected `_salespersonId` state with a read from `currentProfileProvider`:
```dart
final currentProfile = ref.read(currentProfileProvider);
final salespersonIdToUse = currentProfile?.id;
```
- For `edit_invoice_screen.dart`, we should ideally preserve the *original* `salespersonId` (so we don't accidentally re-assign a historical invoice to the current user when editing notes). The UI should just display the original name statically instead of a dropdown.

**Step 2: Commit**
```bash
git add lib/features/sales/presentation/create_invoice_screen.dart lib/features/sales/presentation/edit_invoice_screen.dart lib/features/products/presentation/inventory_adjustment_screen.dart
git commit -m "feat(ui): remove manual salesperson selection dropdowns"
```

### Task 3: Auto-Assign in POS Checkout

**Files:**
- Modify: `lib/features/pos/presentation/pos_layout.dart` (or the relevant POS checkout dialog where sales are finalized)

**Step 1: Write the minimal implementation**
- Locate the checkout flow (e.g., `_processSale` or `showCheckoutDialog`).
- Remove any requirement to select a staff member.
- Inject `ref.read(currentProfileProvider)?.id` into the sale payload passed to `salesService.recordSale()`.

**Step 2: Commit**
```bash
git add lib/features/pos/presentation/pos_layout.dart
git commit -m "feat(pos): auto-assign current user profile to pos sales"
```

### Task 4: Verify Edge Functions & Print Templates

**Files:**
- Modify: `lib/features/sales/presentation/printing/invoice_template.dart`
- Modify: `lib/features/sales/presentation/printing/receipt_template.dart`

**Step 1: Write the minimal implementation**
- Verify that `salespersonName` is passed correctly to the print templates. Because we updated `repository.dart` in Task 1, `sale.salespersonName` should naturally be correct.
- Test the print generation to ensure no null errors occur.

**Step 2: Commit**
```bash
git commit --allow-empty -m "chore(print): verify receipt templates handle auto-assigned salespersons"
```
