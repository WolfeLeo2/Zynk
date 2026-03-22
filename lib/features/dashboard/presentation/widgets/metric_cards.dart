import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'skeleton_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP METRICS GRID (Bento Style)
// ─────────────────────────────────────────────────────────────────────────────

class DesktopMetricsGrid extends ConsumerWidget {
  final AsyncValue<double> salesAsync;
  final ColorScheme colorScheme;
  const DesktopMetricsGrid({
    super.key,
    required this.salesAsync,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(todaysRevenueProvider);
    final ordersAsync = ref.watch(todaysOrderCountProvider);
    final inventoryValueAsync = ref.watch(totalInventoryValueProvider);
    final recentAdjAsync = ref.watch(recentAdjustmentsCountProvider);
    final pendingAsync = ref.watch(pendingApprovalsCountProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);
    final revenueSparkline = ref.watch(revenueSparklineProvider);
    final ordersSparkline = ref.watch(ordersSparklineProvider);

    return SizedBox(
      height: 240, // Fixed height for the Bento row
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Large Promo/Main KPI Card (e.g. Revenue)
          Expanded(
            flex: 4,
            child: revenueAsync.isLoading
                ? SkeletonCard(colorScheme: colorScheme)
                : MetricCardWithSparkline(
                    title: 'Today\'s Revenue',
                    value: 'Ksh ${_formatNumber(revenueAsync.value ?? 0)}',
                    rawValue: revenueAsync.value ?? 0,
                    icon: PhosphorIconsDuotone.moneyWavy,
                    color: colorScheme.primary,
                    sparklineData: revenueSparkline.value ?? [],
                    isLargeCard: true,
                  ),
          ),
        const SizedBox(width: 16),
        // Stacked Medium KPIs
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: ordersAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Today\'s Orders',
                        value: '${ordersAsync.value ?? 0}',
                        rawValue: (ordersAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.receipt,
                        color: colorScheme.secondary,
                        sparklineData: ordersSparkline.value ?? [],
                      ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: inventoryValueAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Total Inventory Value',
                        value: 'Ksh ${_formatNumber(inventoryValueAsync.value ?? 0)}',
                        rawValue: inventoryValueAsync.value ?? 0,
                        icon: PhosphorIconsDuotone.package,
                        color: const Color(0xFF6366F1), // Indigo
                        sparklineData: const [],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Grouped Small KPIs
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: pendingAsync.isLoading
                          ? SkeletonCard(colorScheme: colorScheme)
                          : MetricCardWithSparkline(
                              title: 'Pending Approvals',
                              value: '${pendingAsync.value ?? 0}',
                              rawValue: (pendingAsync.value ?? 0).toDouble(),
                              icon: PhosphorIconsDuotone.clock,
                              color: (pendingAsync.value ?? 0) > 0
                                  ? colorScheme.error
                                  : colorScheme.tertiary,
                              sparklineData: const [],
                              isSmallCard: true,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: recentAdjAsync.isLoading
                          ? SkeletonCard(colorScheme: colorScheme)
                          : MetricCardWithSparkline(
                              title: 'Recent Adjustments',
                              value: '${recentAdjAsync.value ?? 0}',
                              rawValue: (recentAdjAsync.value ?? 0).toDouble(),
                              icon: PhosphorIconsDuotone.slidersHorizontal,
                              color: colorScheme.secondary,
                              sparklineData: const [],
                              isSmallCard: true,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: lowStockAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Low Stock Alerts',
                        value: '${lowStockAsync.value ?? 0}',
                        rawValue: (lowStockAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.warning,
                        color: (lowStockAsync.value ?? 0) > 0
                            ? colorScheme.error
                            : Colors.green,
                        sparklineData: const [],
                        isWideCard: true,
                      ),
              ),
            ],
          ),
        ),
      ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE METRICS GRID (Bento Style)
// ─────────────────────────────────────────────────────────────────────────────

class MobileMetricsGrid extends ConsumerWidget {
  const MobileMetricsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(todaysRevenueProvider);
    final ordersAsync = ref.watch(todaysOrderCountProvider);
    final inventoryValueAsync = ref.watch(totalInventoryValueProvider);
    final recentAdjAsync = ref.watch(recentAdjustmentsCountProvider);
    final pendingAsync = ref.watch(pendingApprovalsCountProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);
    final revenueSparkline = ref.watch(revenueSparklineProvider);
    final ordersSparkline = ref.watch(ordersSparklineProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: revenueAsync.isLoading
              ? SkeletonCard(colorScheme: colorScheme)
              : MetricCardWithSparkline(
                  title: 'Today\'s Revenue',
                  value: 'Ksh ${_formatNumber(revenueAsync.value ?? 0)}',
                  rawValue: revenueAsync.value ?? 0,
                  icon: PhosphorIconsDuotone.moneyWavy,
                  color: colorScheme.primary,
                  sparklineData: revenueSparkline.value ?? [],
                  isLargeCard: true,
                ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 140,
                child: ordersAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Orders',
                        value: '${ordersAsync.value ?? 0}',
                        rawValue: (ordersAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.receipt,
                        color: colorScheme.secondary,
                        sparklineData: ordersSparkline.value ?? [],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 140,
                child: inventoryValueAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Inventory Value',
                        value: 'Ksh ${_formatNumber(inventoryValueAsync.value ?? 0)}',
                        rawValue: inventoryValueAsync.value ?? 0,
                        icon: PhosphorIconsDuotone.package,
                        color: const Color(0xFF6366F1), // Indigo
                        sparklineData: const [],
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 120,
                child: pendingAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Pending',
                        value: '${pendingAsync.value ?? 0}',
                        rawValue: (pendingAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.clock,
                        color: (pendingAsync.value ?? 0) > 0
                            ? colorScheme.error
                            : colorScheme.tertiary,
                        sparklineData: const [],
                        isSmallCard: true,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 120,
                child: recentAdjAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Adjustments',
                        value: '${recentAdjAsync.value ?? 0}',
                        rawValue: (recentAdjAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.slidersHorizontal,
                        color: colorScheme.secondary,
                        sparklineData: const [],
                        isSmallCard: true,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 120,
                child: lowStockAsync.isLoading
                    ? SkeletonCard(colorScheme: colorScheme)
                    : MetricCardWithSparkline(
                        title: 'Low Stock',
                        value: '${lowStockAsync.value ?? 0}',
                        rawValue: (lowStockAsync.value ?? 0).toDouble(),
                        icon: PhosphorIconsDuotone.warning,
                        color: (lowStockAsync.value ?? 0) > 0
                            ? colorScheme.error
                            : Colors.green,
                        sparklineData: const [],
                        isSmallCard: true,
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRIC CARD WITH SPARKLINE (premium design with gradient tint)
// ─────────────────────────────────────────────────────────────────────────────

class MetricCardWithSparkline extends StatefulWidget {
  final String title;
  final String value;
  final double? rawValue;
  final IconData icon;
  final Color color;
  final List<double> sparklineData;
  final bool isLargeCard;
  final bool isSmallCard;
  final bool isWideCard;

  const MetricCardWithSparkline({
    super.key,
    required this.title,
    required this.value,
    this.rawValue,
    required this.icon,
    required this.color,
    required this.sparklineData,
    this.isLargeCard = false,
    this.isSmallCard = false,
    this.isWideCard = false,
  });

  @override
  State<MetricCardWithSparkline> createState() =>
      _MetricCardWithSparklineState();
}

class _MetricCardWithSparklineState extends State<MetricCardWithSparkline>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (widget.rawValue != null) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(MetricCardWithSparkline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawValue != widget.rawValue && widget.rawValue != null) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatAnimatedValue(double value) {
    if (widget.title.contains('Revenue') || widget.title.contains('Value')) {
      return 'Ksh ${_formatNumber(value)}';
    }
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final double padding = widget.isSmallCard ? 12 : (widget.isLargeCard ? 24 : 16);
    final double iconSize = widget.isSmallCard ? 16 : (widget.isLargeCard ? 28 : 20);
    final double iconBgSize = widget.isSmallCard ? 8 : (widget.isLargeCard ? 14 : 10);
    final double titleFontSize = widget.isSmallCard ? 18 : (widget.isLargeCard ? 36 : 24);
    final double labelFontSize = widget.isSmallCard ? 11 : (widget.isLargeCard ? 14 : 12);
    // final double sparklineHeight = widget.isSmallCard ? 24 : (widget.isLargeCard ? 60 : 40);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.surface, widget.color.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(widget.isSmallCard ? 16 : 24),
        border: Border.all(color: widget.color.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(iconBgSize),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.15),
                      widget.color.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.isSmallCard ? 10 : 14),
                ),
                child: PhosphorIcon(widget.icon, color: widget.color, size: iconSize),
              ),
            ],
          ),
          Spacer(),
          if (widget.rawValue != null)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                final animatedValue = widget.rawValue! * _animation.value;
                return Text(
                  _formatAnimatedValue(animatedValue),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                    fontSize: titleFontSize,
                    height: 1.2,
                  ),
                );
              },
            )
          else
            Text(
              widget.value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
                fontSize: titleFontSize,
                height: 1.2,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            widget.title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
              fontSize: labelFontSize,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          /* if (!widget.isSmallCard && widget.sparklineData.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: sparklineHeight,
              child: Sparkline(data: widget.sparklineData, color: widget.color),
            ),
          ] */
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPARKLINE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;

  const Sparkline({super.key, required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range * 0.1;

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: data.length - 1,
        minY: minY - padding,
        maxY: maxY + padding,
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value);
            }).toList(),
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(enabled: false),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatNumber(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}
