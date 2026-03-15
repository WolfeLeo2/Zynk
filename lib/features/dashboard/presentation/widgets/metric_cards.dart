import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'skeleton_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESKTOP METRICS GRID
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
    final pendingAsync = ref.watch(pendingApprovalsCountProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);
    final revenueSparkline = ref.watch(revenueSparklineProvider);
    final ordersSparkline = ref.watch(ordersSparklineProvider);

    return Row(
      children: [
        Expanded(
          child: revenueAsync.isLoading
              ? SkeletonCard(colorScheme: colorScheme)
              : MetricCardWithSparkline(
                  title: 'Today\'s Revenue',
                  value: 'Ksh ${_formatNumber(revenueAsync.value ?? 0)}',
                  rawValue: revenueAsync.value ?? 0,
                  icon: PhosphorIconsDuotone.moneyWavy,
                  color: colorScheme.primary,
                  sparklineData: revenueSparkline.value ?? [],
                ),
        ),
        const SizedBox(width: 16),
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
        const SizedBox(width: 16),
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
                ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: lowStockAsync.isLoading
              ? SkeletonCard(colorScheme: colorScheme)
              : MetricCardWithSparkline(
                  title: 'Low Stock Items',
                  value: '${lowStockAsync.value ?? 0}',
                  rawValue: (lowStockAsync.value ?? 0).toDouble(),
                  icon: PhosphorIconsDuotone.warning,
                  color: (lowStockAsync.value ?? 0) > 0
                      ? colorScheme.error
                      : Colors.green,
                  sparklineData: const [],
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
    final pendingAsync = ref.watch(pendingApprovalsCountProvider);
    final lowStockAsync = ref.watch(lowStockCountProvider);
    final revenueSparkline = ref.watch(revenueSparklineProvider);
    final ordersSparkline = ref.watch(ordersSparklineProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: revenueAsync.isLoading
                  ? SkeletonCard(colorScheme: colorScheme)
                  : MetricCardWithSparkline(
                      title: 'Today\'s Revenue',
                      value: 'Ksh ${_formatNumber(revenueAsync.value ?? 0)}',
                      rawValue: revenueAsync.value ?? 0,
                      icon: PhosphorIconsDuotone.currencyDollar,
                      color: colorScheme.primary,
                      sparklineData: revenueSparkline.value ?? [],
                    ),
            ),
            const SizedBox(width: 12),
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
          ],
        ),
        const SizedBox(height: 12),
        Row(
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
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
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

  const MetricCardWithSparkline({
    super.key,
    required this.title,
    required this.value,
    this.rawValue,
    required this.icon,
    required this.color,
    required this.sparklineData,
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

    return AnimatedContainer(
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
                child: PhosphorIcon(widget.icon, color: widget.color, size: 20),
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
