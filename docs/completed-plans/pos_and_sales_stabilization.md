# Plan: POS & Sales Stabilization (Consistency & Reactivity)

The goal is to ensure POS branch consistency, lock invoice contexts, and resolve UI synchronization issues where server-side mutations (deletions, status changes, credit notes) fail to reflect immediately in the application state.

## Proposed Changes

### [Component] POS Providers & Notifiers
#### [MODIFY] [pos_providers.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/pos/providers/pos_providers.dart)
- Update `PosBranchNotifier` to ensure it never returns 'all' as a fallback. If the global branch is 'all', it should default to the first available physical branch.
- Add a provider `selectedPosBranchProvider` that returns the `Branch` object for the current `posBranchId`. (Already exists, but ensure it works with the new fallback).

### [Component] POS UI
#### [MODIFY] [pos_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/pos/presentation/pos_screen.dart)
- Filter `branchOptions` to exclude the 'all' branch.
- Pass `posBranchId` explicitly to `PosTicket` (or let `PosTicket` watch it).
- Ensure `_addToCart` continues to use `posBranchId`.

#### [MODIFY] [pos_ticket.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/pos/presentation/components/pos_ticket.dart)
- Update `_TicketItemRow` to use `stockByBranchProvider` with `posBranchId` instead of the global `stockProvider`.
- Pass `posBranchId` to `create-invoice` route in the `extra` map.

### [Component] Sales & Invoices
#### [MODIFY] [create_invoice_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/sales/presentation/create_invoice_screen.dart)
- Update constructor to accept an optional `branchId`.
- If `branchId` is provided:
    - Use it for initialization.
    - Hide the branch selection dropdown in the AppBar (or make it read-only).
    - Use it for all stock validation and submission logic.
- Ensure `_submit` uses the provided `branchId` instead of reading from `currentBranchIdProvider`.

#### [MODIFY] [sale_detail_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/sales/presentation/sale_detail_screen.dart)
- In `clone_invoice` logic, pass the original `sale.branchId` to the `create-invoice` route.

### [Component] Routing
#### [MODIFY] [routes.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/core/routes.dart)
- Update `create-invoice` route to extract `branchId` from `extra` and pass it to `CreateInvoiceScreen`.

### [Component] UI Reactivity & Stabilization
#### [MODIFY] [sale_detail_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/sales/presentation/sale_detail_screen.dart)
- Fix UI logic in `PopupMenuButton` to correctly hide "Approve" and "Reject" buttons based on the current sale status.
- Add explicit `ref.invalidate` calls for `saleDetailProvider`, `salePaymentsProvider`, and `creditNotesForSaleProvider` after successful server mutations (delete payment, approve/reject, issue credit note).
- Ensure that the "Delete Payment" button correctly invalidates the `saleDetailProvider` since a payment deletion updates the `amount_paid` and potentially the `status` of the sale.
- Add a success SnackBar for more actions to provide immediate visual feedback that the request completed on the server.

## Verification Plan

### Automated Tests
- Run `dart analyze` to ensure no new lints or errors.

### Manual Verification
1.  **POS Branch Switch**: Change branch in POS. Verify the items grid updates and the Ticket stock validation (plus/minus) uses the new branch's stock.
2.  **Create Invoice**: From POS, tap "Create Invoice". Verify the screen shows the correct branch and does NOT allow changing it.
3.  **Cloning**: Open an existing invoice from "Downtown". Tap "Clone Invoice". Verify the new invoice screen defaults to "Downtown" and the branch selector is hidden.
4.  **Stock Validation**: Attempt to add an item that has 0 stock in the current branch but >0 in another. Verify it is blocked in the Ticket and Create Invoice screen.
