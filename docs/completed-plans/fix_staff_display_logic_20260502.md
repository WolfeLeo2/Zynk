# Fix Staff Display Logic for Inventory Adjustments

Currently, inventory adjustments are attributed to the `created_by` field, which contains an Auth User ID. The system attempts to join this ID against the `staff_members` table, but since `staff_members` records use independent UUIDs, the join fails, and the staff name is always null in the history.

This plan adds a dedicated `salesperson_id` column to the `stock_adjustments` table to correctly link adjustments to the staff member selected in the UI.

## User Review Required

> [!IMPORTANT]
> This change requires a database migration to add the `salesperson_id` column to the `stock_adjustments` table. I will perform this using the Supabase MCP tool.

## Proposed Changes

### Database

#### [MODIFY] Supabase Migration
Add `salesperson_id` to `stock_adjustments` to track the staff member responsible for the adjustment.

```sql
ALTER TABLE public.stock_adjustments 
ADD COLUMN salesperson_id UUID REFERENCES public.staff_members(id) ON DELETE SET NULL;
```

---

### Models

#### [MODIFY] [schema_models.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/core/models/schema_models.dart)
Update the `StockAdjustment` class to include the `salespersonId` field and update serialization.

---

### Repository

#### [MODIFY] [repository.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/data/local/repository.dart)
- Update `watchAllStockAdjustments` and `watchStockAdjustmentsByBundle` to join `staff_members` on `sa.salesperson_id` instead of `sa.created_by`.
- Update `batchAdjustStock` and `batchAdjustStockForGroup` to accept and persist `salespersonId`.

---

### UI Components

#### [MODIFY] [inventory_adjustment_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/products/presentation/inventory_adjustment_screen.dart)
Pass the `id` of the `_selectedAdjuster` (which is a `StaffMember`) to the repository when submitting the adjustment.

#### [MODIFY] [adjustment_detail_screen.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustment_detail_screen.dart)
Refine the fallback logic to prioritize `staffName` (from the join) and use `adjusterName` (the user who performed the action) as a backup.

---

## Verification Plan

### Automated Tests
- Run `dart analyze` to ensure no regressions.
- Verify the SQL migration executes successfully.

### Manual Verification
1. Open the **Inventory Adjustment** screen.
2. Select a specific **Staff Member** from the "Adjuster" dropdown.
3. Perform an adjustment.
4. Navigate to the **Adjustment History** and view the details of the new adjustment.
5. Confirm that the **"Adjusted By"** field correctly displays the name of the selected staff member.
6. Verify that for old adjustments (where `salesperson_id` is null), the UI still falls back to the `adjusterName`.
