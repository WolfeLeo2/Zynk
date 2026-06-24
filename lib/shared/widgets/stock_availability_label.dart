import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

/// Small live "in stock: N" indicator for an invoice/cart line item.
/// Hides itself for products with no stock row (e.g. services). Used on the
/// create and edit invoice screens.
class StockAvailabilityLabel extends ConsumerWidget {
  final String productId;
  final String? branchId;

  const StockAvailabilityLabel({
    super.key,
    required this.productId,
    required this.branchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final stock = ref
        .watch(
          stockByBranchProvider((productId: productId, branchId: branchId)),
        )
        .value;

    // No stock row → not stock-tracked (service). Show nothing.
    if (stock == null) return const SizedBox.shrink();

    final qty = stock.quantity;
    final reorder = stock.reorderLevel ?? 0;
    final color = qty <= 0
        ? cs.error
        : (qty <= reorder ? Colors.orange : cs.primary);
    final label = qty <= 0 ? 'Out of stock' : 'In stock: $qty';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          PhosphorIcon(PhosphorIconsDuotone.package, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
