import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/features/dashboard/models/dashboard_models.dart';
import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'skeleton_widgets.dart';
import 'empty_error_states.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ORDERS LIST (MOBILE)
// ─────────────────────────────────────────────────────────────────────────────

class RecentOrdersList extends ConsumerWidget {
  const RecentOrdersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final salesAsync = ref.watch(recentSalesProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/sales'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          salesAsync.when(
            data: (sales) {
              if (sales.isEmpty) {
                return EmptyState(
                  colorScheme: colorScheme,
                  title: 'No orders yet',
                  message: 'Complete a sale in the POS to see orders here',
                  icon: PhosphorIconsDuotone.receipt,
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sales.take(5).length,
                itemBuilder: (context, index) {
                  final sale = sales[index];
                  return _SaleListItem(
                    sale: sale,
                    colorScheme: colorScheme,
                    index: index,
                  );
                },
              );
            },
            loading: () => Column(
              children: List.generate(
                3,
                (_) => SkeletonListItem(colorScheme: colorScheme),
              ),
            ),
            error: (error, stack) => ErrorState(
              colorScheme: colorScheme,
              message: 'Failed to load orders',
              onRetry: () => ref.invalidate(recentSalesProvider),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ORDERS TABLE (DESKTOP)
// ─────────────────────────────────────────────────────────────────────────────

class RecentOrdersTable extends ConsumerWidget {
  const RecentOrdersTable({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final salesAsync = ref.watch(recentSalesProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Orders',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => context.push('/sales'),
                    child: const Text('View All'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TableHeader(colorScheme: colorScheme),
          const SizedBox(height: 8),
          salesAsync.when(
            data: (sales) {
              if (sales.isEmpty) {
                return EmptyState(
                  colorScheme: colorScheme,
                  title: 'No orders yet',
                  message: 'Complete a sale in the POS to see orders here',
                  icon: PhosphorIconsDuotone.receipt,
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sales.length,
                itemBuilder: (context, index) {
                  return _SaleTableRow(
                    sale: sales[index],
                    index: index,
                    colorScheme: colorScheme,
                  );
                },
              );
            },
            loading: () => Column(
              children: List.generate(
                5,
                (_) => SkeletonListItem(colorScheme: colorScheme),
              ),
            ),
            error: (error, stack) => ErrorState(
              colorScheme: colorScheme,
              message: 'Failed to load orders',
              onRetry: () => ref.invalidate(recentSalesProvider),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final ColorScheme colorScheme;

  const _TableHeader({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final headerStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      color: colorScheme.onSurfaceVariant,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('INVOICE', style: headerStyle)),
          Expanded(flex: 2, child: Text('TYPE', style: headerStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: headerStyle)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('AMOUNT', style: headerStyle),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE LIST ITEM (MOBILE)
// ─────────────────────────────────────────────────────────────────────────────

class _SaleListItem extends StatelessWidget {
  final Sale sale;
  final ColorScheme colorScheme;
  final int index;

  const _SaleListItem({
    required this.sale,
    required this.colorScheme,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(sale.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/sales/${sale.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: PhosphorIcon(
                  _getStatusIcon(sale.status),
                  size: 20,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.invoiceNumber ?? sale.id.substring(0, 8),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${sale.saleType.toUpperCase()} • ${formatTimeAgo(sale.createdAt ?? DateTime.now())}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Ksh ${sale.grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(status: sale.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE TABLE ROW (DESKTOP)
// ─────────────────────────────────────────────────────────────────────────────

class _SaleTableRow extends StatelessWidget {
  final Sale sale;
  final int index;
  final ColorScheme colorScheme;

  const _SaleTableRow({
    required this.sale,
    required this.index,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/sales/${sale.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                sale.invoiceNumber ?? sale.id.substring(0, 8),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  PhosphorIcon(
                    sale.saleType == 'sale'
                        ? PhosphorIconsDuotone.shoppingBag
                        : PhosphorIconsDuotone.fileText,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sale.saleType[0].toUpperCase() + sale.saleType.substring(1),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: _StatusBadge(status: sale.status)),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Ksh ${sale.grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    final color = _getStatusColor(status);
    final bgColor = color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Color _getStatusColor(InvoiceStatus status) {
  return switch (status) {
    InvoiceStatus.completed => Colors.green,
    InvoiceStatus.paid => Colors.green.shade700,
    InvoiceStatus.approved => Colors.blue,
    InvoiceStatus.pendingApproval => Colors.orange,
    InvoiceStatus.partiallyPaid => Colors.amber,
    InvoiceStatus.rejected => Colors.red,
    InvoiceStatus.voided => Colors.red.shade900,
  };
}

IconData _getStatusIcon(InvoiceStatus status) {
  return switch (status) {
    InvoiceStatus.completed => PhosphorIconsDuotone.checkCircle,
    InvoiceStatus.paid => PhosphorIconsDuotone.checkCircle,
    InvoiceStatus.approved => PhosphorIconsDuotone.thumbsUp,
    InvoiceStatus.pendingApproval => PhosphorIconsDuotone.clock,
    InvoiceStatus.partiallyPaid => PhosphorIconsDuotone.clockCountdown,
    InvoiceStatus.rejected => PhosphorIconsDuotone.xCircle,
    InvoiceStatus.voided => PhosphorIconsDuotone.prohibit,
  };
}
