# Branch Filter Chips in Adjustments Screen Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add the shared `BranchFilterChips` component into the `AppBar.bottom` of `AdjustmentsScreen` so users can filter stock adjustments by branch when viewing all branches.

**Architecture:** A local Riverpod `_adjustmentBranchFilterProvider` (`Notifier<String?>`) tracks the active branch filter on `AdjustmentsScreen`. The `AppBar.bottom` is given a `PreferredSize` widget containing a `Column` with `BranchFilterChips` on top and `_StatusFilterBar` below, with dynamic height based on branch visibility. `_adjustmentsProvider` is invoked with `effectiveBranchId = isAllBranches ? branchFilter : globalBranchId`.

**Tech Stack:** Flutter, Flutter Riverpod (NotifierProvider), Phosphor Icons, Zynk shared widgets (`BranchFilterChips`).

---

### Task 1: Add Branch Filter Provider and Wire Query in `AdjustmentsScreen`

**Files:**
- Modify: `lib/features/products/presentation/adjustments_screen.dart:18-45`
- Modify: `lib/features/products/presentation/adjustments_screen.dart:51-66`

**Step 1: Define `_BranchFilterNotifier` and provider**

Add `_BranchFilterNotifier` and `_adjustmentBranchFilterProvider`:

```dart
class _BranchFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null; // null = All Branches

  void setBranch(String? branchId) => state = branchId;
}

final _adjustmentBranchFilterProvider =
    NotifierProvider.autoDispose<_BranchFilterNotifier, String?>(
      _BranchFilterNotifier.new,
    );
```

**Step 2: Calculate `effectiveBranchId` and pass to `_adjustmentsProvider`**

In `AdjustmentsScreen.build`:
```dart
    final globalBranchId = ref.watch(currentBranchIdProvider);
    final branchFilter = ref.watch(_adjustmentBranchFilterProvider);
    final isAllBranches = globalBranchId == null || globalBranchId == 'all';
    final effectiveBranchId = isAllBranches ? branchFilter : globalBranchId;

    final adjustmentsAsync = ref.watch(
      _adjustmentsProvider((tenantId: tenantId, branchId: effectiveBranchId)),
    );
```

---

### Task 2: Integrate `BranchFilterChips` into `AppBar.bottom`

**Files:**
- Modify: `lib/features/products/presentation/adjustments_screen.dart:1-15`
- Modify: `lib/features/products/presentation/adjustments_screen.dart:89-97`

**Step 1: Add import for `BranchFilterChips`**

```dart
import 'package:zynk/shared/widgets/branch_filter_chips.dart';
```

**Step 2: Update `AppBar.bottom` with dynamic `PreferredSize`**

Check whether `BranchFilterChips` should be rendered:
```dart
    final branches = ref.watch(branchesProvider).value ?? [];
    final showBranchFilter = isAllBranches && branches.length > 1;
    final bottomHeight = (showBranchFilter ? 48.0 : 0.0) + 52.0;
```

Update `AppBar.bottom`:
```dart
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(bottomHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBranchFilter)
                BranchFilterChips(
                  selectedBranchId: branchFilter,
                  onSelected: (v) => ref
                      .read(_adjustmentBranchFilterProvider.notifier)
                      .setBranch(v),
                ),
              _StatusFilterBar(
                selected: statusFilter,
                onSelected: (v) => ref
                    .read(_adjustmentStatusFilterProvider.notifier)
                    .setStatus(v),
              ),
            ],
          ),
        ),
```

---

### Task 3: Verification

**Files:**
- `lib/features/products/presentation/adjustments_screen.dart`

**Step 1: Run Dart Analyze**

Run: `dart analyze lib/features/products/presentation/adjustments_screen.dart`
Expected: `No issues found!`

**Step 2: Run test suite**

Run: `flutter test test/features/products/domain/stock_adjustment_math_test.dart`
Expected: All tests pass.
