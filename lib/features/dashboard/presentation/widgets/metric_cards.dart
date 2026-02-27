import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zynk/features/dashboard/models/dashboard_models.dart';
import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'metric_detail_sheet.dart';
import 'skeleton_widgets.dart';

export 'package:zynk/features/dashboard/models/dashboard_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP METRICS GRID
// ─────────────────────────────────────────────────────────────────────────────

class DesktopMetricsGrid extends ConsumerWidget {
  final AsyncValue<double> salesAsync;
  final ColorScheme colorScheme;
  final Function(MetricDetailData) onMetricTap;

  const DesktopMetricsGrid({
    super.key,
    required this.salesAsync,
    required this.colorScheme,
    required this.onMetricTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(todaysRevenueProvider);
    final ordersAsync = ref.watch(todaysOrderCountProvider);
    final aovAsync = ref.watch(averageOrderValueProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);
    final revenueSparkline = ref.watch(revenueSparklineProvider);
    final ordersSparkline = ref.watch(ordersSparklineProvider);

    // Show skeleton if primary data is loading
    final anyLoading = revenueAsync.isLoading && ordersAsync.isLoading;
    if (anyLoading) {
      return Row(
        children: List.generate(
          4,
          (_) => [
            Expanded(child: SkeletonCard(colorScheme: colorScheme)),
            const SizedBox(width: 16),
          ],
        ).expand((e) => e).toList()..removeLast(),
      );
    }

    final revenue = revenueAsync.value ?? 0;
    final orders = ordersAsync.value ?? 0;
    final aov = aovAsync.value ?? 0;
    final lowStock = lowStockAsync.value ?? 0;

    return Row(
      children: [
        Expanded(
          child: MetricCardWithSparkline(
            title: 'Today\'s Revenue',
            value: 'Ksh ${_formatNumber(revenue)}',
            rawValue: revenue,
            icon: PhosphorIconsDuotone.moneyWavy,
            color: colorScheme.primary,
            sparklineData: revenueSparkline.value ?? [],
            onTap: () =>
                onMetricTap(createRevenueDetailData(revenue, colorScheme)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MetricCardWithSparkline(
            title: 'Today\'s Orders',
            value: '$orders',
            rawValue: orders.toDouble(),
            icon: PhosphorIconsDuotone.receipt,
            color: colorScheme.secondary,
            sparklineData: ordersSparkline.value ?? [],
            onTap: () =>
                onMetricTap(createOrdersDetailData(orders, colorScheme)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MetricCardWithSparkline(
            title: 'Avg Order Value',
            value: 'Ksh ${_formatNumber(aov)}',
            rawValue: aov,
            icon: PhosphorIconsDuotone.shoppingCart,
            color: colorScheme.tertiary,
            sparklineData: const [],
            onTap: () => onMetricTap(createAOVDetailData(aov, colorScheme)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: MetricCardWithSparkline(
            title: 'Low Stock Items',
            value: '$lowStock',
            rawValue: lowStock.toDouble(),
            icon: PhosphorIconsDuotone.warning,
            color: lowStock > 0 ? colorScheme.error : Colors.green,
            sparklineData: const [],
            onTap: () =>
                onMetricTap(createLowStockDetailData(lowStock, colorScheme)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE METRICS GRID
// ─────────────────────────────────────────────────────────────────────────────

class MobileMetricsGrid extends ConsumerWidget {
  const MobileMetricsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(todaysRevenueProvider);
    final ordersAsync = ref.watch(todaysOrderCountProvider);
    final aovAsync = ref.watch(averageOrderValueProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);
    final revenueSparkline = ref.watch(revenueSparklineProvider);
    final ordersSparkline = ref.watch(ordersSparklineProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final anyLoading = revenueAsync.isLoading && ordersAsync.isLoading;
    if (anyLoading) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: SkeletonCard(colorScheme: colorScheme)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonCard(colorScheme: colorScheme)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SkeletonCard(colorScheme: colorScheme)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonCard(colorScheme: colorScheme)),
            ],
          ),
        ],
      );
    }

    final revenue = revenueAsync.value ?? 0;
    final orders = ordersAsync.value ?? 0;
    final aov = aovAsync.value ?? 0;
    final lowStock = lowStockAsync.value ?? 0;

    void onMetricTap(MetricDetailData data) {
      HapticFeedback.mediumImpact();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MetricDetailSheet(data: data),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCardWithSparkline(
                title: 'Today\'s Revenue',
                value: 'Ksh ${_formatNumber(revenue)}',
                rawValue: revenue,
                icon: PhosphorIconsDuotone.currencyDollar,
                color: colorScheme.primary,
                sparklineData: revenueSparkline.value ?? [],
                onTap: () =>
                    onMetricTap(createRevenueDetailData(revenue, colorScheme)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCardWithSparkline(
                title: 'Today\'s Orders',
                value: '$orders',
                rawValue: orders.toDouble(),
                icon: PhosphorIconsDuotone.receipt,
                color: colorScheme.secondary,
                sparklineData: ordersSparkline.value ?? [],
                onTap: () =>
                    onMetricTap(createOrdersDetailData(orders, colorScheme)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCardWithSparkline(
                title: 'Avg Order Value',
                value: 'Ksh ${_formatNumber(aov)}',
                rawValue: aov,
                icon: PhosphorIconsDuotone.shoppingCart,
                color: colorScheme.tertiary,
                sparklineData: const [],
                onTap: () => onMetricTap(createAOVDetailData(aov, colorScheme)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCardWithSparkline(
                title: 'Low Stock',
                value: '$lowStock',
                rawValue: lowStock.toDouble(),
                icon: PhosphorIconsDuotone.warning,
                color: lowStock > 0 ? colorScheme.error : Colors.green,
                sparklineData: const [],
                onTap: () => onMetricTap(
                  createLowStockDetailData(lowStock, colorScheme),
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
  final VoidCallback onTap;

  const MetricCardWithSparkline({
    super.key,
    required this.title,
    required this.value,
    this.rawValue,
    required this.icon,
    required this.color,
    required this.sparklineData,
    required this.onTap,
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

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.surface, widget.color.withValues(alpha: 0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.color.withValues(alpha: 0.15),
                        widget.color.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: PhosphorIcon(
                    widget.icon,
                    color: widget.color,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                ),
              ),
            const SizedBox(height: 2),
            Text(
              widget.title,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: widget.sparklineData.isNotEmpty
                  ? Sparkline(data: widget.sparklineData, color: widget.color)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
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
