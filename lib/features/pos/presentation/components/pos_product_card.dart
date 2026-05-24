import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';

import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/pos/providers/pos_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';
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

    final posBranchId = ref.watch(posBranchProvider);
    final stockAsync = ref.watch(stockByBranchProvider((
      productId: product.id,
      branchId: posBranchId,
    )));
    final currentStock = stockAsync.value?.quantity ?? 0;
    final isOutOfStock = !product.isService && currentStock <= 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Image
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildImage(colorScheme),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            fontSize: 15,
                          ),
                          maxLines: 1,
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
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            },
                            loading: () => const SizedBox(height: 12),
                            error: (e, s) => const SizedBox(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Consumer(
                          builder: (context, ref, child) {
                            final group = product.itemGroupId != null
                                ? ref
                                    .watch(itemGroupProvider(product.itemGroupId!))
                                    .value
                                : null;
                            final pricingService = ref.watch(productPricingServiceProvider);
                            final resolvedPrice = pricingService.resolveSellingPrice(product, group);
                            final isSqm = pricingService.resolvePricingUnit(product, group) == 'sqm';
                            return Text(
                              isSqm
                                  ? 'Ksh ${resolvedPrice.toStringAsFixed(0)}/sqm'
                                  : 'Ksh ${resolvedPrice.toStringAsFixed(0)}',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Floating Plus Button at Bottom Right
              Positioned(
                bottom: 12,
                right: 12,
                child: Material(
                  color: isOutOfStock
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surface,
                  shape: const CircleBorder(),
                  elevation: isOutOfStock ? 0 : 2,
                  shadowColor: Colors.black26,
                  child: InkWell(
                    onTap: isOutOfStock ? null : onAddToCart,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? colorScheme.surfaceContainerHighest
                            : colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIconsBold.plus,
                          size: 18,
                          color: isOutOfStock
                              ? colorScheme.onPrimaryContainer.withValues(
                                  alpha: 0.3,
                                )
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
