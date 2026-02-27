import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Analytics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  const _TimeRangeSelector(),
                  const SizedBox(width: 12),
                  const _ChartTypeToggle(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: _ChartRenderer(
              chartType: chartType,
              colorScheme: colorScheme,
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

  const _ChartRenderer({required this.chartType, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    switch (chartType) {
      case ChartType.line:
        return _LineChart(colorScheme: colorScheme);
      case ChartType.bar:
        return _BarChart(colorScheme: colorScheme);
      case ChartType.area:
        return _AreaChart(colorScheme: colorScheme);
      case ChartType.pie:
        return _PieChartWidget(colorScheme: colorScheme);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHART TYPE TOGGLE
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
          _buildTypeButton(
            ChartType.area,
            Icons.stacked_line_chart,
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
// TIME RANGE SELECTOR
// ─────────────────────────────────────────────────────────────────────────────

class _TimeRangeSelector extends StatefulWidget {
  const _TimeRangeSelector();

  @override
  State<_TimeRangeSelector> createState() => _TimeRangeSelectorState();
}

class _TimeRangeSelectorState extends State<_TimeRangeSelector> {
  String selectedRange = 'This Week';
  final List<String> ranges = ['Today', 'This Week', 'This Month', 'This Year'];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      initialValue: selectedRange,
      onSelected: (value) {
        setState(() => selectedRange = value);
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
      itemBuilder: (context) => ranges
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
// LINE CHART
// ─────────────────────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final ColorScheme colorScheme;

  const _LineChart({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
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
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(1, 4),
              FlSpot(2, 3.5),
              FlSpot(3, 5),
              FlSpot(4, 4),
              FlSpot(5, 5.5),
              FlSpot(6, 5),
            ],
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
                return LineTooltipItem(
                  'Ksh ${(spot.y * 10000).toStringAsFixed(0)}',
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
// BAR CHART
// ─────────────────────────────────────────────────────────────────────────────

class _BarChart extends StatelessWidget {
  final ColorScheme colorScheme;

  const _BarChart({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
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
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          _makeBarGroup(0, 3, colorScheme.primary),
          _makeBarGroup(1, 4, colorScheme.primary),
          _makeBarGroup(2, 3.5, colorScheme.primary),
          _makeBarGroup(3, 5, colorScheme.secondary),
          _makeBarGroup(4, 4, colorScheme.primary),
          _makeBarGroup(5, 5.5, colorScheme.secondary),
          _makeBarGroup(6, 5, colorScheme.primary),
        ],
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => colorScheme.surfaceContainerHighest,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                'Ksh ${(rod.toY * 10000).toStringAsFixed(0)}',
                TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 20,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AREA CHART
// ─────────────────────────────────────────────────────────────────────────────

class _AreaChart extends StatelessWidget {
  final ColorScheme colorScheme;

  const _AreaChart({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
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
              getTitlesWidget: (value, meta) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 3),
              FlSpot(1, 4),
              FlSpot(2, 3.5),
              FlSpot(3, 5),
              FlSpot(4, 4),
              FlSpot(5, 5.5),
              FlSpot(6, 5),
            ],
            isCurved: true,
            color: Colors.transparent,
            barWidth: 0,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary.withValues(alpha: 0.8),
                  colorScheme.secondary.withValues(alpha: 0.4),
                  colorScheme.tertiary.withValues(alpha: 0.1),
                ],
                stops: const [0.0, 0.5, 1.0],
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
                return LineTooltipItem(
                  'Ksh ${(spot.y * 10000).toStringAsFixed(0)}',
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
// PIE CHART
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
        Text(
          percentage,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
