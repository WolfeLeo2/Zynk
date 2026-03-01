import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';

import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PosProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const PosProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final stockAsync = ref.watch(stockProvider(product.id));
    final currentStock = stockAsync.value?.quantity ?? 0;
    final isOutOfStock = !product.isService && currentStock <= 0;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product Image
            Expanded(flex: 3, child: _buildImage(colorScheme)),
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!product.isService) ...[
                      const SizedBox(height: 2),
                      stockAsync.when(
                        data: (stock) {
                          final qty = stock?.quantity ?? 0;
                          return Text(
                            qty > 0 ? '$qty in stock' : 'Out of stock',
                            style: textTheme.labelSmall?.copyWith(
                              color: qty > 0
                                  ? colorScheme.primary
                                  : colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                        loading: () => const SizedBox(
                          height: 12,
                          width: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (e, s) => const SizedBox(),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            'Ksh ${product.basePrice.toStringAsFixed(0)}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        // Quick Add Button
                        Material(
                          color: isOutOfStock
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: isOutOfStock ? null : onAddToCart,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: PhosphorIcon(
                                PhosphorIconsBold.plus,
                                size: 14,
                                color: isOutOfStock
                                    ? colorScheme.onSurface.withValues(
                                        alpha: 0.3,
                                      )
                                    : colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(ColorScheme colorScheme) {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: product.imageUrl!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        useOldImageOnUrlChange: true,
        placeholder: (context, url) => Container(
          color: colorScheme.surfaceContainerHighest,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _imagePlaceholder(colorScheme),
      );
    }
    return _imagePlaceholder(colorScheme);
  }

  Widget _imagePlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: PhosphorIcon(
          PhosphorIconsDuotone.package,
          size: 32,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
