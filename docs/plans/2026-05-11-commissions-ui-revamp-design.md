# Design: Commissions UI Revamp (Corporate Minimalism)

Date: 2026-05-11
Topic: Commissions UI Revamp
Status: Approved

## Overview
Revamp the `CommissionsReportScreen` to transition from a functional list to a premium, "corporate minimalist" dashboard. The design focuses on visual hierarchy, intentional spacing, and seamless interactions, drawing inspiration from Zoho, Google Wallet, and OneUI.

## Design Goals
1.  **Immersive Header**: Utilize a `SliverAppBar` to house a "Hero" summary section with rich KPIs.
2.  **Simplified Month Selection**: Implement a "Clickable Pill" for month switching.
3.  **Consistent Filtering**: Use `FilterChips` for status selection (All, Pending, Paid), matching the app's design system.
4.  **Intentional Card Layout**: Redesign salesperson items to emphasize names, activity counts, and monetary values.

## Components

### 1. `SliverAppBar` & Hero Section
- **Expanded Height**: ~200px.
- **Background**: Subtle mesh gradient from `primary` to `surface`.
- **Month Pill**: A `Tonal` or `Glassmorphic` button in the center: `[ May 2026 ▾ ]`.
    - Opens a `MonthPickerSheet` (Bottom Sheet) with a grid of months.
- **KPI Row**: Three key metrics displayed with high-contrast typography:
    - **Total Sales**: Primary color.
    - **Total Pending**: Secondary/Orange (Warning).
    - **Total Paid**: Success/Green.

### 2. Status Filter Bar
- A pinned `SliverPersistentHeader` or a simple row in the list.
- Uses `FilterChip` widgets instead of `SegmentedButton`.
- Transitions should be smooth (cross-fade or sliding indicator).

### 3. Salesperson Item Cards
- **Container**: `M3ECardList` for consistent padding and rounded corners.
- **Visuals**:
    - **Avatar**: Circular initials with team-color background.
    - **Content**: Bold Name + Subtext (`"X Sales • Y Pending"`).
    - **Monetary Value**: Large, bold "Total Commission" on the right.
    - **Status Indicator**: A colored dot or subtle tonal background on the amount to indicate payment status.

## Interaction Flow
1.  User taps the **Month Pill** -> Bottom Sheet opens -> User selects month -> Pill updates and list refreshes.
2.  User taps a **Filter Chip** -> List animates to show filtered results.
3.  User taps a **Salesperson Card** -> Detailed Commission Sheet opens.

## Technical Considerations
- **Animations**: Use `AnimatedSwitcher` or `ImplicitlyAnimatedList` for status filtering.
- **Themes**: All colors must reference `Theme.of(context).colorScheme` or `AppTokens` derived from the theme to ensure dark/light mode compatibility.
- **Responsiveness**: Use `LayoutBuilder` to ensure the KPI row doesn't overflow on small screens.
