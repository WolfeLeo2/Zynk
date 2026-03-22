# Global Soft Minimal UI Redesign Plan

> **For AI Agents:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Pivot the entire app's visual structure to a Soft Minimal aesthetic (off-white backgrounds, floating white cards, borderless filled inputs) while strictly retaining the brand's Electric Blue and Neon Lime colors.

**Architecture:** We will rewrite the core tokens in `app_tokens.dart` and overhaul the overarching `ThemeData`. We will update the Dashboard and replace `AppShell` with the global drawer.

---
### Task 1: Theme & Tokens Overhaul
**Files:**
- Modify: `lib/core/theme/app_tokens.dart`
- Modify: `lib/core/theme/theme.dart`

**Step 1:** In `AppTokens`, keep `brandPrimary` (ElectricBlue) and `brandSecondary` (NeonLime). Introduce `offWhiteCanvas` (`0xFFF9FAFB`) for the light canvas base and keep pure white for `lightSurface`.
**Step 2:** In the `ThemeData`, redefine `InputDecorationTheme` away from heavy `OutlineInputBorder`. Use a filled decoration (color `#F3F4F6` for light mode) with `InputBorder.none` or a transparent border, and only show a primary-colored `OutlineInputBorder` on `focusedBorder`.
**Step 3:** Overhaul `CardTheme` for softness—zero elevation, a very subtle shadow (e.g., `blurRadius: 16`, `color: black(0.04)`), and `Radius.circular(16)`.

### Task 2: Implement Global Side Drawer Navigation
**Files:**
- Create: `lib/core/widgets/app_drawer.dart`
- Modify: `lib/core/app_shell.dart`
- Modify: `lib/core/routes.dart`

**Step 1:** Remove `BottomNavigationBar` from `AppShell`.
**Step 2:** Ensure the global `Scaffold` uses `drawer: const AppDrawer()`. Add logic allowing mobile users to access it via hamburger menu and iPad users to see a persistent or off-canvas drawer.
**Step 3:** The `AppDrawer` will use `ExpansionTile` widgets to group functional areas: Inventory (Items, Groups, Composites, Adjustments), Sales (POS, Invoices), Settings. Update `routes.dart` to support nested paths gracefully.

### Task 3: Soft Minimal Dashboard Redesign
**Files:**
- Modify: `lib/features/dashboard/presentation/dashboard_screen.dart`

**Step 1:** Remove the heavy 2x2 grid of quick-action navigational buttons.
**Step 2:** Replace the dashboard with a "Bento-style" layout of clean, KPI cards on the canvas. Colors get picked from the apptheme/tokens. (e.g. "Total Inventory Value", "Recent Adjustments", "Low Stock Alerts, Pending Invoices, etc etc"). Use shimmer loaders for async metrics.
