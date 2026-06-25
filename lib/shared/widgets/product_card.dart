import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';

import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/core/services/product_pricing_service.dart';
import 'package:zynk/core/utils/currency.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SharedProductCard extends ConsumerWidget {
  final Product product;
  final VoidCallback onTap;
  final bool showCartBadges;
  final String? overrideBranchId;

  const SharedProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showCartBadges = false,
    this.overrideBranchId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Use override branch ID (e.g. pos branch) or fallback to global current branch.
    final branchId = overrideBranchId ?? ref.watch(currentBranchIdProvider);

    final stockAsync = ref.watch(
      stockByBranchProvider((productId: product.id, branchId: branchId)),
    );
    final currentStock = stockAsync.value?.quantity ?? 0;
    final isOutOfStock = !product.isService && currentStock <= 0;

    // Cart details (only if requested)
    bool isInCart = false;
    int qtyInCart = 0;

    if (showCartBadges) {
      final cartItems = ref
          .watch(cartProvider)
          .items
          .where((i) => i.product.id == product.id)
          .toList();
      isInCart = cartItems.isNotEmpty;
      qtyInCart = cartItems.fold<int>(0, (sum, i) => sum + i.quantity);
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: isInCart
          ? RoundedRectangleBorder(
              borderRadius: AppTokens.roundedCard,
              side: BorderSide(color: colorScheme.primary, width: 0.5),
            )
          : null,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: AppTokens.roundedCard,
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
                            final isLowStock = qty <= 5;
                            return Row(
                              children: [
                                PhosphorIcon(
                                  isLowStock
                                      ? PhosphorIconsFill.warningCircle
                                      : PhosphorIconsFill.circle,
                                  size: 10,
                                  color: isLowStock
                                      ? colorScheme.error
                                      : colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    qty > 0 ? '$qty in stock' : 'Out of stock',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: isLowStock
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: isLowStock
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
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
                                    .watch(
                                      itemGroupProvider(product.itemGroupId!),
                                    )
                                    .value
                              : null;
                          final pricingService = ref.watch(
                            productPricingServiceProvider,
                          );
                          final resolvedPrice = pricingService
                              .resolveSellingPrice(product, group);
                          final isSqm =
                              pricingService.resolvePricingUnit(
                                product,
                                group,
                              ) ==
                              'sqm';
                          return Text(
                            isSqm
                                ? '${CurrencyHelper.format(resolvedPrice)}/sqm'
                                : CurrencyHelper.format(resolvedPrice),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: colorScheme.primary,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (showCartBadges && isInCart)
              Positioned(
                top: 12,
                right: 12,
                child: Badge(
                  label: Text(
                    '$qtyInCart',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: colorScheme.primary,
                  largeSize: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
