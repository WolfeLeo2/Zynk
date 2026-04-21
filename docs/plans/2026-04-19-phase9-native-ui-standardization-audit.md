# Phase 9 Native UI Standardization Audit (Thorough Pass)

Date: 2026-04-19

## Scope Audited

1. Phase 9 target files:
- lib/features/dashboard/presentation/dashboard_layout.dart
- lib/core/widgets/app_drawer.dart
- lib/features/products/presentation/inventory_adjustment_screen.dart
- lib/features/sales/presentation/sale_detail_screen.dart

2. Broader loading-state audit across all user UI files:
- Searched all lib/**/*.dart for CircularProgressIndicator, LinearProgressIndicator, CupertinoActivityIndicator.
- Found repeated non-shimmer loading indicators in auth, products, sales, settings, and POS flows.

## Findings and Planned Changes (Exact)

### A. lib/core/widgets/app_drawer.dart

Current findings:
- Custom tile composition uses Material + InkWell + Row wrappers.
- Profile footer uses custom Container card-like composition.

Planned standardization:
1. Replace custom item rows with native NavigationDrawer + NavigationDrawerDestination.
2. Keep route semantics identical; selected index maps to currentPath.
3. Replace profile footer custom Container with native Card + ListTile (leading avatar, title displayName, subtitle status).
4. Preserve existing icons/labels and drawer grouping headers.

Widgets to use:
- NavigationDrawer
- NavigationDrawerDestination
- Card
- ListTile

### B. lib/features/dashboard/presentation/dashboard_layout.dart

Current findings:
- Global branch selector was removed from app bar usage, but BranchSelector helper classes remain in file (dead UI code).
- Several custom Container wrappers still present for selector/badge classes not currently mounted.

Planned standardization:
1. Remove dead BranchSelector/_ReadOnlyBranchBadge/_BranchDropdown/_BranchSkeleton from this file.
2. Keep active app bars using SliverAppBar and existing Material widgets only.
3. If branch badge is needed again in future, re-introduce with InputChip/ChoiceChip, not custom painted containers.

Widgets to use:
- SliverAppBar
- ListTile (if compact badge content needs to be shown)
- InputChip / ChoiceChip (if selector comes back)

### C. lib/features/products/presentation/inventory_adjustment_screen.dart

Current findings:
- Panel and card sections rely on many custom Container wrappers for visual structure.
- Loading states still use CircularProgressIndicator and LinearProgressIndicator in multiple places.

Planned standardization:
1. Replace major panel wrappers with Card/OutlinedCard for native Material structure.
2. Keep SearchBar, ListTile, SwitchListTile.adaptive, Chip (already native).
3. Replace bottom action custom Container with BottomAppBar + FilledButton.icon.
4. Replace CircularProgressIndicator/LinearProgressIndicator loading states with shimmer skeleton components.
5. Keep quantity controls with IconButton.filledTonal + TextField (already native and acceptable).
6. Manage reasons sheet: keep DraggableScrollableSheet, replace loading indicators with shimmer list placeholders.

Widgets to use:
- Card / OutlinedCard
- BottomAppBar
- FilledButton.icon
- ListTile
- Shimmer.fromColors placeholders (instead of progress indicators)

### D. lib/features/sales/presentation/sale_detail_screen.dart

Current findings:
- Heavy custom Container composition in status hero, items list, payments, totals, and sheets.
- Multiple CircularProgressIndicator usages remain (button/loading states).
- Bottom sheets render manual drag handle container.

Planned standardization:
1. Convert status hero to Card + ListTile + Chip for badges.
2. Convert items and payments rows to ListTile inside Card sections.
3. Keep action controls as FilledButton/OutlinedButton/TextButton (already largely compliant).
4. Replace manual drag-handle containers with showDragHandle: true on showModalBottomSheet.
5. Replace CircularProgressIndicator loading UIs with shimmer placeholders; for button busy states, use shimmer capsule in label area.
6. Keep popup menus and confirmation dialogs (native and compliant).

Widgets to use:
- Card / ListTile
- Chip
- showModalBottomSheet(showDragHandle: true)
- Shimmer placeholders for loading

## Broader Loading-State Backlog (Outside Phase 9 Core Files)

High-priority files still using non-shimmer loading indicators (from full-lib audit):
- lib/features/auth/sign_in_screen.dart
- lib/features/auth/sign_up_screen.dart
- lib/features/auth/verify_email_screen.dart
- lib/features/pos/presentation/pos_screen.dart
- lib/features/pos/presentation/components/pos_product_card.dart
- lib/features/products/presentation/composite_item_details_screen.dart
- lib/features/products/presentation/item_groups_screen.dart
- lib/features/settings/presentation/settings_screen.dart
- lib/features/settings/presentation/add_staff_screen.dart
- lib/features/settings/presentation/staff_screen.dart
- lib/features/settings/presentation/branches_screen.dart

Planned approach:
- Phase 9.5 (global loading sweep): replace all remaining Circular/Linear indicators in user-facing list/detail flows with shared shimmer widgets.

## Execution Order Recommendation

1. Phase 9 Task A: app_drawer and dashboard dead-code cleanup.
2. Phase 9 Task B: inventory_adjustment_screen refactor to Card/BottomAppBar + shimmer loading.
3. Phase 9 Task C: sale_detail_screen structural standardization + shimmer conversion.
4. Phase 9.5 Task D: global loading indicator sweep across remaining files.
