import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'skeleton_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REVENUE BAR CHART (Lightweight)
// ─────────────────────────────────────────────────────────────────────────────

class RevenueBarChart extends ConsumerWidget {
  const RevenueBarChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final chartDataAsync = ref.watch(dailySalesChartProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
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
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
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
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
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
  final String title;
  final String value;
  final String current;
  final ColorScheme colorScheme;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.title,
    required this.value,
    required this.current,
    required this.colorScheme,
    required this.onTap,
  });

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
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
  final ColorScheme colorScheme;
  final List<Map<String, dynamic>> data;

  const _SimpleBarChart({required this.colorScheme, required this.data});

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
    for (final r in data) {
      final val = (r['revenue'] as num?)?.toDouble() ?? 0;
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
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final val = rod.toY;
              String label;
              if (val >= 1000000) {
                label = 'Ksh ${(val / 1000000).toStringAsFixed(1)}M';
              } else if (val >= 1000) {
                label = 'Ksh ${(val / 1000).toStringAsFixed(1)}K';
              } else {
                label = 'Ksh ${val.toStringAsFixed(0)}';
              }
              return BarTooltipItem(
                label,
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox();
                final dateStr = data[index]['day'] as String?;
                if (dateStr == null) return const SizedBox();

                final dt = DateTime.tryParse(dateStr);
                final label = dt != null
                    ? DateFormat('E').format(dt)
                    : ''; // e.g. Mon, Tue

                // Show fewer labels for monthly view
                if (data.length > 10 && index % 5 != 0) return const SizedBox();

                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                String label;
                if (value >= 1000000) {
                  label = '${(value / 1000000).toStringAsFixed(1)}M';
                } else if (value >= 1000) {
                  label = '${(value / 1000).toStringAsFixed(1)}K';
                } else {
                  label = value.toStringAsFixed(0);
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxVal / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            strokeWidth: 1,
            dashArray: [4, 4],
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
                width: data.length > 10 ? 4 : 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT METHODS CHART (SIDE PANEL)
// ─────────────────────────────────────────────────────────────────────────────

class PaymentMethodsChart extends ConsumerWidget {
  const PaymentMethodsChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final paymentData = ref.watch(paymentMethodsProvider);
    final breakdownData = ref.watch(paymentBreakdownProvider);

    const legendColors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF22C55E), // Green
      Color(0xFFF59E0B), // Amber
      Color(0xFFEF4444), // Red
      Color(0xFF8B5CF6), // Purple
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: paymentData.when(
              data: (sections) {
                if (sections.isEmpty) {
                  return Center(
                    child: Text(
                      'No payment data yet',
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  );
                }
                return PieChart(
                  PieChartData(
                    sections: sections
                        .map((s) => s.copyWith(radius: 50))
                        .toList(),
                    centerSpaceRadius: 30,
                    sectionsSpace: 2,
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Center(child: Text('Error loading data')),
            ),
          ),
          const SizedBox(height: 16),
          // Dynamic legend from real data
          breakdownData.when(
            data: (rows) {
              if (rows.isEmpty) return const SizedBox.shrink();
              final total = rows.fold<double>(
                0,
                (sum, r) => sum + ((r['total'] as num?)?.toDouble() ?? 0),
              );
              return Column(
                children: rows.asMap().entries.map((entry) {
                  final r = entry.value;
                  final method = (r['payment_method'] as String?) ?? 'Other';
                  final amount = (r['total'] as num?)?.toDouble() ?? 0;
                  final pct = total > 0 ? (amount / total * 100).round() : 0;
                  final label = _formatMethodName(method);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildLegend(
                      label,
                      legendColors[entry.key % legendColors.length],
                      '$pct%',
                      colorScheme,
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
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

  Widget _buildLegend(
    String label,
    Color color,
    String percentage,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        Text(percentage, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
