# Commissions UI Revamp Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal**: Revamp the `CommissionsReportScreen` to transition from a functional list to a premium, "corporate minimalist" dashboard.

**Architecture**: Refactor to `NestedScrollView` with a `SliverAppBar` hero section. Use local UI providers for selection states.

**Tech Stack**: Flutter, Riverpod, Phosphor Icons, M3E Card List.

---

### Task 1: Month Selection Infrastructure

**Files**:
- Modify: `lib/features/reports/presentation/commissions_report_screen.dart`

**Step 1: Implement `_MonthPickerSheet`**
Add a stateful or stateless widget that displays a 4x3 grid of months for the user to select from.

**Step 2: Implement `_MonthPill`**
Create the clickable header widget that displays the current month and triggers the sheet.

**Step 3: Update `_SelectedMonthNotifier`**
Ensure it supports full `DateTime` selection and refreshes the list.

**Step 4: Commit**
`git commit -m "feat(commissions): add month picker pill and selection sheet"`

---

### Task 2: Hero Header & SliverAppBar

**Files**:
- Modify: `lib/features/reports/presentation/commissions_report_screen.dart`

**Step 1: Refactor to `NestedScrollView`**
Change the layout structure to support a collapsing header.

**Step 2: Implement `FlexibleSpaceBar`**
Add the gradient background and the KPI row.

**Step 3: Commit**
`git commit -m "feat(commissions): implement hero sliver app bar with kpis"`

---

### Task 3: Filtering & Status Chips

**Files**:
- Modify: `lib/features/reports/presentation/commissions_report_screen.dart`

**Step 1: Replace SegmentedButtons with `FilterChip`s**
Implement the horizontal chip bar for status filtering.

**Step 2: Commit**
`git commit -m "feat(commissions): replace segmented buttons with filter chips"`

---

### Task 4: Salesperson Card Redesign

**Files**:
- Modify: `lib/features/reports/presentation/commissions_report_screen.dart`

**Step 1: Implement `_SalespersonCard`**
Build the hierarchical card layout for the main list.

**Step 2: Final Verification**
Run `dart analyze` and verify UI on the device.

**Step 3: Commit**
`git commit -m "feat(commissions): redesign salesperson cards for better hierarchy"`
