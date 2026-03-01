import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import 'package:zynk/features/dashboard/models/dashboard_models.dart';
import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'skeleton_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INTERACTIVE SALES CHART WITH TYPE TOGGLE
// ─────────────────────────────────────────────────────────────────────────────

class InteractiveSalesChart extends ConsumerWidget {
  const InteractiveSalesChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartType = ref.watch(chartTypeProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final chartDataAsync = ref.watch(dailySalesChartProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — Flexible wrapping prevents overflow
          Row(
            children: [
              Flexible(
                child: Text(
                  'Sales Analytics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const _TimeRangeSelector(),
              const SizedBox(width: 8),
              const _ChartTypeToggle(),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: chartDataAsync.when(
              data: (rows) => _ChartRenderer(
                chartType: chartType,
                colorScheme: colorScheme,
                data: rows,
              ),
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

class _ChartRenderer extends StatelessWidget {
  final ChartType chartType;
  final ColorScheme colorScheme;
  final List<Map<String, dynamic>> data;

  const _ChartRenderer({
    required this.chartType,
    required this.colorScheme,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'No sales data for this period',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      );
    }

    switch (chartType) {
      case ChartType.line:
        return _LineChart(colorScheme: colorScheme, data: data);
      case ChartType.bar:
        return _BarChart(colorScheme: colorScheme, data: data);
      case ChartType.pie:
        return _PieChartWidget(colorScheme: colorScheme);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART TYPE TOGGLE (line + bar only)
// ─────────────────────────────────────────────────────────────────────────────

class _ChartTypeToggle extends ConsumerWidget {
  const _ChartTypeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentType = ref.watch(chartTypeProvider);
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
          _buildTypeButton(
            ChartType.line,
            Icons.show_chart,
            currentType,
            ref,
            colorScheme,
          ),
          _buildTypeButton(
            ChartType.bar,
            Icons.bar_chart,
            currentType,
            ref,
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(
    ChartType type,
    IconData icon,
    ChartType current,
    WidgetRef ref,
    ColorScheme colorScheme,
  ) {
    final isSelected = type == current;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(chartTypeProvider.notifier).setType(type);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected
              ? colorScheme.onPrimary
              : colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME RANGE SELECTOR (wired to provider)
// ─────────────────────────────────────────────────────────────────────────────

class _TimeRangeSelector extends ConsumerWidget {
  const _TimeRangeSelector();

  static const _ranges = ['Today', 'This Week', 'This Month', 'This Year'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(chartTimeRangeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      initialValue: selectedRange,
      onSelected: (value) {
        ref.read(chartTimeRangeProvider.notifier).setRange(value);
        HapticFeedback.lightImpact();
      },
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      color: colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedRange,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => _ranges
          .map(
            (range) => PopupMenuItem(
              value: range,
              child: Text(
                range,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: range == selectedRange
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS — shared label formatter
// ─────────────────────────────────────────────────────────────────────────────

String _dayLabel(String iso) {
  try {
    final d = DateTime.parse(iso);
    return DateFormat('E').format(d); // Mon, Tue, …
  } catch (_) {
    return iso.substring(5); // MM-DD fallback
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINE CHART (real data)
// ─────────────────────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<Map<String, dynamic>> data;

  const _LineChart({required this.colorScheme, required this.data});

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map((e) {
      final revenue = (e.value['revenue'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), revenue);
    }).toList();

    final maxY = spots.isEmpty
        ? 10.0
        : spots.map((e) => e.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _dayLabel(data[i]['day'] as String),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (data.length - 1).toDouble().clamp(0, double.infinity),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: colorScheme.primary,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: colorScheme.primary,
                strokeWidth: 2,
                strokeColor: colorScheme.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.3),
                  colorScheme.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) =>
                colorScheme.surfaceContainerHighest,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final i = spot.x.toInt();
                final day = i < data.length
                    ? _dayLabel(data[i]['day'] as String)
                    : '';
                return LineTooltipItem(
                  '$day\nKsh ${_chartFormat(spot.y)}',
                  TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BAR CHART (real data)
// ─────────────────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<Map<String, dynamic>> data;

  const _BarChart({required this.colorScheme, required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data.isEmpty
        ? 10.0
        : data
                  .map((e) => (e['revenue'] as num?)?.toDouble() ?? 0)
                  .reduce((a, b) => a > b ? a : b) *
              1.2;

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _dayLabel(data[i]['day'] as String),
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxY,
        barGroups: data.asMap().entries.map((e) {
          final revenue = (e.value['revenue'] as num?)?.toDouble() ?? 0;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: revenue,
                color: colorScheme.primary,
                width: data.length > 14 ? 8 : 20,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY,
                  color: colorScheme.primary.withValues(alpha: 0.05),
                ),
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => colorScheme.surfaceContainerHighest,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final i = group.x;
              final day = i < data.length
                  ? _dayLabel(data[i]['day'] as String)
                  : '';
              final orders = i < data.length
                  ? (data[i]['order_count'] as num?)?.toInt() ?? 0
                  : 0;
              return BarTooltipItem(
                '$day\nKsh ${_chartFormat(rod.toY)}\n$orders orders',
                TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PIE CHART (payment methods — already uses real data)
// ─────────────────────────────────────────────────────────────────────────────

class _PieChartWidget extends ConsumerWidget {
  final ColorScheme colorScheme;

  const _PieChartWidget({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentData = ref.watch(paymentMethodsProvider);

    return paymentData.when(
      data: (sections) => PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
          pieTouchData: PieTouchData(
            enabled: true,
            touchCallback: (FlTouchEvent event, pieTouchResponse) {},
          ),
        ),
      ),
      loading: () => SkeletonChart(colorScheme: colorScheme),
      error: (_, _) => const Center(child: Text('Error')),
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

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _chartFormat(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return value.toStringAsFixed(0);
}
