import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zynk/core/widgets/app_drawer.dart';

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
                                  s.status != InvoiceStatus.completed &&
                                  s.paymentStatus != PaymentStatus.paid,
                            )
                            .toList()
                        : _filter is InvoiceStatus
                            ? branchFiltered
                                .where((s) => s.status == _filter)
                                .toList()
                            : _filter is PaymentStatus
                                ? branchFiltered
                                    .where((s) => s.paymentStatus == _filter)
                                    .toList()
                                : _filter is FulfillmentStatus
                                    ? branchFiltered
                                        .where((s) =>
                                            s.fulfillmentStatus == _filter)
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
      // FAB for creating invoices (permission-gated)
      floatingActionButton:
          ref.watch(hasPermissionProvider(Permission.createInvoices))
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/sales/create-invoice'),
              icon: const PhosphorIcon(PhosphorIconsBold.fileText, size: 20),
              label: const Text('Create Invoice'),
            )
          : null,
    );
  }

  Widget _buildFilterBar(ThemeData theme, ColorScheme cs) {
    // null = All, String = special, ENUM = exact match
    final filters = [
      (null, 'All', PhosphorIconsRegular.listBullets),
      ('outstanding', 'Outstanding', PhosphorIconsRegular.warningCircle),
      (InvoiceStatus.draft, 'Drafts', PhosphorIconsRegular.pencilSimple),
      (InvoiceStatus.pendingApproval, 'Pending Approval', PhosphorIconsRegular.clock),
      (InvoiceStatus.approved, 'Approved', PhosphorIconsRegular.sealCheck),
      (PaymentStatus.unpaid, 'Unpaid', PhosphorIconsRegular.money),
      (PaymentStatus.partiallyPaid, 'Partial', PhosphorIconsRegular.percent),
      (PaymentStatus.paid, 'Paid', PhosphorIconsRegular.currencyCircleDollar),
      (InvoiceStatus.completed, 'Completed', PhosphorIconsRegular.checkCircle),
      (InvoiceStatus.voided, 'Voided', PhosphorIconsRegular.prohibit),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Branch filter (only visible when "All Branches" is selected)
        Consumer(
          builder: (context, ref, _) {
            final branchesAsync = ref.watch(branchesProvider);
            final currentBranch = ref.watch(currentBranchIdProvider);
            final isAllBranches =
                currentBranch == null || currentBranch == 'all';

            if (!isAllBranches) return const SizedBox.shrink();

            return branchesAsync.when(
              data: (branches) {
                if (branches.length <= 1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIconsRegular.storefront,
                        size: 16,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _branchChip(theme, cs, null, 'All Branches'),
                              ...branches.map(
                                (b) => _branchChip(theme, cs, b.id, b.name),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            );
          },
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

  Widget _branchChip(
    ThemeData theme,
    ColorScheme cs,
    String? branchId,
    String label,
  ) {
    final isActive = _branchFilter == branchId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: isActive,
        showCheckmark: false,
        label: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? cs.onSecondary : cs.onSurface,
            fontSize: 12,
          ),
        ),
        selectedColor: cs.secondary,
        side: BorderSide(
          color: isActive ? cs.secondary : cs.outline.withValues(alpha: 0.2),
        ),
        onSelected: (_) => setState(() => _branchFilter = branchId),
      ),
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
            'Complete a POS sale or create an invoice',
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

class _SaleCard extends StatelessWidget {
  final Sale sale;
  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type label: Receipt or Invoice
                  Text(
                    sale.saleType == 'pos_sale' ? 'Receipt' : 'Invoice',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: sale.saleType == 'pos_sale'
                          ? cs.onSurfaceVariant
                          : cs.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sale.invoiceNumber ?? '#—',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: sale.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(sale.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

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
                if (sale.status == InvoiceStatus.partiallyPaid)
                  Text(
                    'Paid: ${sale.amountPaid.toStringAsFixed(0)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFFFA726),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
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

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final InvoiceStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _statusColor(status),
        ),
      ),
    );
  }
}

Color _statusColor(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return AppTokens.textMutedDark;
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

IconData _statusIcon(InvoiceStatus status) {
  switch (status) {
    case InvoiceStatus.draft:
      return PhosphorIconsRegular.pencilLine;
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
