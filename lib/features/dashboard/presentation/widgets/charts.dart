import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'skeleton_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REVENUE CHART
// ─────────────────────────────────────────────────────────────────────────────

class RevenueBarChart extends ConsumerWidget {
  const RevenueBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final chartDataAsync = ref.watch(dailySalesChartProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Revenue',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const _TimeRangeToggle(),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 210,
              child: chartDataAsync.when(
                data: (rows) =>
                    _SimpleBarChart(colorScheme: colorScheme, data: rows),
                loading: () => SkeletonChart(colorScheme: colorScheme),
                error: (_, _) => Center(
                  child: Text(
                    'Unable to load chart data',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRangeToggle extends ConsumerWidget {
  const _TimeRangeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRange = ref.watch(chartTimeRangeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleOption(
            title: 'Weekly',
            value: 'This Week',
            current: currentRange,
            colorScheme: colorScheme,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(chartTimeRangeProvider.notifier).setRange('This Week');
            },
          ),
          _ToggleOption(
            title: 'Monthly',
            value: 'This Month',
            current: currentRange,
            colorScheme: colorScheme,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(chartTimeRangeProvider.notifier).setRange('This Month');
            },
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  const _ToggleOption({
    required this.title,
    required this.value,
    required this.current,
    required this.colorScheme,
    required this.onTap,
  });

  final String title;
  final String value;
  final String current;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _SimpleBarChart extends StatelessWidget {
  const _SimpleBarChart({required this.colorScheme, required this.data});

  final ColorScheme colorScheme;
  final List<Map<String, dynamic>> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No data for this period',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    double maxVal = 0;
    for (final row in data) {
      final val = (row['revenue'] as num?)?.toDouble() ?? 0;
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 100;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal * 1.2,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'Ksh ${_compact(rod.toY)}',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    _axisLabel(value),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final dateStr = data[index]['day'] as String?;
                final dt = dateStr == null ? null : DateTime.tryParse(dateStr);
                final label = dt == null ? '' : DateFormat('E').format(dt);

                if (data.length > 10 && index % 5 != 0) {
                  return const SizedBox();
                }

                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          final val = (data[i]['revenue'] as num?)?.toDouble() ?? 0;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val,
                color: colorScheme.primary,
                width: data.length > 10 ? 5 : 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _axisLabel(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT METHODS CHART
// ─────────────────────────────────────────────────────────────────────────────

class PaymentMethodsChart extends ConsumerWidget {
  const PaymentMethodsChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final breakdownData = ref.watch(paymentBreakdownProvider);

    const legendColors = [
      Color(0xFF6366F1),
      Color(0xFF22C55E),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Methods',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: breakdownData.when(
                loading: () => SkeletonChart(colorScheme: colorScheme),
                error: (_, _) =>
                    const Center(child: Text('Error loading data')),
                data: (rows) {
                  if (rows.isEmpty) {
                    return Center(
                      child: Text(
                        'No payment data yet',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    );
                  }

                  final total = rows.fold<double>(
                    0,
                    (sum, row) =>
                        sum + ((row['total'] as num?)?.toDouble() ?? 0),
                  );

                  final sections = rows.asMap().entries.map((entry) {
                    final amount =
                        (entry.value['total'] as num?)?.toDouble() ?? 0;
                    return PieChartSectionData(
                      value: amount,
                      color: legendColors[entry.key % legendColors.length],
                      radius: 10,
                      showTitle: false,
                    );
                  }).toList();

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 52,
                          sectionsSpace: 2,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Ksh ${_formatCompact(total)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Collected',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            breakdownData.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (rows) {
                if (rows.isEmpty) return const SizedBox.shrink();
                final total = rows.fold<double>(
                  0,
                  (sum, row) => sum + ((row['total'] as num?)?.toDouble() ?? 0),
                );

                return Column(
                  children: rows.asMap().entries.map((entry) {
                    final row = entry.value;
                    final method =
                        (row['payment_method'] as String?) ?? 'Other';
                    final amount = (row['total'] as num?)?.toDouble() ?? 0;
                    final pct = total > 0 ? (amount / total * 100).round() : 0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildLegend(
                        label: _formatMethodName(method),
                        color: legendColors[entry.key % legendColors.length],
                        percentage: '$pct%',
                        amountLabel: 'Ksh ${_formatCompact(amount)}',
                        colorScheme: colorScheme,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _formatMethodName(String raw) {
    switch (raw.toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'mpesa':
      case 'm-pesa':
        return 'M-Pesa';
      case 'card':
        return 'Card';
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  Widget _buildLegend({
    required String label,
    required Color color,
    required String percentage,
    required String amountLabel,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Text(
          amountLabel,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          percentage,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
