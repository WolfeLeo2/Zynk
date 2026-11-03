# Adjustment Detail Multi-Branch Display & Official Chip Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Display all involved branches (comma-separated) in the metadata section of `AdjustmentDetailScreen` and replace the custom container branch badge in item rows with official Flutter `Chip` widgets.

**Architecture:** `_MetadataSection` receives `List<StockAdjustment> items` instead of a single adjustment, resolves all unique `branchId` values to their branch names, and formats them as comma-separated values with dynamic label (`Branch` or `Branches`). In `_AdjustmentItemRow`, the custom `Container` branch badge is replaced with an official Material 3 `Chip` widget configured with `VisualDensity.compact` and `storefront` avatar.

**Tech Stack:** Flutter, Material 3 (`Chip`), Phosphor Icons, Riverpod.

---

### Task 1: Update `_MetadataSection` to Display All Involved Branches

**Files:**
- Modify: `lib/features/products/presentation/adjustment_detail_screen.dart:150-155`
- Modify: `lib/features/products/presentation/adjustment_detail_screen.dart:209-247`

**Step 1: Update `_MetadataSection` call site**

In `AdjustmentDetailScreen.build`:
Change:
```dart
_MetadataSection(adjustment: first),
```
To:
```dart
_MetadataSection(items: items),
```

**Step 2: Update `_MetadataSection` class definition and build method**

```dart
class _MetadataSection extends ConsumerWidget {
  final List<StockAdjustment> items;
  const _MetadataSection({required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final first = items.first;
    final branches = ref.watch(branchesProvider).value ?? [];
    final branchIds = items.map((i) => i.branchId).toSet();
    final branchNames = branchIds.map((id) {
      return branches
          .firstWhere(
            (b) => b.id == id,
            orElse: () => Branch(
              id: id,
              tenantId: '',
              name: id,
            ),
          )
          .name;
    }).toList();

    final branchLabel = branchNames.length > 1 ? 'Branches' : 'Branch';
    final branchValue =
        branchNames.isNotEmpty ? branchNames.join(', ') : 'Unknown';

    return Column(
      children: [
        _MetaItem(
          label: 'Reference',
          value:
              (first.referenceNumber != null &&
                  first.referenceNumber!.isNotEmpty)
              ? first.referenceNumber!
              : 'ADJ-${first.bundleId?.substring(0, 5).toUpperCase() ?? first.id.substring(0, 5).toUpperCase()}',
        ),
        _MetaItem(label: 'Account', value: first.adjusterName ?? 'System'),
        _MetaItem(
          label: 'Adjusted By',
          value: first.staffName ?? first.adjusterName ?? 'System',
        ),
        _MetaItem(label: 'Adjustment Type', value: 'Quantity'),
        _MetaItem(label: branchLabel, value: branchValue),
      ],
    );
  }
}
```

---

### Task 2: Replace Custom Branch Badge in `_AdjustmentItemRow` with Official `Chip`

**Files:**
- Modify: `lib/features/products/presentation/adjustment_detail_screen.dart:428-458`

**Step 1: Replace Container with Flutter `Chip`**

In `_AdjustmentItemRow`:
Change:
```dart
                if (branchName != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PhosphorIcon(
                          PhosphorIconsRegular.storefront,
                          size: 12,
                          color: colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          branchName!,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
```
To:
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

---

### Task 3: Verification

**Step 1: Run Dart Analyze**
Run: `dart analyze lib/features/products/presentation/adjustment_detail_screen.dart`
Expected: `No issues found!`

**Step 2: Run test suite**
Run: `flutter test test/features/products/domain/stock_adjustment_math_test.dart`
Expected: PASS
