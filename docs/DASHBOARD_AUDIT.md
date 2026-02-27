# Dashboard UI/UX & Data Audit

**Audit Date:** 2026-02-22  
**Reviewed Against:** Square Dashboard, Shopify POS Admin, Lightspeed Retail, Zoho Books Dashboard

---

## Executive Summary

The Zynk dashboard has a **strong visual foundation** — responsive layouts, sparkline metric cards, chart type toggles, and a clean mobile SliverAppBar. However, **~80% of the data displayed is hardcoded mock data**, the time range selector is non-functional, and several key metrics that real SME owners need are missing. The dashboard looks good but tells the owner almost nothing about their actual business.

---

## 1. Data Integrity Audit

### What's Real vs Mock

| Component | Data Source | Status |
|-----------|-----------|--------|
| **Total Revenue** | `salesDataProvider` → `repository.watchTotalSales()` | ✅ **Real** — reads from PowerSync `sales` table |
| **Daily Orders** | Hardcoded `'24'` in `metric_cards.dart:64` | ❌ **Mock** |
| **Avg Order Value** | Hardcoded `'Ksh 1,884'` in `metric_cards.dart:77` | ❌ **Mock** |
| **Low Stock Items** | Hardcoded `'3'` in `metric_cards.dart:90` | ❌ **Mock** |
| **Revenue Sparkline** | `revenueSparklineProvider` → hardcoded array `[32000, 35000, ...]` | ❌ **Mock** |
| **Orders Sparkline** | `ordersSparklineProvider` → hardcoded array `[18, 22, 20, ...]` | ❌ **Mock** |
| **All Trend %** | Hardcoded `12.5`, `8.3`, `5.2`, `-10.0` | ❌ **Mock** |
| **Sales Chart Data** | Hardcoded `FlSpot` values in `charts.dart` | ❌ **Mock** |
| **Payment Methods Pie** | Hardcoded `45%, 30%, 15%, 10%` splits | ❌ **Mock** |
| **Recent Orders List** | `ordersDataProvider` → hardcoded array of fake orders | ❌ **Mock** |
| **Top Selling Products** | `productsDataProvider` → hardcoded array of fake products | ❌ **Mock** |
| **Time Range Selector** | UI present, `selectedRange` is local state — **does nothing** | ❌ **Non-functional** |
| **Chart Type Toggle** | Works — switches between Line/Bar/Area | ✅ **Functional** (but on mock data) |
| **Pull to Refresh** | Invalidates providers — works but just re-fetches mock data | ⚠️ **Works technically** |
| **Branch Selector** | Reads from real `branchesProvider` | ✅ **Real** |
| **User Profile/Tenant** | Reads from real providers | ✅ **Real** |
| **Greeting** | Time-based greeting (`greetingProvider`) | ✅ **Real** |

**Verdict: Only 5 out of 17 dashboard data points are from real sources.**

---

## 2. UI/UX Analysis vs Industry Standards

### ✅ What Zynk Does Well

| Aspect | Detail | Industry Comparison |
|--------|--------|-------------------|
| **Responsive layout** | Mobile (SliverAppBar + sliver list) vs Desktop (2-column) | ✅ On par with Square & Shopify |
| **Metric cards with sparklines** | Mini-charts inside each KPI card | ✅ Better than Square (no sparklines), on par with Shopify |
| **Animated value counting** | Numbers animate up on load | ✅ Premium feel, Shopify does this |
| **Trend indicators** | ↑12.5% badges on each metric | ✅ Industry standard |
| **Chart type toggle** | Line/Bar/Area options | ✅ Nice touch — Zoho has this |
| **Haptic feedback** | On refresh, on actions | ✅ Mobile-native feel |
| **Skeleton loading states** | Shimmer placeholders while loading | ✅ Best practice — Shopify does this |
| **Branch selector** | Dropdown for multi-location businesses | ✅ Matches Lightspeed |
| **Quick actions row** | Products, Add, POS, Staff shortcuts | ✅ Square has similar "Shortcuts" |

### ❌ What Zynk Is Missing

| Missing Feature | What Competitors Do | Impact |
|----------------|--------------------|-|
| **Today's Sales summary** | Square shows "Today's Sales" as the primary hero card with actual revenue | 🔴 **Critical** — this is what owners check first |
| **Transaction count** | Square/Shopify show # of transactions today | 🔴 **Critical** — hardcoded as '24' currently |
| **Real-time updates** | Square updates dashboard live as sales happen | 🟡 **Important** — PowerSync streams enable this |
| **Functional time filter** | Square lets you filter by Today/Week/Month/Custom | 🔴 **Critical** — the selector exists but does nothing |
| **Sales by hour heatmap** | Square shows peak hours — essential for staffing | 🟡 **Important** for scheduling |
| **Employee performance** | Square shows sales-per-employee breakdown | 🟡 **Important** for accountability |
| **Gross profit** | Shopify shows revenue AND profit (revenue minus COGS) | 🔴 **Critical** — revenue alone is misleading |
| **Comparison period** | "vs last week" or "vs same day last month" | 🟡 **Important** — trends are guessed currently |
| **Cash drawer tracking** | Square tracks opening/closing balances | 🟡 **Important** for cash-heavy EA businesses |
| **Empty state guidance** | Shopify shows "No sales yet today — start your first sale" | 🟢 Nice-to-have |
| **Notifications/alerts** | Low stock alerts, overdue invoice alerts | 🟡 **Important** |

### ⚠️ UX Issues

| Issue | Detail | Recommendation |
|-------|--------|----------------|
| **3-second rule violation** | A new user cannot understand business health in 3 seconds — most numbers are meaningless mock data | Wire up real data |
| **Information hierarchy** | All 4 metric cards are equally weighted visually. Revenue should be more prominent. | Make "Today's Revenue" a hero card (2x size) |
| **Quick Actions placement** | On mobile, Quick Actions appear before metrics. Owner cares about numbers first. | Move metrics above Quick Actions |
| **No empty states** | If there are zero sales today, the dashboard shows 'Ksh 0' with a fake +12.5% trend — this is misleading | Show contextual empty states |
| **Staff button does nothing** | Quick Actions "Staff" button has `onTap: () {}` | Connect to staff management or remove |
| **Desktop chart sidebar** | Quick Actions + Payment Methods + Top Products stacked vertically — very long scroll | Consider tabs or collapsible sections |
| **No drill-down from charts** | Tapping a chart bar does nothing. Square lets you tap a day to see individual transactions. | Add tap-to-drill on charts |

---

## 3. Recommendations (Prioritized)

### P0 — Fix Immediately
1. **Wire up all metrics to real data** — Daily Orders, AOV, Low Stock, Trends
2. **Make the Time Range Selector functional** — pass selected range to all data providers
3. **Remove fake trend percentages** — show "N/A" or calculate from real historical data
4. **Fix Quick Actions Staff button** — either connect or remove

### P1 — Next Sprint
5. **Add "Today's Revenue" as a hero card** — bigger, at the top, with a live-updating counter
6. **Show gross profit** alongside revenue (requires `cost_price` data)
7. **Add real orders list** — query `sales` table with real data
8. **Add real top products** — query `sale_items` joined with `products`
9. **Add real payment methods pie** — query `payments` by method

### P2 — Future
10. **Sales by hour chart** — for staffing decisions
11. **Comparison periods** ("vs yesterday", "vs last week")
12. **Push notifications** for low stock and shift reminders
13. **Cash drawer management** — open/close register, expected vs actual
14. **Employee performance cards** — who sold the most today

---

## 4. Mobile Layout Order (Current vs Recommended)

### Current
1. SliverAppBar (greeting, profile, branch)
2. Quick Actions (Products, Add, POS, Staff)
3. Metric Cards (Revenue, Orders, AOV, Low Stock)
4. Sales Chart
5. Payment Methods Pie
6. Top Selling Products
7. Recent Orders

### Recommended (Industry Standard)
1. SliverAppBar (greeting, profile, branch)
2. **Hero: Today's Revenue** (large, prominent, live-updating)
3. Metric Cards (Orders, AOV, Gross Profit, Low Stock)
4. Quick Actions
5. Sales Chart (with functional time filter)
6. Recent Orders (real data, tappable for details)
7. Top Selling Products (real data)
8. Payment Methods Pie (real data)

---

## 5. Desktop Layout Comparison

| Square Dashboard | Shopify Admin | Zynk Desktop |
|-----------------|---------------|--------------|
| Hero revenue card at top | Sales overview card | 4 equal metric cards ← should differentiate |
| Quick actions as floating buttons | Quick actions in sidebar | Quick actions in right column ✅ |
| Live transaction feed | Recent orders table | Recent orders table ✅ |
| Filterable by location | Filterable by channel | Branch selector ✅ |
| Staff performance section | N/A | Missing ❌ |
| Tips & notifications bar | Activity feed | Missing ❌ |
