# Navigation & Dashboard UI Overhaul Implementation Plan

> **For AI Agents:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a global expandable side drawer for navigation and completely redesign the Dashboard into a soft-minimal KPI interface.

**Architecture:** We will replace the bottom navigation bar pattern inside `AppShell` with a standard `Drawer` containing nested `ExpansionTile` widgets to match Zoho's expanding tree. The Dashboard will be stripped of navigational tiles and replaced with aggregated KPI metric cards.

**Tech Stack:** Flutter Framework, Riverpod, GoRouter.

---
### Task 1: Global Sidebar Drawer Component
**Files:**
- Create: `lib/core/widgets/app_drawer.dart`

**Step 1: Implement the Drawer UI**
Create an `AppDrawer` widget containing a `ListView`.
- Header: User Profile/Tenant info.
- `ListTile`: Dashboard (`/`)
- `ExpansionTile`: Inventory
  - `ListTile`: Items (`/products`)
  - `ListTile`: Item Groups (`/products/groups`)
  - `ListTile`: Composite Items (`/products/composite`)
  - `ListTile`: Stock Adjustments (`/products/batch-adjust`)
- `ListTile`: Point of Sale (`/pos`)
- `ExpansionTile`: Sales
  - `ListTile`: Invoices/Sales (`/sales`)
- `ExpansionTile`: Settings
  - `ListTile`: Branches (`/settings/branches`)
  - `ListTile`: Staff (`/settings/staff`)

### Task 2: Update AppShell and Routes
**Files:**
- Modify: `lib/core/app_shell.dart`
- Modify: `lib/core/routes.dart`

**Step 1: Replace BottomNavigationBar in AppShell**
Modify `AppShell` to remove the `BottomNavigationBar`. Ensure the main `Scaffold` includes `drawer: const AppDrawer()` and `body: widget.navigationShell`. Keep an `AppBar` with a hamburger menu icon (this is critical so the user can open it). Add simple visual logic: highlight the currently active Drawer item based on `GoRouter.of(context).state`.

**Step 2: Add New Routes**
Add dummy path declarations in `routes.dart` for Item Groups (`groups`) and Composite Items (`composite`) within the Products StatefulShellBranch. Ensure navigating from the drawer uses `context.go()`.

### Task 3: Soft Minimal Dashboard Redesign
**Files:**
- Modify: `lib/features/dashboard/presentation/dashboard_screen.dart` (or `dashboard_layout.dart`)
- Modify: `lib/core/theme/app_tokens.dart`

**Step 1: Refine Theme Tokens**
Add subtle grays (e.g., `Color(0xFFF9FAFB)`), extremely soft shadows, and clean modern card styling constraints to `AppTokens`. Ensure primary buttons/accents feel professional and less harsh.

**Step 2: Build KPI Cards**
Remove the old navigational 2x2 action button grid in the dashboard.
Replace it with summary metrics:
- "Top Selling Items" (Placeholder card)
- "Recent Activities" (Placeholder card)
- "Sales Overview" (Placeholder card)

Adopt a "soft minimal" design system: large white cards, subtle gray backgrounds, soft borders, and an elegant layout akin to the Zoho web dashboard screenshots. Use empty state shimmer loaders where data will typically fetch.
