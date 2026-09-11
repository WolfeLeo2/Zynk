# Branch Filter Chips in Adjustments Review Screen — Design Document

## Summary

Add the shared [`BranchFilterChips`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/shared/widgets/branch_filter_chips.dart) component to the bottom section of the AppBar in [`AdjustmentsScreen`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustments_screen.dart) (`/adjustment-review`). This allows users to filter stock adjustments by branch directly on the screen when viewing all branches.

## Context & Requirements

- **Screen**: [`AdjustmentsScreen`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustments_screen.dart) (`/adjustment-review`).
- **Placement**: Bottom section of the AppBar (`AppBar.bottom`), stacked directly above the status filter bar (`_StatusFilterBar`).
- **Component**: Reuse the existing [`BranchFilterChips`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/shared/widgets/branch_filter_chips.dart) widget.
- **Behavior**:
  - Automatically renders when the user has multiple branches and the global selection is "All Branches" (`currentBranchId == null || currentBranchId == 'all'`).
  - Hides automatically when scoped to a single branch.
  - Tapping a branch chip filters the adjustments stream to that branch. Tapping "All Branches" shows adjustments across all branches.
  - Status filter chips (All, Pending, Approved, Rejected) apply on top of the branch-filtered adjustments.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Placement | `AppBar.bottom` | User requested branch filter chips at the bottom section of the AppBar. Keeps filter controls unified in the header. |
| Component | [`BranchFilterChips`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/shared/widgets/branch_filter_chips.dart) | Reuses existing shared widget that already handles horizontal chip scrolling, storefront icon, and "All Branches" detection. |
| State Management | `_adjustmentBranchFilterProvider` (autoDispose `Notifier<String?>`) | Local to [`adjustments_screen.dart`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustments_screen.dart). Matches the pattern of `_adjustmentStatusFilterProvider`. |
| Dynamic Height | Compute `preferredSize.height` based on branch visibility | Prevents empty vertical dead space in `AppBar.bottom` when the branch filter is hidden (single branch user or locked branch). |

## UI Architecture

```
AppBar
├── leading (Drawer button on mobile)
├── title: "Stock Adjustments"
├── actions: [Stock Report button]
└── bottom: PreferredSize (height: showBranchFilter ? 100 : 52)
    └── Column
        ├── BranchFilterChips (visible if isAllBranches && branches.length > 1)
        └── _StatusFilterBar (All | Pending | Approved | Rejected)
```

## State & Data Flow

```
User taps Branch Chip
        │
        ▼
_adjustmentBranchFilterProvider.setBranch(branchId)
        │
        ▼
effectiveBranchId = isAllBranches ? branchFilter : globalBranchId
        │
        ▼
_adjustmentsProvider((tenantId: tenantId, branchId: effectiveBranchId))
        │
        ▼
repository.watchAllStockAdjustments(tenantId, effectiveBranchId)
        │
        ▼
Stream updates ListView with branch-filtered StockAdjustment items
```

## Files Touched

| File | Changes |
|---|---|
| [`lib/features/products/presentation/adjustments_screen.dart`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustments_screen.dart) | Add `_adjustmentBranchFilterProvider`, integrate `BranchFilterChips` into `AppBar.bottom`, pass `effectiveBranchId` to `_adjustmentsProvider`. |
