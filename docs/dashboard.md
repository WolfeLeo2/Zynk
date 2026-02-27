# Dashboard Architecture & Design

## Overview
The Zynk Dashboard is a responsive, feature-rich analytics hub that provides business insights across mobile, tablet, and desktop platforms. It follows Material 3 design principles with custom enhancements for a polished user experience.

## Architecture

### Data Flow
```
┌─────────────────────────────────────────────────────────────┐
│                    Dashboard Layout                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │  Providers  │  │   UI State  │  │   Async Handlers    │ │
│  ├─────────────┤  ├─────────────┤  ├─────────────────────┤ │
│  │salesData    │  │chartType    │  │ pull-to-refresh     │ │
│  │ordersData   │  │selectedRange│  │ retry on error      │ │
│  │productsData │  │refreshTime  │  │ haptic feedback     │ │
│  │sparklines   │  │             │  │ metric detail view  │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Providers
| Provider | Type | Purpose |
|----------|------|---------|
| `salesDataProvider` | StreamProvider | Real-time total sales metrics |
| `ordersDataProvider` | FutureProvider | Recent orders with pagination |
| `productsDataProvider` | FutureProvider | Top-selling products |
| `revenueSparklineProvider` | FutureProvider | 7-day revenue sparkline data |
| `ordersSparklineProvider` | FutureProvider | 7-day orders sparkline data |
| `paymentMethodsProvider` | FutureProvider | Payment method distribution for pie chart |
| `chartTypeProvider` | NotifierProvider | Selected chart type (line/bar/area/pie) |
| `dashboardRefreshTriggerProvider` | Provider | Pull-to-refresh trigger |

## Responsive Breakpoints

```dart
// Current implementation
< 600px    → Mobile (Bottom Navigation + Single Column)
600-840px  → Tablet (Navigation Rail + 2-Column Grid)
> 840px    → Desktop (Custom Sidebar + 4-Column Metrics)
```

## Features

### 1. Sparklines in Metric Cards
Each metric card displays a mini line chart showing the 7-day trend:

```
┌─────────────────────────────┐
│  💰    ↑ 12.5%             │
│  Ksh 45,230                │
│  ╱╲╱╲╱‾╲╱╲                 │  ← Sparkline
│  Total Revenue             │
└─────────────────────────────┘
```

**Sparkline Providers:**
- `revenueSparklineProvider` - 7-day revenue trend
- `ordersSparklineProvider` - 7-day orders trend

### 2. Metric Detail Sheets (Expanded View)
Tapping any metric card opens a bottom sheet with:
- Full metric value with count-up animation
- Related metrics grid (4 cards)
- 7-day trend chart
- Contextual insights

**Example - Revenue Detail:**
```
┌─────────────────────────────┐
│  Revenue Details        [X] │
├─────────────────────────────┤
│  Ksh 45,230                 │
│  Total revenue this week    │
├─────────────────────────────┤
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐│
│  │Online│ │Store│ │Avg  │ │Total││
│  │28k  │ │17k  │ │1.8k │ │24   ││
│  └────┘ └────┘ └────┘ └────┘│
├─────────────────────────────┤
│  7-Day Trend                │
│  [Line Chart]               │
└─────────────────────────────┘
```

### 3. Interactive Charts with Type Toggle
The main sales chart supports 4 chart types:

| Type | Description | Use Case |
|------|-------------|----------|
| **Line** | Curved line with gradient fill | Trend over time |
| **Bar** | Vertical bars | Daily comparison |
| **Area** | Gradient-filled area | Emphasize volume |
| **Pie** | Payment method distribution | Category breakdown |

**Features:**
- Toggle buttons (Line | Bar | Area)
- Touch tooltips with exact values
- Time range selector (Today/Week/Month/Year)

### 4. Pull-to-Refresh with Haptics
- **Medium haptic** on pull start
- **Light haptic** on refresh complete
- All providers refresh simultaneously
- Uses `BouncingScrollPhysics` for iOS-style bounce

### 5. Skeleton Loading States
| Component | Skeleton Type |
|-----------|---------------|
| Metric Cards | `_SkeletonCard` - Rounded rectangle shimmer |
| List Items | `_SkeletonListItem` - Avatar + text lines |
| Branch Selector | Shimmer container |

### 6. Count-Up Animations
Metric cards animate from 0 to actual value over 1.5 seconds using `AnimationController` with `easeOutCubic` curve.

### 7. Empty & Error States
- **Empty**: Icon, title, message with fade-in
- **Error**: Warning icon, message, retry button with provider invalidation

### 8. Advanced Data Tables (ListView.builder)

#### Mobile: Card List
- Card-based layout
- Status badges with color coding
- Time-ago timestamps
- Status icons (check, cooking pot, clock)

#### Desktop: Table Layout
- Header row with column labels
- Zebra striping (alternating backgrounds)
- Avatar + customer name
- Status pill badges

## Visual Design

### Metric Cards (4 on Desktop, 2x2 on Mobile)
| Card | Color | Sparkline | Trend |
|------|-------|-----------|-------|
| Total Revenue | Primary | 7-day line | ↑ 12.5% |
| Daily Orders | Secondary | 7-day line | ↑ 8.3% |
| Avg Order Value | Tertiary | 7-day line | ↑ 5.2% |
| Low Stock Items | Error | 7-day line | ↓ 10.0% |

### Shadows & Elevation
```dart
BoxShadow(
  color: widget.color.withValues(alpha: 0.05),
  blurRadius: 20,
  offset: const Offset(0, 4),
)
```

### Animations (flutter_animate)
| Element | Animation | Duration | Delay |
|---------|-----------|----------|-------|
| Metric Cards | Fade + SlideY | 400ms | 100ms stagger |
| Chart | Fade + SlideY | 500ms | 200ms |
| List Items | Fade + SlideX | 400ms | 50ms × index |
| Detail Sheet | SlideY | 300ms | - |

## Data Models

### MetricDetailData
```dart
class MetricDetailData {
  final MetricType type;        // revenue, orders, aov, etc.
  final String title;           // "Revenue Details"
  final String value;           // "Ksh 45,230"
  final double? rawValue;       // 45230.0
  final String subtitle;        // "Total revenue this week"
  final List<MetricRelation> relatedMetrics;  // 4 related cards
  final List<ChartPoint> chartData;          // 7-day trend
}
```

### MetricRelation
```dart
class MetricRelation {
  final String label;     // "Online Sales"
  final String value;     // "Ksh 28,450"
  final IconData icon;    // PhosphorIconsDuotone.globe
  final Color color;
  final double? change;   // +15.2%
}
```

## Component Reference

### _MetricCardWithSparkline
Enhanced metric card with sparkline mini-chart and tap-to-expand.

**Props:**
- `title`: String
- `value`: String (display value)
- `rawValue`: double? (for count-up)
- `icon`: IconData
- `color`: Color
- `sparklineData`: List<double>
- `trend`: double (percentage)
- `onTap`: VoidCallback

### _InteractiveSalesChart
Multi-type chart with toggle controls.

**Chart Types:**
```dart
enum ChartType { line, bar, area, pie }
```

### MetricDetailSheet
Bottom sheet showing expanded metric view.

**Features:**
- Draggable handle bar
- Related metrics grid (2x2)
- Mini trend chart
- Smooth slide-up animation

### _PaymentMethodsChart
Side-panel pie chart showing payment distribution.

**Categories:**
- M-Pesa (45%)
- Cash (30%)
- Card (15%)
- Other (10%)

## Dependencies
```yaml
dependencies:
  shimmer: ^3.0.0              # Skeleton loading
  flutter_animate: ^4.5.2      # Animations
  fl_chart: ^1.1.1             # Charts
```

## Future Enhancements
- [ ] Draggable dashboard widgets
- [ ] Command palette (Cmd+K)
- [ ] Real-time WebSocket updates (deferred - using PowerSync)
- [ ] Export to PDF/CSV
- [ ] Advanced filtering
- [ ] Date range picker
- [ ] Custom metric card arrangement

## PowerSync Integration Note
Since Zynk uses PowerSync for local-first architecture, real-time updates are handled automatically through:
- Local SQLite with sync to Supabase
- Offline-first data persistence
- Automatic conflict resolution
- No additional real-time provider needed

## Testing Checklist
- [ ] Pull-to-refresh on iOS/Android
- [ ] Metric card tap opens detail sheet
- [ ] Chart type toggle works (Line/Bar/Area)
- [ ] Sparklines animate on load
- [ ] Count-up animation plays
- [ ] Empty/error states display correctly
- [ ] Responsive layout at all breakpoints
- [ ] Haptic feedback on all interactions
- [ ] Dark mode compatibility
