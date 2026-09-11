# Adjustment Detail Screen Multi-Branch Display & Official Chip — Design Document

## Summary

Update [`AdjustmentDetailScreen`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustment_detail_screen.dart) to:
1. Show all involved branch names (comma-separated, e.g., "Branch A, Branch B") in the top summary metadata section, with dynamic label (`Branch` for 1 branch, `Branches` for multiple branches).
2. Replace custom inline `Container` branch badges in item rows with official Flutter `Chip` widgets.

## Context & Problem

1. **Top Metadata Summary (`_MetadataSection`)**:
   Previously, [`_MetadataSection`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustment_detail_screen.dart#L209-L247) was only passed `first: StockAdjustment` and looked up `first.branchId`. When an adjustment bundle involved multiple branches, only the first branch was shown.
2. **Inline Branch Badge (`_AdjustmentItemRow`)**:
   In item rows, the branch badge was implemented using a custom `Container` with manual padding and `BoxDecoration`, rather than the standard Flutter `Chip` widget.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Multi-branch display in metadata | Comma-separated string (`branchNames.join(', ')`) | User preference. Fits cleanly into `_MetaItem` with automatic line wrapping. |
| Dynamic metadata label | `Branches` when `branchNames.length > 1`, else `Branch` | Clear and accurate representation of the adjustment scope. |
| Item row badge component | Flutter official `Chip` | Replaces custom `Container` with native Material 3 chip widget (`VisualDensity.compact`, `MaterialTapTargetSize.shrinkWrap`). |
| Colors & Styling | `colorScheme.secondaryContainer` & `colorScheme.onSecondaryContainer` | Adheres strictly to codebase rule: use `colorScheme` instead of raw `AppTokens`. |

## Architecture & Code Changes

### 1. `_MetadataSection`
Pass `items: items` instead of `adjustment: first`.
```dart
class _MetadataSection extends ConsumerWidget {
  final List<StockAdjustment> items;
  const _MetadataSection({required this.items});
```
Derive unique branch names:
```dart
final branchIds = items.map((i) => i.branchId).toSet();
final branchNames = branchIds.map((id) {
  return branches.firstWhere(
    (b) => b.id == id,
    orElse: () => Branch(id: id, tenantId: '', name: id),
  ).name;
}).toList();

final branchLabel = branchNames.length > 1 ? 'Branches' : 'Branch';
final branchValue = branchNames.isNotEmpty ? branchNames.join(', ') : 'Unknown';
```

### 2. `_AdjustmentItemRow`
Replace custom `Container` with official Flutter `Chip`:
```dart
if (branchName != null) ...[
  const SizedBox(height: 6),
  Chip(
    avatar: PhosphorIcon(
      PhosphorIconsRegular.storefront,
      size: 14,
      color: colorScheme.onSecondaryContainer,
    ),
    label: Text(branchName!),
    labelStyle: textTheme.labelSmall?.copyWith(
      color: colorScheme.onSecondaryContainer,
      fontWeight: FontWeight.w600,
    ),
    backgroundColor: colorScheme.secondaryContainer,
    side: BorderSide.none,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  ),
],
```

## Files Touched

| File | Changes |
|---|---|
| [`lib/features/products/presentation/adjustment_detail_screen.dart`](file:///Users/leo/AndroidStudioProjects/Zynk/lib/features/products/presentation/adjustment_detail_screen.dart) | Update `_MetadataSection` to accept `items` and render comma-separated branches; replace custom container badge with official `Chip` in `_AdjustmentItemRow`. |
