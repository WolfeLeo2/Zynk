# Invoice Workflow Extensions

Three new owner-level (and permissioned) actions to extend the invoice lifecycle.

---

## User Review Required

> [!IMPORTANT]
> **Answers needed before implementation begins.**
> See the Open Questions section below.

---

## Background

The current invoice state machine is:

```
pending_approval → (approve_sale) → approved → (fulfill_sale) → fulfilled
                 ↘ (reject_sale) → rejected
                 ↘ (void_sale)   → voided
```

The three new features add the following transitions:

| Feature | Who | Transition |
|---|---|---|
| **Unapprove** | Owner only | `approved → pending_approval` |
| **Edit Approved** | Owner only | `approved → pending_approval → edit_invoice screen` (one action) |
| **Final Approve (Fast-Track)** | Owner only | `pending_approval → approved` (skips 2-approval requirement) |

---

## Confirmed Design Decisions

| # | Decision |
|---|---|
| Q1 — Unapprove + fulfilled stock | **Auto-reverse** — increment stock back, reset `fulfillment_status = unfulfilled` |
| Q2 — Unapprove + payments | **Revert payments to zero** — delete `sale_payments` rows, reset `amount_paid = 0`, `payment_status = unpaid` |
| Q3 — Edit Approved flow | **Yes** — call `unapprove_sale` first, then push `/sales/:id/edit` route |
| Q4 — Final Approve count | **Keep `required_approvals` as-is**, set `approval_count = required_approvals` to satisfy threshold |
| Permissions | **Final Approve and Unapprove are NOT owner-only** — available to anyone with the `approve_invoices` permission flag |

---

## Proposed Changes

### 1. Supabase Edge Function — `manage-sale`

#### [MODIFY] [index.ts](file:///Users/app/AndroidStudioProjects/Zynk/supabase/functions/manage-sale/index.ts)

**Add 2 new actions to `ACTION_PERMISSIONS`:**
```ts
unapprove_sale: "approve_invoices",
final_approve_sale: "approve_invoices",
```

**Add `case "unapprove_sale"`:**
- Fetch the sale; assert `status === 'approved'`.
- If `fulfillment_status === 'fulfilled'`: increment stock back for all items, set `fulfillment_status = 'unfulfilled'`.
- Delete all `sale_payments` rows for this `sale_id`; reset `amount_paid = 0`, `payment_status = 'unpaid'`.
- Delete all `sale_approvals` rows for this `sale_id` with `decision = 'approved'`.
- Update `sales`: `status = 'pending_approval'`, `approval_count = 0`, `approved_by = null`.
- Return `{ status: 'pending_approval', sale_id }`.

**Add `case "final_approve_sale"`:**
- Fetch the sale; assert `status === 'pending_approval'`.
- Permission check uses standard `approve_invoices` flag (no owner restriction).
- Clear any existing `sale_approvals` for this sale (start fresh audit trail).
- Insert a single `sale_approvals` row with `decision = 'approved'`.
- Update `sales`: `status = 'approved'`, `approval_count = required_approvals`, `approved_by = userId`.
- Return `{ status: 'approved', sale_id }`.

---

### 2. Dart — `SalesService`

#### [MODIFY] [sales_service.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/core/services/sales_service.dart)

Add two new thin wrappers using the existing `_manageSale` helper:

```dart
/// Reverts an approved invoice back to pending_approval. Owner-only.
Future<Map<String, dynamic>> unapproveSale(String saleId, {required String tenantId}) =>
    _manageSale('unapprove_sale', {'sale_id': saleId, 'tenant_id': tenantId});

/// Owner fast-track: bypasses dual-approval and immediately approves.
Future<Map<String, dynamic>> finalApproveSale(String saleId, {required String tenantId}) =>
    _manageSale('final_approve_sale', {'sale_id': saleId, 'tenant_id': tenantId});
```

---

### 3. Flutter UI — `SaleDetailScreen`

#### [MODIFY] [sale_detail_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/sales/presentation/sale_detail_screen.dart)

**A. New menu items in the `PopupMenuButton`:**

| Action | Condition |
|---|---|
| "Unapprove Invoice" | `sale.status == approved && canApprove` |
| "Edit Approved Invoice" | `sale.status == approved && canApprove && canEdit` |
| "Final Approve" | `sale.status == pendingApproval && canApprove && !hasCurrentUserApproved` |

**B. New `_handleAction` cases:**

```dart
case 'unapprove':
  // Confirm dialog: "This will revert the invoice to Pending Approval..."
  await service.unapproveSale(sale.id, tenantId: sale.tenantId);
  // Invalidate providers, show snack
  break;

case 'edit_approved':
  // Unapprove first, then navigate to edit
  await service.unapproveSale(sale.id, tenantId: sale.tenantId);
  // Invalidate, then push edit route
  if (context.mounted) context.push('/sales/${sale.id}/edit');
  break;

case 'final_approve':
  // Confirm dialog: "This will immediately approve the invoice, bypassing normal approval flow."
  await service.finalApproveSale(sale.id, tenantId: sale.tenantId);
  // Invalidate providers, show snack
  break;
```

**C. `EditInvoiceScreen` status guard relaxation:**
Currently the server (`update_draft`) already blocks non-`pending_approval` invoices. Since "Edit Approved" calls `unapprove_sale` first, no client-side guard change is needed — the invoice will be `pending_approval` by the time the edit screen opens.

---

### 4. Flutter UI — `EditInvoiceScreen` (optional UX polish)

#### [MODIFY] [edit_invoice_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/sales/presentation/edit_invoice_screen.dart)

- Add a banner at the top of the edit screen if the invoice was previously approved: 
  `"This invoice was previously approved. Saving will require re-approval."`
- This is read from a route `extra` parameter (e.g., `{'wasApproved': true}`).

---

## Verification Plan

### Automated
- Run `dart analyze` after all Dart changes.
- Deploy updated edge function: `supabase functions deploy manage-sale`.

### Manual flows to test
1. **Unapprove Happy Path**: Approved, zero-payment invoice → tap Unapprove → status reverts to `pending_approval`, approval timeline clears.
2. **Unapprove Blocked**: Approved invoice with payment → Unapprove option should be hidden (or show error).
3. **Edit Approved**: Tap "Edit Approved Invoice" → invoice moves to `pending_approval` → edit screen opens with "was approved" banner → save → invoice is now `pending_approval` awaiting re-approval.
4. **Final Approve Happy Path**: Owner on a `pending_approval` invoice → tap "Final Approve" → status immediately becomes `approved` without needing a second approver.
5. **Final Approve Permission Check**: A manager (non-owner) should NOT see the Final Approve option in the menu.
