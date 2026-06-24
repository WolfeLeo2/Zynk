import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/services/commission_service.dart';
import 'package:zynk/core/utils/responsive_modal.dart';


// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

enum CommissionStatus { all, pending, paid }

final _selectedMonthProvider =
    NotifierProvider<_SelectedMonthNotifier, DateTime>(
      _SelectedMonthNotifier.new,
    );

class _SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1);
  }

  void setMonth(DateTime date) {
    state = DateTime(date.year, date.month);
  }
}

class _CommissionStatusNotifier extends Notifier<CommissionStatus> {
  @override
  CommissionStatus build() => CommissionStatus.all;
  @override
  set state(CommissionStatus val) => super.state = val;
}

final _commissionStatusProvider =
    NotifierProvider<_CommissionStatusNotifier, CommissionStatus>(
      _CommissionStatusNotifier.new,
    );

final _commissionSummaryProvider = StreamProvider.autoDispose
    .family<
      List<SalespersonCommissionSummary>,
      ({
        String tenantId,
        String? branchId,
        DateTime month,
        CommissionStatus status,
      })
    >((ref, args) {
      final repo = ref.watch(repositoryProvider);
      final startDate = args.month;
      final endDate = DateTime(
        args.month.year,
        args.month.month + 1,
        0,
        23,
        59,
        59,
      );

      return repo
          .watchCommissionSummaryRaw(
            tenantId: args.tenantId,
            branchId: args.branchId,
            startDate: startDate,
            endDate: endDate,
          )
          .map((rows) {
            final summaries = rows.map((row) {
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
            }).toList();

            if (args.status == CommissionStatus.pending) {
              return summaries.where((s) => s.totalPending > 0).toList();
            } else if (args.status == CommissionStatus.paid) {
              return summaries
                  .where((s) => s.totalPaid > 0 && s.totalPending == 0)
                  .toList();
            }
            return summaries;
          });
    });

final _salespersonDetailProvider = StreamProvider.autoDispose
    .family<
      List<Commission>,
      ({
        String tenantId,
        String? branchId,
        String salespersonId,
        DateTime month,
      })
    >((ref, args) {
      final repo = ref.watch(repositoryProvider);
      final startDate = args.month;
      final endDate = DateTime(
        args.month.year,
        args.month.month + 1,
        0,
        23,
        59,
        59,
      );

      return repo.watchCommissions(
        tenantId: args.tenantId,
        branchId: args.branchId,
        salespersonId: args.salespersonId,
        startDate: startDate,
        endDate: endDate,
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

    final selectedMonth = ref.watch(_selectedMonthProvider);
    final status = ref.watch(_commissionStatusProvider);
    final summaryAsync = ref.watch(
      _commissionSummaryProvider((
        tenantId: tenantId,
        branchId: branchId,
        month: selectedMonth,
        status: status,
      )),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      body: summaryAsync.when(
        loading: () => const _CommissionSkeletonList(),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (summaries) {
          final grandSales = summaries.fold(
            0.0,
            (a, s) => a + s.totalSalesAmount,
          );
          final grandPending = summaries.fold(
            0.0,
            (a, s) => a + s.totalPending,
          );
          final grandPaid = summaries.fold(0.0, (a, s) => a + s.totalPaid);

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                stretch: true,
                backgroundColor: colorScheme.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.primaryContainer.withAlpha(80),
                          colorScheme.surface,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 48),
                          const _MonthPill(),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _HeroStat(
                                label: 'SALES',
                                value: grandSales,
                                color: colorScheme.primary,
                              ),
                              _HeroStat(
                                label: 'PENDING',
                                value: grandPending,
                                color: Colors.orange,
                              ),
                              _HeroStat(
                                label: 'PAID',
                                value: grandPaid,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                leading: Builder(
                  builder: (context) {
                    return IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.list),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    );
                  },
                ),
                title: Text(
                  'Commissions',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: status == CommissionStatus.all,
                          onSelected: (_) =>
                              ref
                                      .read(_commissionStatusProvider.notifier)
                                      .state =
                                  CommissionStatus.all,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Pending'),
                          selected: status == CommissionStatus.pending,
                          onSelected: (_) =>
                              ref
                                      .read(_commissionStatusProvider.notifier)
                                      .state =
                                  CommissionStatus.pending,
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Paid'),
                          selected: status == CommissionStatus.paid,
                          onSelected: (_) =>
                              ref
                                      .read(_commissionStatusProvider.notifier)
                                      .state =
                                  CommissionStatus.paid,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            body: summaries.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: summaries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            'BY SALESPERSON',
                            style: textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 1.2,
                            ),
                          ),
                        );
                      }
                      final s = summaries[index - 1];
                      return _SalespersonCard(
                        summary: s,
                        tenantId: tenantId,
                        branchId: branchId,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final fmt = NumberFormat.compactCurrency(symbol: 'KES ', decimalDigits: 1);

    return Column(
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 1.1,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          fmt.format(value),
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

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
    final fmt = NumberFormat.compactCurrency(symbol: 'KES ', decimalDigits: 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(50)),
      ),
      child: InkWell(
        onTap: () => _showDetail(context, ref),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _SalespersonAvatar(name: summary.salespersonName),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.salespersonName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.salesCount} Sales • ${fmt.format(summary.totalSalesAmount)} Revenue',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fmt.format(summary.totalEarned),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                    ),
                  ),
                  if (summary.totalPending > 0)
                    Text(
                      '${fmt.format(summary.totalPending)} pending',
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, WidgetRef ref) {
    showResponsiveModal(
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

class _SalespersonAvatar extends StatelessWidget {
  const _SalespersonAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withAlpha(150)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
        month: ref.watch(_selectedMonthProvider),
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
                      leading: PhosphorIcon(
                        isPaid
                            ? PhosphorIconsRegular.checkCircle
                            : PhosphorIconsRegular.circle,
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
                                try {
                                  await ref
                                      .read(commissionServiceProvider)
                                      .markPaid(
                                        tenantId: tenantId,
                                        commissionId: c.id,
                                      );

                                  // Force refresh
                                  ref.invalidate(_commissionSummaryProvider);
                                  ref.invalidate(
                                    _salespersonDetailProvider((
                                      tenantId: tenantId,
                                      branchId: branchId,
                                      salespersonId: summary.salespersonId,
                                      month: ref.read(_selectedMonthProvider),
                                    )),
                                  );
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: colorScheme.error,
                                      ),
                                    );
                                  }
                                }
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
          PhosphorIcon(
            PhosphorIconsRegular.chartBar,
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
            PhosphorIcon(
              PhosphorIconsRegular.warningCircle,
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

class _MonthPill extends ConsumerWidget {
  const _MonthPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: UnconstrainedBox(
        child: InkWell(
          onTap: () => _showMonthPicker(context, ref),
          borderRadius: BorderRadius.circular(32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer.withAlpha(150),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(100),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.calendarBlank,
                  size: 18,
                  color: colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMMM yyyy').format(selectedMonth),
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 4),
                PhosphorIcon(
                  PhosphorIconsRegular.caretDown,
                  size: 14,
                  color: colorScheme.onSecondaryContainer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMonthPicker(BuildContext context, WidgetRef ref) {
    showResponsiveModal(
      context: context,
      builder: (context) => const _MonthPickerSheet(),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    );
  }
}

class _MonthPickerSheet extends ConsumerWidget {
  const _MonthPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(_selectedMonthProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Month',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = DateTime(selectedMonth.year, index + 1);
              final isSelected = month.month == selectedMonth.month;
              final isFuture = month.isAfter(DateTime.now());

              return InkWell(
                onTap: isFuture
                    ? null
                    : () {
                        ref
                            .read(_selectedMonthProvider.notifier)
                            .setMonth(month);
                        Navigator.pop(context);
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withAlpha(100),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    DateFormat('MMM').format(month),
                    style: textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimary
                          : isFuture
                          ? colorScheme.outline
                          : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          // Simple Year Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.caretLeft),
                onPressed: () {
                  ref
                      .read(_selectedMonthProvider.notifier)
                      .setMonth(
                        DateTime(selectedMonth.year - 1, selectedMonth.month),
                      );
                },
              ),
              Text(
                selectedMonth.year.toString(),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.caretRight),
                onPressed: selectedMonth.year >= DateTime.now().year
                    ? null
                    : () {
                        ref
                            .read(_selectedMonthProvider.notifier)
                            .setMonth(
                              DateTime(
                                selectedMonth.year + 1,
                                selectedMonth.month,
                              ),
                            );
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
