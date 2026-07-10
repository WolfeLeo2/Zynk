import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:m3e_card_list/m3e_card_list.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';
import 'package:zynk/core/utils/currency.dart';
import 'package:zynk/core/utils/quantity.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          IconButton(
            onPressed: () => context.push('/products/add', extra: product),
            icon: const PhosphorIcon(PhosphorIconsDuotone.pencilSimple),
            tooltip: 'Edit Item',
          ),
          IconButton(
            onPressed: () => context.push(
              '/products/add',
              extra: {'product': product, 'clone': true},
            ),
            icon: const PhosphorIcon(PhosphorIconsDuotone.copy),
            tooltip: 'Clone Item',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 64x64 rounded thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: product.imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: product.imageUrl!,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    _buildImagePlaceholder(colorScheme),
                                errorWidget: (context, url, error) =>
                                    _buildImagePlaceholder(colorScheme),
                              )
                            : _buildImagePlaceholder(colorScheme),
                      ),
                      const SizedBox(width: 16),
                      // Name + SKU + Barcode
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  label: Text(product.sku ?? 'NO-SKU'),
                                  labelStyle: theme.textTheme.labelSmall
                                      ?.copyWith(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                if (product.isService)
                                  Chip(
                                    label: const Text('Service'),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor:
                                        colorScheme.tertiaryContainer,
                                  ),
                              ],
                            ),
                            if (product.barcode != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  PhosphorIcon(
                                    PhosphorIconsDuotone.barcode,
                                    size: 16,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    product.barcode!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Description
                  if (product.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      product.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                child: Text(
                  'Classification',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              M3ECardList(
                itemCount: 2,
                color: colorScheme.surfaceContainerLow,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Consumer(
                      builder: (context, ref, child) {
                        final categories =
                            ref.watch(allCategoriesProvider).value ?? [];
                        final categoryName =
                            categories
                                .where((c) => c.id == product.categoryId)
                                .map((c) => c.name)
                                .firstOrNull ??
                            'No Category';
                        return ListTile(
                          leading: PhosphorIcon(
                            PhosphorIconsRegular.folder,
                            color: colorScheme.primary,
                          ),
                          title: const Text('Category'),
                          subtitle: Text(categoryName),
                        );
                      },
                    );
                  } else {
                    return Consumer(
                      builder: (context, ref, child) {
                        final groups =
                            ref.watch(allItemGroupsProvider).value ?? [];
                        final groupName =
                            groups
                                .where((g) => g.id == product.itemGroupId)
                                .map((g) => g.name)
                                .firstOrNull ??
                            'No Group';
                        return ListTile(
                          leading: PhosphorIcon(
                            PhosphorIconsRegular.package,
                            color: colorScheme.primary,
                          ),
                          title: const Text('Item Group'),
                          subtitle: Text(groupName),
                        );
                      },
                    );
                  }
                },
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                child: Text(
                  'Pricing',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              M3ECardList(
                itemCount: 2,
                color: colorScheme.surfaceContainerLow,
                itemBuilder: (context, index) {
                  return Consumer(
                    builder: (context, ref, child) {
                      final group = product.itemGroupId != null
                          ? ref
                                .watch(itemGroupProvider(product.itemGroupId!))
                                .value
                          : null;
                      final pricingService = ref.watch(
                        productPricingServiceProvider,
                      );

                      final isCost = index == 0;
                      final price = isCost
                          ? pricingService.resolveBuyingPrice(product, group)
                          : pricingService.resolveSellingPrice(product, group);

                      final priceFormatted = price > 0
                          ? CurrencyHelper.format(price)
                          : 'Not Set';
                      final label = isCost ? 'Cost Price' : 'Selling Price';

                      return Row(
                        children: [
                          PhosphorIcon(
                            isCost
                                ? PhosphorIconsDuotone.money
                                : PhosphorIconsDuotone.tag,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 16),
                          Text(
                            priceFormatted,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isCost
                                  ? colorScheme.onSurfaceVariant
                                  : colorScheme.secondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          if (!product.isService) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                  child: Text(
                    'Inventory',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                M3ECardList(
                  itemCount: 1,
                  color: colorScheme.surfaceContainerLow,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    return Consumer(
                      builder: (context, ref, child) {
                        final stockAsync = ref.watch(stockProvider(product.id));
                        return stockAsync.when(
                          data: (stock) {
                            final qty = stock?.quantity ?? 0;
                            return ListTile(
                              leading: PhosphorIcon(
                                PhosphorIconsDuotone.stack,
                                color: colorScheme.primary,
                              ),
                              title: const Text('Total Stock'),
                              trailing: Text(
                                formatQty(qty),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: qty <= 5
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: qty <= 5
                                      ? colorScheme.error
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          },
                          loading: () => ListTile(
                            leading: PhosphorIcon(
                              PhosphorIconsDuotone.stack,
                              color: colorScheme.primary,
                            ),
                            title: const Text('Total Stock'),
                            trailing: Shimmer.fromColors(
                              baseColor: colorScheme.surfaceContainerHighest,
                              highlightColor: colorScheme.surface,
                              child: Container(
                                width: 48,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          error: (e, st) => ListTile(
                            leading: PhosphorIcon(
                              PhosphorIconsDuotone.stack,
                              color: colorScheme.error,
                            ),
                            title: const Text('Total Stock'),
                            trailing: Text(
                              'Error',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            Consumer(
              builder: (context, ref, _) {
                final branchesAsync = ref.watch(allTenantBranchesProvider);
                final branchStocksAsync = ref.watch(
                  branchStocksProvider(product.id),
                );

                return branchesAsync.when(
                  data: (branches) {
                    final realBranches = branches
                        .where((b) => b.id != 'all')
                        .toList();
                    if (realBranches.isEmpty) return const SizedBox.shrink();

                    return branchStocksAsync.when(
                      data: (stocks) {
                        final qtyByBranch = <String, num>{};
                        for (final stock in stocks) {
                          final prev = qtyByBranch[stock.branchId] ?? 0;
                          qtyByBranch[stock.branchId] = prev + stock.quantity;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                              child: Text(
                                'Stock by Branch',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            M3ECardList(
                              itemCount: realBranches.length,
                              color: colorScheme.surfaceContainerLow,
                              padding: EdgeInsets.zero,
                              itemBuilder: (context, i) {
                                final branch = realBranches[i];
                                final qty = qtyByBranch[branch.id] ?? 0;
                                return ListTile(
                                  leading: PhosphorIcon(
                                    PhosphorIconsDuotone.storefront,
                                    color: colorScheme.primary,
                                  ),
                                  title: Text(branch.name),
                                  trailing: Text(
                                    formatQty(qty),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: qty <= 5
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: qty <= 5
                                          ? colorScheme.error
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                      loading: () =>
                          _buildBranchStockShimmer(theme, colorScheme),
                      error: (e, st) => Card(
                        child: ListTile(
                          leading: PhosphorIcon(
                            PhosphorIconsDuotone.warning,
                            color: colorScheme.error,
                          ),
                          title: const Text('Failed to load branch stock'),
                        ),
                      ),
                    );
                  },
                  loading: () => _buildBranchStockShimmer(theme, colorScheme),
                  error: (e, st) => const SizedBox.shrink(),
                );
              },
            ),
          ],
          if (!product.isService)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Activity',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push(
                          '/products/details/history',
                          extra: {
                            'productId': product.id,
                            'productName': product.name,
                          },
                        ),
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final historyAsync = ref.watch(
                      productTransactionHistoryProvider(product.id),
                    );
                    return historyAsync.when(
                      data: (history) {
                        if (history.isEmpty) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  children: [
                                    PhosphorIcon(
                                      PhosphorIconsDuotone
                                          .clockCounterClockwise,
                                      size: 32,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No activity yet',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        final visible = history.length > 5
                            ? history.sublist(0, 5)
                            : history;
                        return M3ECardList(
                          itemCount: visible.length,
                          padding: EdgeInsets.zero,
                          color: colorScheme.surfaceContainerLow,
                          itemBuilder: (context, i) => _buildTransactionTile(
                            theme,
                            colorScheme,
                            visible[i],
                            context,
                          ),
                        );
                      },
                      loading: () =>
                          _buildTransactionShimmer(theme, colorScheme),
                      error: (e, st) => Card(
                        child: ListTile(
                          leading: PhosphorIcon(
                            PhosphorIconsDuotone.warning,
                            color: colorScheme.error,
                          ),
                          title: Text('Failed to load history: $e'),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(ColorScheme colorScheme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: PhosphorIcon(
          PhosphorIconsDuotone.package,
          size: 28,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildBranchStockShimmer(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Text(
            'Stock by Branch',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (int i = 0; i < 3; i++)
          Card(
            child: ListTile(
              leading: PhosphorIcon(
                PhosphorIconsDuotone.storefront,
                color: colorScheme.primary,
              ),
              title: Shimmer.fromColors(
                baseColor: colorScheme.surfaceContainerHighest,
                highlightColor: colorScheme.surface,
                child: Container(
                  width: 100,
                  height: 16,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              trailing: Shimmer.fromColors(
                baseColor: colorScheme.surfaceContainerHighest,
                highlightColor: colorScheme.surface,
                child: Container(
                  width: 48,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionTile(
    ThemeData theme,
    ColorScheme colorScheme,
    ProductTransaction tx,
    BuildContext context,
  ) {
    final isPositive = tx.quantityChange > 0;
    final isSale = tx.type == 'sale';

    return ListTile(
      onTap: isSale && tx.referenceId != null
          ? () => context.push('/sales/${tx.referenceId}')
          : null,
      leading: CircleAvatar(
        backgroundColor: isSale
            ? colorScheme.primaryContainer
            : (isPositive
                  ? colorScheme.tertiaryContainer
                  : colorScheme.errorContainer),
        child: PhosphorIcon(
          isSale
              ? PhosphorIconsDuotone.receipt
              : (isPositive
                    ? PhosphorIconsDuotone.trendUp
                    : PhosphorIconsDuotone.trendDown),
          color: isSale
              ? colorScheme.onPrimaryContainer
              : (isPositive
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.onErrorContainer),
        ),
      ),
      title: Text(tx.referenceNumber ?? (isSale ? 'Sale' : 'Adjustment')),
      subtitle: Text(
        '${tx.actorName ?? 'Unknown'} · ${tx.createdAt != null ? DateFormat('MMM d, y HH:mm').format(tx.createdAt!) : ''}',
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}${formatQty(tx.quantityChange)}',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isPositive ? colorScheme.tertiary : colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildTransactionShimmer(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      child: Column(
        children: List.generate(
          3,
          (i) => ListTile(
            leading: Shimmer.fromColors(
              baseColor: colorScheme.surfaceContainerHighest,
              highlightColor: colorScheme.surface,
              child: const CircleAvatar(),
            ),
            title: Shimmer.fromColors(
              baseColor: colorScheme.surfaceContainerHighest,
              highlightColor: colorScheme.surface,
              child: Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            subtitle: Shimmer.fromColors(
              baseColor: colorScheme.surfaceContainerHighest,
              highlightColor: colorScheme.surface,
              child: Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            trailing: Shimmer.fromColors(
              baseColor: colorScheme.surfaceContainerHighest,
              highlightColor: colorScheme.surface,
              child: Container(
                width: 40,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
