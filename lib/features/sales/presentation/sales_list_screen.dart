import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/features/sales/presentation/sales_search_screen.dart';
import 'package:zynk/features/sales/presentation/widgets/sale_card.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';
import 'package:zynk/shared/widgets/branch_filter_chips.dart';
import 'package:zynk/shared/widgets/date_range_filter.dart';

import '../../../core/widgets/app_drawer.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  Object? _filter; // null = All, InvoiceStatus = exact, 'outstanding' = special
  String?
  _branchFilter; // null = current branch selection, specific branchId = filter

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(salesListLimitProvider.notifier).increment(50);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final salesAsync = ref.watch(
      filteredSalesListProvider((branchId: _branchFilter, status: _filter)),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
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
        title: const Text('Invoices'),
        actions: [
          Center(
            child: DateRangeFilter(
              selectedRange: ref.watch(salesListDateRangeProvider),
              onChanged: (range) {
                ref.read(salesListLimitProvider.notifier).reset();
                ref.read(salesListDateRangeProvider.notifier).setRange(range);
              },
            ),
          ),
          const SizedBox(width: 8),
          OpenContainer(
            transitionType: ContainerTransitionType.fadeThrough,
            closedElevation: 0,
            openElevation: 0,
            closedColor: Colors.transparent,
            openColor: theme.colorScheme.surface,
            middleColor: theme.colorScheme.surface,
            closedBuilder: (context, action) {
              return IconButton(
                icon: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass),
                onPressed: action,
              );
            },
            openBuilder: (context, action) {
              return const SalesSearchScreen();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterBar(theme, cs),
          const Divider(height: 1),
          // Sales list
          Expanded(
            child: Builder(
              builder: (context) {
                if (salesAsync.isLoading && !salesAsync.hasValue) {
                  return _SalesListSkeleton();
                }
                if (salesAsync.hasError && !salesAsync.hasValue) {
                  return Center(child: Text('Error: ${salesAsync.error}'));
                }

                final sales = salesAsync.value ?? [];

                // Branch filtering is handled server-side now by the provider
                final branchFiltered = sales;

                final filtered = _filter == null || _filter is InvoiceStatus
                    // InvoiceStatus is handled server-side, everything else handled here
                    ? branchFiltered
                    : _filter == 'outstanding'
                    ? branchFiltered
                          .where(
                            (s) =>
                                s.status != InvoiceStatus.voided &&
                                s.status != InvoiceStatus.rejected &&
                                !s.isOperationallyCompleted,
                          )
                          .toList()
                    : _filter is PaymentStatus
                    ? branchFiltered
                          .where((s) => s.paymentStatus == _filter)
                          .toList()
                    : _filter is FulfillmentStatus
                    ? branchFiltered
                          .where((s) => s.fulfillmentStatus == _filter)
                          .toList()
                    : branchFiltered;

                if (filtered.isEmpty) {
                  return _buildEmpty(theme, cs);
                }

                return ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length + (salesAsync.isLoading ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (i == filtered.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return SaleCard(sale: filtered[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }

  Widget _buildFilterBar(ThemeData theme, ColorScheme cs) {
    // null = All, String = special, ENUM = exact match
    final filters = [
      (null, 'All', PhosphorIconsRegular.listBullets),
      ('outstanding', 'Outstanding', PhosphorIconsRegular.warningCircle),
      (
        InvoiceStatus.pendingApproval,
        'Pending Approval',
        PhosphorIconsRegular.clock,
      ),
      (InvoiceStatus.approved, 'Approved', PhosphorIconsRegular.sealCheck),
      (PaymentStatus.unpaid, 'Unpaid', PhosphorIconsRegular.money),
      (PaymentStatus.partiallyPaid, 'Partial', PhosphorIconsRegular.percent),
      (PaymentStatus.paid, 'Paid', PhosphorIconsRegular.currencyCircleDollar),
      (
        FulfillmentStatus.unreleased,
        'Unreleased',
        PhosphorIconsRegular.package,
      ),
      (FulfillmentStatus.released, 'Released', PhosphorIconsRegular.package),
      (InvoiceStatus.voided, 'Voided', PhosphorIconsRegular.prohibit),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Branch filter (only visible when "All Branches" is selected)
        BranchFilterChips(
          selectedBranchId: _branchFilter,
          onSelected: (id) => setState(() => _branchFilter = id),
        ),
        // Status filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: filters.map((f) {
              final isActive = _filter == f.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isActive,
                  showCheckmark: false,
                  avatar: PhosphorIcon(
                    f.$3,
                    size: 16,
                    color: isActive ? cs.onPrimary : cs.onSurface,
                  ),
                  label: Text(f.$2),
                  labelStyle: TextStyle(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? cs.onPrimary : cs.onSurface,
                  ),
                  selectedColor: cs.primary,
                  side: BorderSide(
                    color: isActive
                        ? cs.primary
                        : cs.outline.withValues(alpha: 0.3),
                  ),
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(ThemeData theme, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIconsDuotone.receipt,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No invoices yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete a POS sale to start seeing invoices',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON LOADER
// ─────────────────────────────────────────────────────────────────────────────

class _SalesListSkeleton extends StatelessWidget {
  const _SalesListSkeleton();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => Shimmer.fromColors(
        baseColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        highlightColor: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
