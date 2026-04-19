import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';

class _ReportsDaysNotifier extends Notifier<int> {
  @override
  int build() => 30;

  void setDays(int days) => state = days;
}

final reportsDaysProvider = NotifierProvider<_ReportsDaysNotifier, int>(
  _ReportsDaysNotifier.new,
);

final reportsSummaryProvider = StreamProvider.autoDispose<Map<String, dynamic>>(
  (ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final branchId = ref.watch(currentBranchIdProvider);
    final days = ref.watch(reportsDaysProvider);
    if (tenantId == null) return Stream.value(<String, dynamic>{});
    return ref
        .watch(repositoryProvider)
        .watchReportSummary(tenantId: tenantId, branchId: branchId, days: days);
  },
);

final reportsDailySalesProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      final days = ref.watch(reportsDaysProvider);
      final repo = ref.watch(repositoryProvider);
      if (tenantId == null) return Stream.value(<Map<String, dynamic>>[]);
      return repo.watchDailySalesDataSmart(
        tenantId: tenantId,
        branchId: branchId,
        days: days,
      );
    });

final reportsPaymentBreakdownProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      final days = ref.watch(reportsDaysProvider);
      if (tenantId == null) return Stream.value(<Map<String, dynamic>>[]);
      return ref
          .watch(repositoryProvider)
          .watchPaymentMethodBreakdownInRange(
            tenantId: tenantId,
            branchId: branchId,
            days: days,
          );
    });

final reportsTopProductsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      final days = ref.watch(reportsDaysProvider);
      if (tenantId == null) return Stream.value(<Map<String, dynamic>>[]);
      return ref
          .watch(repositoryProvider)
          .watchTopProductsInRange(
            tenantId: tenantId,
            branchId: branchId,
            days: days,
            limit: 8,
          );
    });

final reportsInvoiceStatusProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      final days = ref.watch(reportsDaysProvider);
      if (tenantId == null) return Stream.value(<Map<String, dynamic>>[]);
      return ref
          .watch(repositoryProvider)
          .watchInvoiceStatusBreakdown(
            tenantId: tenantId,
            branchId: branchId,
            days: days,
          );
    });

final reportsCommissionSummaryProvider =
    StreamProvider.autoDispose<List<SalespersonCommissionSummary>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final branchId = ref.watch(currentBranchIdProvider);
      final days = ref.watch(reportsDaysProvider);
      if (tenantId == null) {
        return Stream.value(<SalespersonCommissionSummary>[]);
      }

      final startDate = DateTime.now().subtract(Duration(days: days - 1));
      final endDate = DateTime.now();

      return ref
          .watch(repositoryProvider)
          .watchCommissionSummaryRaw(
            tenantId: tenantId,
            branchId: branchId,
            startDate: startDate,
            endDate: endDate,
          )
          .map(
            (rows) => rows
                .map(
                  (row) => SalespersonCommissionSummary(
                    salespersonId: row['salesperson_id'] as String? ?? '',
                    salespersonName:
                        row['salesperson_name'] as String? ??
                        'Unknown Salesperson',
                    totalPending:
                        (row['total_pending'] as num?)?.toDouble() ?? 0.0,
                    totalPaid: (row['total_paid'] as num?)?.toDouble() ?? 0.0,
                    transactionCount:
                        (row['transaction_count'] as num?)?.toInt() ?? 0,
                    totalSalesAmount:
                        (row['total_sales_amount'] as num?)?.toDouble() ?? 0.0,
                    salesCount: (row['sales_count'] as num?)?.toInt() ?? 0,
                  ),
                )
                .toList(),
          );
    });

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final days = ref.watch(reportsDaysProvider);
    final profile = ref.watch(currentUserProfileProvider).value;

    return Scaffold(
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: Builder(
              builder: (context) => IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.list),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            title: const Text('Reports'),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?.tenantId == null
                        ? 'No tenant selected'
                        : 'Branch-aware performance and operations',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  _RangeSwitcher(
                    days: days,
                    onChanged: (newDays) =>
                        ref.read(reportsDaysProvider.notifier).setDays(newDays),
                  ),
                  const SizedBox(height: 16),
                  const _ReportSummaryGrid(),
                  const SizedBox(height: 16),
                  const _SalesTrendCard(),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 900;
                      if (stacked) {
                        return const Column(
                          children: [
                            _PaymentMixCard(),
                            SizedBox(height: 16),
                            _InvoiceStatusCard(),
                          ],
                        );
                      }
                      return const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _PaymentMixCard()),
                          SizedBox(width: 16),
                          Expanded(child: _InvoiceStatusCard()),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  const _TopProductsReportCard(),
                  const SizedBox(height: 16),
                  const _CommissionLeaderboardCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSwitcher extends StatelessWidget {
  const _RangeSwitcher({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const options = [7, 30, 90];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((option) {
          final selected = option == days;
          final label = option == 7
              ? '7d'
              : option == 30
              ? '30d'
              : '90d';
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ReportSummaryGrid extends ConsumerWidget {
  const _ReportSummaryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportsSummaryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return summaryAsync.when(
      loading: () =>
          const _ReportCard(title: 'Summary', child: SizedBox(height: 120)),
      error: (e, _) => _ReportCard(
        title: 'Summary',
        child: Text('Failed to load summary: $e'),
      ),
      data: (summary) {
        final grossSales = _asDouble(summary['gross_sales']);
        final paid = _asDouble(summary['payments_collected']);
        final avg = _asDouble(summary['average_ticket']);
        final pending = _asInt(summary['pending_approval_count']);
        final lowStock = _asInt(summary['low_stock_count']);
        final unreleased = _asInt(summary['unreleased_count']);

        return _ReportCard(
          title: 'Summary',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              final children = [
                _KpiTile(
                  label: 'Gross Sales',
                  value: _currency(grossSales),
                  color: colorScheme.primary,
                ),
                _KpiTile(
                  label: 'Payments Collected',
                  value: _currency(paid),
                  color: colorScheme.tertiary,
                ),
                _KpiTile(
                  label: 'Avg Ticket',
                  value: _currency(avg),
                  color: colorScheme.secondary,
                ),
                _KpiTile(
                  label: 'Pending Approvals',
                  value: '$pending',
                  color: colorScheme.error,
                ),
                _KpiTile(
                  label: 'Unreleased Invoices',
                  value: '$unreleased',
                  color: const Color(0xFFF59E0B),
                ),
                _KpiTile(
                  label: 'Low Stock SKUs',
                  value: '$lowStock',
                  color: const Color(0xFF10B981),
                ),
              ];

              if (compact) {
                return Column(
                  children: children
                      .map(
                        (child) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: child,
                        ),
                      )
                      .toList(),
                );
              }

              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.35,
                children: children,
              );
            },
          ),
        );
      },
    );
  }
}

class _SalesTrendCard extends ConsumerWidget {
  const _SalesTrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(reportsDailySalesProvider);

    return _ReportCard(
      title: 'Revenue Trend',
      subtitle: 'Daily branch-aware totals',
      child: dataAsync.when(
        loading: () => const SizedBox(height: 220),
        error: (e, _) => Text('Failed to load trend: $e'),
        data: (rows) {
          if (rows.isEmpty) {
            return const SizedBox(
              height: 220,
              child: Center(child: Text('No trend data yet')),
            );
          }

          final spots = <FlSpot>[];
          final labels = <String>[];
          for (var i = 0; i < rows.length; i++) {
            final row = rows[i];
            final day = (row['day'] as String?) ?? '';
            final dt = DateTime.tryParse(day);
            labels.add(dt == null ? day : DateFormat('d MMM').format(dt));
            spots.add(FlSpot(i.toDouble(), _asDouble(row['revenue'])));
          }

          final maxY = spots.fold<double>(0, (m, s) => s.y > m ? s.y : m);
          final safeMaxY = maxY <= 0 ? 100.0 : maxY * 1.2;
          final colorScheme = Theme.of(context).colorScheme;

          return SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: safeMaxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: rows.length > 10 ? 3 : 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) {
                          return const SizedBox();
                        }
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            labels[idx],
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        child: Text(
                          value >= 1000
                              ? '${(value / 1000).toStringAsFixed(0)}K'
                              : value.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => colorScheme.inverseSurface,
                    getTooltipItems: (touchedSpots) => touchedSpots
                        .map(
                          (spot) => LineTooltipItem(
                            _currency(spot.y),
                            TextStyle(color: colorScheme.onInverseSurface),
                          ),
                        )
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 2.4,
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withValues(alpha: 0.12),
                    ),
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentMixCard extends ConsumerWidget {
  const _PaymentMixCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(reportsPaymentBreakdownProvider);

    return _ReportCard(
      title: 'Payment Mix',
      child: paymentsAsync.when(
        loading: () => const SizedBox(height: 220),
        error: (e, _) => Text('Failed to load payment mix: $e'),
        data: (rows) {
          if (rows.isEmpty) {
            return const SizedBox(
              height: 220,
              child: Center(child: Text('No payment data yet')),
            );
          }

          final total = rows.fold<double>(
            0,
            (sum, row) => sum + _asDouble(row['total']),
          );
          final palette = [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.tertiary,
            Theme.of(context).colorScheme.secondary,
            const Color(0xFFF59E0B),
            const Color(0xFF10B981),
          ];

          final sections = rows.asMap().entries.map((entry) {
            final amount = _asDouble(entry.value['total']);
            return PieChartSectionData(
              value: amount,
              color: palette[entry.key % palette.length],
              radius: 9,
              showTitle: false,
            );
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 46,
                        sectionsSpace: 2,
                        sections: sections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _currency(total),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Collected',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...rows.asMap().entries.map((entry) {
                final row = entry.value;
                final amount = _asDouble(row['total']);
                final pct = total <= 0 ? 0 : ((amount / total) * 100).round();
                final label = _formatPaymentMethod(
                  (row['payment_method'] as String?) ?? 'unknown',
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: palette[entry.key % palette.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(label)),
                      Text('$pct%'),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceStatusCard extends ConsumerWidget {
  const _InvoiceStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(reportsInvoiceStatusProvider);

    return _ReportCard(
      title: 'Invoice Lifecycle Mix',
      child: statusAsync.when(
        loading: () => const SizedBox(height: 220),
        error: (e, _) => Text('Failed to load lifecycle mix: $e'),
        data: (rows) {
          if (rows.isEmpty) {
            return const SizedBox(
              height: 220,
              child: Center(child: Text('No invoice data yet')),
            );
          }

          final total = rows.fold<int>(
            0,
            (sum, row) => sum + _asInt(row['count']),
          );
          final colors = {
            'approved': Theme.of(context).colorScheme.primary,
            'pending_approval': const Color(0xFFF59E0B),
            'voided': Theme.of(context).colorScheme.error,
            'rejected': const Color(0xFFDC2626),
          };

          return Column(
            children: rows.map((row) {
              final status = (row['status'] as String?) ?? 'unknown';
              final count = _asInt(row['count']);
              final pct = total == 0 ? 0.0 : count / total;
              final color =
                  colors[status] ?? Theme.of(context).colorScheme.secondary;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatStatus(status),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('$count'),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        color: color,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _TopProductsReportCard extends ConsumerWidget {
  const _TopProductsReportCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topProductsAsync = ref.watch(reportsTopProductsProvider);

    return _ReportCard(
      title: 'Top Products',
      subtitle: 'By sold quantity and revenue',
      child: topProductsAsync.when(
        loading: () => const SizedBox(height: 160),
        error: (e, _) => Text('Failed to load products: $e'),
        data: (rows) {
          if (rows.isEmpty) {
            return const SizedBox(
              height: 160,
              child: Center(child: Text('No product movement yet')),
            );
          }

          final maxSold = rows.fold<double>(
            1,
            (m, row) => _asDouble(row['total_sold']) > m
                ? _asDouble(row['total_sold'])
                : m,
          );

          return Column(
            children: rows.take(6).map((row) {
              final name = (row['name'] as String?) ?? 'Unknown Product';
              final sold = _asDouble(row['total_sold']);
              final revenue = _asDouble(row['total_revenue']);
              final ratio = maxSold <= 0 ? 0.0 : sold / maxSold;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${sold.toInt()} sold',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _currency(revenue),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CommissionLeaderboardCard extends ConsumerWidget {
  const _CommissionLeaderboardCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commissionsAsync = ref.watch(reportsCommissionSummaryProvider);

    return _ReportCard(
      title: 'Commissions',
      subtitle: 'Top performers and pending payouts',
      child: commissionsAsync.when(
        loading: () => const SizedBox(height: 140),
        error: (e, _) => Text('Failed to load commissions: $e'),
        data: (rows) {
          if (rows.isEmpty) {
            return const SizedBox(
              height: 140,
              child: Center(child: Text('No commissions generated yet')),
            );
          }

          return Column(
            children: rows.take(6).map((row) {
              final total = row.totalEarned;
              final paid = row.totalPaid;
              final pending = row.totalPending;
              final paidPct = total <= 0 ? 0.0 : paid / total;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.salespersonName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(_currency(total)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Paid ${_currency(paid)} • Pending ${_currency(pending)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: paidPct,
                        minHeight: 6,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.error.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
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

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

double _asDouble(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

int _asInt(dynamic value) => (value as num?)?.toInt() ?? 0;

String _currency(double value) {
  final compact = NumberFormat.compactCurrency(
    symbol: 'Ksh ',
    decimalDigits: value.abs() >= 100000 ? 1 : 0,
  );
  return compact.format(value);
}

String _formatPaymentMethod(String raw) {
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
    case 'credit_note':
      return 'Credit Note';
    default:
      return raw.isEmpty ? 'Unknown' : raw;
  }
}

String _formatStatus(String raw) {
  switch (raw) {
    case 'pending_approval':
      return 'Pending Approval';
    case 'approved':
      return 'Approved';
    case 'voided':
      return 'Voided';
    case 'rejected':
      return 'Rejected';
    default:
      return raw;
  }
}
