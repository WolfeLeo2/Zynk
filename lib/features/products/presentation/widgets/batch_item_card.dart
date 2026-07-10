import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynk/core/utils/quantity.dart';
import 'package:zynk/features/products/domain/stock_adjustment_math.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

/// Colour for a stock delta: error for a decrease, green for an increase,
/// neutral for no change. Shared by every stock-adjustment surface so the
/// one hardcoded green lives in a single place.
// ponytail: green is a raw Material colour because the app theme has no
// "success" token; promote to a ThemeExtension if more surfaces need it.
Color stockDeltaColor(ColorScheme cs, num delta) {
  if (delta < 0) return cs.error;
  if (delta > 0) return Colors.green;
  return cs.onSurface;
}

/// One editable row in the adjustment basket: shows current → new stock for
/// the selected branches and lets the user type/step the quantity.
class BatchItemCard extends ConsumerStatefulWidget {
  final BatchItemState item;
  final Set<String> selectedBranchIds;
  final String mode; // 'add' | 'subtract' | 'set'

  const BatchItemCard({
    super.key,
    required this.item,
    required this.selectedBranchIds,
    required this.mode,
  });

  @override
  ConsumerState<BatchItemCard> createState() => _BatchItemCardState();
}

class _BatchItemCardState extends ConsumerState<BatchItemCard> {
  late TextEditingController _notesController;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes);
    _qtyController = TextEditingController(
      text: widget.item.quantityChange == 0
          ? ''
          : formatQtyInput(widget.item.quantityChange),
    );
  }

  @override
  void didUpdateWidget(BatchItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantityChange != widget.item.quantityChange) {
      final formatted = formatQtyInput(widget.item.quantityChange);
      if (_qtyController.text != formatted &&
          widget.item.quantityChange != 0) {
        _qtyController.text = formatted;
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _updateQuantity(String val) {
    // Allow empty field (treat as 0) and fractional/negative numbers.
    final qty = num.tryParse(val) ?? 0;
    ref
        .read(batchStockProvider.notifier)
        .updateQuantity(widget.item.product.id, qty);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final product = widget.item.product;
    final branchStocksAsync = ref.watch(branchStocksProvider(product.id));

    final currentStock =
        branchStocksAsync.value
            ?.where((s) => widget.selectedBranchIds.contains(s.branchId))
            .fold<num>(0, (sum, s) => sum + s.quantity) ??
        0;

    final newStock = resolveStockTarget(
      widget.mode,
      currentStock,
      widget.item.quantityChange,
    );
    final delta = newStock - currentStock;
    final deltaColor = stockDeltaColor(colorScheme, delta);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  image: product.imageUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(product.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imageUrl == null
                    ? PhosphorIcon(
                        PhosphorIconsRegular.package,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (product.sku != null)
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(batchStockProvider.notifier).removeItem(product.id);
                },
                icon: const PhosphorIcon(PhosphorIconsRegular.x),
                color: colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Stock: ${formatQty(currentStock)}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    PhosphorIcon(
                      PhosphorIconsRegular.arrowRight,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      'New Stock: ${formatQty(newStock)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: deltaColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyController,
                keyboardType: TextInputType.numberWithOptions(
                  signed: widget.mode != 'set',
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^-?\d*\.?\d*'),
                  ),
                ],
                style: TextStyle(
                  color: delta == 0 ? null : deltaColor,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: widget.mode == 'set' ? 'New Quantity' : 'Amount',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: _updateQuantity,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Item notes (optional)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (val) {
                  ref
                      .read(batchStockProvider.notifier)
                      .updateNotes(product.id, val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
