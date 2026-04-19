import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final _dateRangeProvider = NotifierProvider<_DateRangeNotifier, DateTimeRange?>(
  _DateRangeNotifier.new,
);

class _DateRangeNotifier extends Notifier<DateTimeRange?> {
  @override
  DateTimeRange? build() => null;

  void setRange(DateTimeRange? range) {
    state = range;
  }
}

final _commissionSummaryProvider = StreamProvider.autoDispose
    .family<
      List<SalespersonCommissionSummary>,
      ({String tenantId, String? branchId, DateTimeRange? range})
    >((ref, args) {
      final repo = ref.watch(repositoryProvider);
      return repo
          .watchCommissionSummaryRaw(
            tenantId: args.tenantId,
            branchId: args.branchId,
            startDate: args.range?.start,
            endDate: args.range?.end,
          )
          .map(
            (rows) => rows.map((row) {
              return SalespersonCommissionSummary(
                salespersonId: row['salesperson_id'] as String? ?? '',
                salespersonName:
                    row['salesperson_name'] as String? ?? 'Unknown',
                totalPending: (row['total_pending'] as num?)?.toDouble() ?? 0.0,
                totalPaid: (row['total_paid'] as num?)?.toDouble() ?? 0.0,
                transactionCount:
                    (row['transaction_count'] as num?)?.toInt() ?? 0,
                totalSalesAmount:
                    (row['total_sales_amount'] as num?)?.toDouble() ?? 0.0,
                salesCount: (row['sales_count'] as num?)?.toInt() ?? 0,
              );
            }).toList(),
          );
    });

final _salespersonDetailProvider = StreamProvider.autoDispose
    .family<
      List<Commission>,
      ({
        String tenantId,
        String? branchId,
        String salespersonId,
        DateTimeRange? range,
      })
    >((ref, args) {
      final repo = ref.watch(repositoryProvider);
      return repo.watchCommissions(
        tenantId: args.tenantId,
        branchId: args.branchId,
        salespersonId: args.salespersonId,
        startDate: args.range?.start,
        endDate: args.range?.end,
      );
    });

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CommissionsReportScreen extends ConsumerWidget {
  const CommissionsReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(currentUserProfileProvider).value;
    final tenantId = profile?.tenantId ?? '';
    final branchId = ref.watch(currentBranchIdProvider);

    final dateRange = ref.watch(_dateRangeProvider);
    final summaryAsync = ref.watch(
      _commissionSummaryProvider((
        tenantId: tenantId,
        branchId: branchId,
        range: dateRange,
      )),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: Builder(
              builder: (context) {
                if (MediaQuery.of(context).size.width < 840) {
                  return IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.list),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            title: const Text('Commission Report'),
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            actions: [
              IconButton(
                icon: const Icon(Icons.date_range_rounded),
                onPressed: () async {
                  final currentRange = ref.read(_dateRangeProvider);
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: currentRange,
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          appBarTheme: AppBarTheme(
                            backgroundColor: colorScheme.surface,
                            foregroundColor: colorScheme.onSurface,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(_dateRangeProvider.notifier).setRange(picked);
                  }
                },
              ),
              if (ref.watch(_dateRangeProvider) != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () =>
                      ref.read(_dateRangeProvider.notifier).setRange(null),
                ),
            ],
          ),
          summaryAsync.when(
            loading: () =>
                const SliverFillRemaining(child: _CommissionSkeletonList()),
            error: (e, _) =>
                SliverFillRemaining(child: _ErrorState(message: e.toString())),
            data: (summaries) {
              if (summaries.isEmpty) {
                return const SliverFillRemaining(child: _EmptyState());
              }

              // Totals bar
              final grandTotal = summaries.fold(
                0.0,
                (a, s) => a + s.totalEarned,
              );
              final grandPending = summaries.fold(
                0.0,
                (a, s) => a + s.totalPending,
              );
              final grandPaid = summaries.fold(0.0, (a, s) => a + s.totalPaid);
              final grandSales = summaries.fold(
                0.0,
                (a, s) => a + s.totalSalesAmount,
              );

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (dateRange != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_alt,
                            size: 16,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Filtered: ${DateFormat.yMd().format(dateRange.start)} - ${DateFormat.yMd().format(dateRange.end)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _TotalsCard(
                    grandTotal: grandTotal,
                    grandPending: grandPending,
                    grandPaid: grandPaid,
                    grandSales: grandSales,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'BY SALESPERSON',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ...summaries.map(
                    (s) => _SalespersonCard(
                      summary: s,
                      tenantId: tenantId,
                      branchId: branchId,
                    ),
                  ),
                  const SizedBox(height: 32),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Totals Card
// ─────────────────────────────────────────────────────────────────────────────

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.grandTotal,
    required this.grandPending,
    required this.grandPaid,
    this.grandSales = 0.0,
  });

  final double grandTotal;
  final double grandPending;
  final double grandPaid;
  final double grandSales;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Commissions',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              fmt.format(grandTotal),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Generated Revenue',
                    value: fmt.format(grandSales),
                    color: colorScheme.onSurface,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Pending',
                    value: fmt.format(grandPending),
                    color: colorScheme.primary, // Highlight pending
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Paid Out',
                    value: fmt.format(grandPaid),
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color.withAlpha(160)),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Salesperson Card
// ─────────────────────────────────────────────────────────────────────────────

class _SalespersonCard extends ConsumerWidget {
  const _SalespersonCard({
    required this.summary,
    required this.tenantId,
    required this.branchId,
  });

  final SalespersonCommissionSummary summary;
  final String tenantId;
  final String? branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fmt = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);

    final pendingPct = summary.totalEarned > 0
        ? summary.totalPending / summary.totalEarned
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetail(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        summary.salespersonName.isNotEmpty
                            ? summary.salespersonName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.salespersonName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Generated ${fmt.format(summary.totalSalesAmount)} Rev (${summary.salesCount} sale${summary.salesCount == 1 ? '' : 's'})',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${summary.transactionCount} commission${summary.transactionCount == 1 ? '' : 's'}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          fmt.format(summary.totalEarned),
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        if (summary.totalPending > 0)
                          Text(
                            '${fmt.format(summary.totalPending)} pending',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar: paid vs pending
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 1 - pendingPct,
                    backgroundColor: colorScheme.errorContainer,
                    color: colorScheme.primary,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Paid ${fmt.format(summary.totalPaid)}',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (summary.totalPending > 0)
                      FilledButton.tonal(
                        onPressed: () => _markAllPaid(context, ref),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Mark Paid',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _markAllPaid(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark All as Paid'),
        content: Text(
          'Mark all pending commissions for ${summary.salespersonName} as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref
        .read(repositoryProvider)
        .markAllCommissionsPaid(
          tenantId: tenantId,
          salespersonId: summary.salespersonId,
          branchId: branchId,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'All commissions for ${summary.salespersonName} marked as paid.',
          ),
        ),
      );
    }
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CommissionDetailSheet(
        tenantId: tenantId,
        branchId: branchId,
        summary: summary,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CommissionDetailSheet extends ConsumerWidget {
  const _CommissionDetailSheet({
    required this.tenantId,
    required this.branchId,
    required this.summary,
  });

  final String tenantId;
  final String? branchId;
  final SalespersonCommissionSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final fmt = NumberFormat.currency(symbol: 'KES ', decimalDigits: 2);
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    final commissionsAsync = ref.watch(
      _salespersonDetailProvider((
        tenantId: tenantId,
        branchId: branchId,
        salespersonId: summary.salespersonId,
        range: ref.watch(_dateRangeProvider),
      )),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    summary.salespersonName[0].toUpperCase(),
                    style: TextStyle(color: colorScheme.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.salespersonName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total: ${fmt.format(summary.totalEarned)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: commissionsAsync.when(
              loading: () => const Center(child: _ShimmerList()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (commissions) {
                if (commissions.isEmpty) {
                  return const Center(child: Text('No commissions found'));
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: commissions.length,
                  itemBuilder: (_, i) {
                    final c = commissions[i];
                    final isPaid = c.status == 'paid';
                    return ListTile(
                      leading: Icon(
                        isPaid
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: isPaid ? colorScheme.primary : colorScheme.error,
                      ),
                      title: Text(
                        fmt.format(c.amount),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        c.createdAt != null ? dateFmt.format(c.createdAt!) : '',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: isPaid
                          ? Chip(
                              label: const Text('Paid'),
                              backgroundColor: colorScheme.primaryContainer,
                              labelStyle: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontSize: 11,
                              ),
                              padding: EdgeInsets.zero,
                            )
                          : FilledButton.tonal(
                              onPressed: () async {
                                await ref
                                    .read(repositoryProvider)
                                    .markCommissionPaid(c.id);
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Pay',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeletons / States
// ─────────────────────────────────────────────────────────────────────────────

class _CommissionSkeletonList extends StatelessWidget {
  const _CommissionSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return const _CommissionSkeletonList();
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: 72,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No commissions yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commissions are calculated automatically\nwhen sales are completed.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message),
          ],
        ),
      ),
    );
  }
}
