import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/sales_models.dart';

import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zynk/features/customers/providers/customer_providers.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/shared/widgets/branch_filter_chips.dart';

class SalesListScreen extends ConsumerStatefulWidget {
  const SalesListScreen({super.key});

  @override
  ConsumerState<SalesListScreen> createState() => _SalesListScreenState();
}

class _SalesListScreenState extends ConsumerState<SalesListScreen> {
  Object? _filter; // null = All, InvoiceStatus = exact, 'outstanding' = special
  String?
  _branchFilter; // null = current branch selection, specific branchId = filter

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final salesAsync = ref.watch(salesListProvider);

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
        title: const Text('Sales & Invoices'),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass),
            onPressed: () {}, // TODO: search
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterBar(theme, cs),
          const Divider(height: 1),
          // Sales list
          Expanded(
            child: salesAsync.when(
              data: (sales) {
                // Apply branch filter client-side
                var branchFiltered = _branchFilter == null
                    ? sales
                    : sales.where((s) => s.branchId == _branchFilter).toList();

                final filtered = _filter == null
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
                    : _filter is InvoiceStatus
                    ? branchFiltered.where((s) => s.status == _filter).toList()
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
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _SaleCard(sale: filtered[i]),
                );
              },
              loading: () => _SalesListSkeleton(),
              error: (e, _) => Center(child: Text('Error: $e')),
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

// ─────────────────────────────────────────────────────────────────────────────
// SALE CARD (Shopify-style)
// ─────────────────────────────────────────────────────────────────────────────

class _SaleCard extends ConsumerWidget {
  final Sale sale;
  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Resolve customer name from local memory provider
    final customersAsync = ref.watch(allCustomersProvider);
    final customerName = customersAsync.maybeWhen(
      data: (customers) {
        if (sale.customerId == null) return 'Walk-in Customer';
        return customers
            .where((c) => c.id == sale.customerId)
            .firstOrNull
            ?.name ?? 'Walk-in Customer';
      },
      orElse: () => 'Loading...',
    );

    return InkWell(
      onTap: () => context.push('/sales/${sale.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor(sale.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: PhosphorIcon(
                  _statusIcon(sale.status),
                  color: _statusColor(sale.status),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.invoiceNumber ?? '#—',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              customerName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Time Ago (Top Right)
                      Text(
                        _formatDate(sale.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Badges
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _LifecycleBadge(status: sale.status),
                            _PaymentStatusBadge(status: sale.paymentStatus),
                            _FulfillmentStatusBadge(
                              status: sale.fulfillmentStatus,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Ksh ${sale.grandTotal.toStringAsFixed(0)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildPaymentStatusText(theme, sale),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 4),
            PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 18,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStatusText(ThemeData theme, Sale sale) {
    if (sale.paymentStatus == PaymentStatus.unpaid) {
      return Text(
        'Unpaid',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFFEF5350),
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (sale.paymentStatus == PaymentStatus.partiallyPaid) {
      return Text(
        'Due: ${sale.remainingBalance.toStringAsFixed(0)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFFFFA726),
          fontWeight: FontWeight.w600,
        ),
      );
    } else {
      return Text(
        'Paid',
        style: theme.textTheme.bodySmall?.copyWith(
          color: const Color(0xFF66BB6A),
          fontWeight: FontWeight.w600,
        ),
      );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final localDate = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${localDate.day}/${localDate.month}/${localDate.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _LifecycleBadge extends StatelessWidget {
  final InvoiceStatus status;
  const _LifecycleBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);

    return _MiniStateBadge(
      label: status.displayName,
      icon: _statusIcon(status),
      color: color,
    );
  }
}

class _PaymentStatusBadge extends StatelessWidget {
  final PaymentStatus status;
  const _PaymentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _paymentColor(status);

    return _MiniStateBadge(
      label: status.displayName,
      icon: _paymentIcon(status),
      color: color,
    );
  }
}

class _FulfillmentStatusBadge extends StatelessWidget {
  final FulfillmentStatus status;
  const _FulfillmentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _fulfillmentColor(status);

    return _MiniStateBadge(
      label: status.displayName,
      icon: _fulfillmentIcon(status),
      color: color,
    );
  }
}

class _MiniStateBadge extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final Color color;

  const _MiniStateBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

Color _paymentColor(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.unpaid:
      return const Color(0xFFEF5350);
    case PaymentStatus.partiallyPaid:
      return const Color(0xFFFFA726);
    case PaymentStatus.paid:
      return const Color(0xFF66BB6A);
  }
}

PhosphorIconData _paymentIcon(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.unpaid:
      return PhosphorIconsRegular.warningCircle;
    case PaymentStatus.partiallyPaid:
      return PhosphorIconsRegular.clockCountdown;
    case PaymentStatus.paid:
      return PhosphorIconsRegular.checkCircle;
  }
}

Color _fulfillmentColor(FulfillmentStatus status) {
  switch (status) {
    case FulfillmentStatus.unreleased:
      return const Color(0xFFFB8C00);
    case FulfillmentStatus.released:
      return const Color(0xFF00897B);
  }
}

PhosphorIconData _fulfillmentIcon(FulfillmentStatus status) {
  switch (status) {
    case FulfillmentStatus.unreleased:
      return PhosphorIconsRegular.package;
    case FulfillmentStatus.released:
      return PhosphorIconsRegular.package;
  }
}

Color _statusColor(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.pendingApproval:
      return const Color(0xFFFFA726);
    case InvoiceStatus.approved:
      return AppTokens.brandPrimary;
    case InvoiceStatus.rejected:
      return AppTokens.brandAccent;
    case InvoiceStatus.partiallyPaid:
      return const Color(0xFFFFA726);
    case InvoiceStatus.paid:
      return AppTokens.brandSecondary;
    case InvoiceStatus.completed:
      return const Color(0xFF66BB6A);
    case InvoiceStatus.voided:
      return const Color(0xFFEF5350);
  }
}

PhosphorIconData _statusIcon(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.pendingApproval:
      return PhosphorIconsRegular.clock;
    case InvoiceStatus.approved:
      return PhosphorIconsRegular.checkCircle;
    case InvoiceStatus.rejected:
      return PhosphorIconsRegular.xCircle;
    case InvoiceStatus.partiallyPaid:
      return PhosphorIconsRegular.percent;
    case InvoiceStatus.paid:
      return PhosphorIconsRegular.currencyCircleDollar;
    case InvoiceStatus.completed:
      return PhosphorIconsRegular.check;
    case InvoiceStatus.voided:
      return PhosphorIconsRegular.prohibit;
  }
}
