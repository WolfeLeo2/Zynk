import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';
import 'package:zynk/core/widgets/app_drawer.dart';

class CompositeItemsScreen extends ConsumerWidget {
  const CompositeItemsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final compositeAsync = ref.watch(compositeProductsProvider);

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
        title: const Text('Composite Items'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => context.push('/products/composite/add'),
              icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 18),
              label: const Text('Add Composite'),
            ),
          ),
        ],
      ),
      body: compositeAsync.when(
        data: (products) {
          if (products.isEmpty) {
            return _buildEmptyState(context, theme);
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return _buildGrid(products, crossAxisCount: 3);
              } else if (constraints.maxWidth > 600) {
                return _buildGrid(products, crossAxisCount: 2);
              }
              return _buildList(products, theme);
            },
          );
        },
        loading: () => _buildShimmer(theme),
        error: (e, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(PhosphorIconsDuotone.warning, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load composite items', style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(PhosphorIconsDuotone.stack, size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            'No Composite Items Yet',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Composite items are assemblies or kit bundles\nbuilt from two or more components.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/products/composite/add'),
            icon: const PhosphorIcon(PhosphorIconsBold.plus),
            label: const Text('Create Composite Item'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<Product> products, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (context, index) => _CompositeItemCard(product: products[index]),
    );
  }

  Widget _buildGrid(List<Product> products, {required int crossAxisCount}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: 104,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => _CompositeItemCard(product: products[index]),
    );
  }

  Widget _buildShimmer(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _CompositeItemCard extends ConsumerWidget {
  final Product product;

  const _CompositeItemCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: InkWell(
          onTap: () => context.push('/products/composite/${product.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const SizedBox.shrink(),
                          errorWidget: (context, url, err) => PhosphorIcon(PhosphorIconsDuotone.imageBroken, color: cs.onSurfaceVariant),
                        )
                      : PhosphorIcon(PhosphorIconsDuotone.stack, size: 28, color: cs.outlineVariant),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _TypeBadge(
                            label: 'Composite',
                            icon: PhosphorIconsDuotone.package,
                            color: cs.secondaryContainer,
                            textColor: cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Consumer(
                            builder: (context, ref, child) {
                              final group = product.itemGroupId != null
                                  ? ref.watch(itemGroupProvider(product.itemGroupId!)).value
                                  : null;
                              final resolvedPrice = ref
                                  .watch(productPricingServiceProvider)
                                  .resolveSellingPrice(product, group);
                              return Text(
                                'KES ${resolvedPrice.toStringAsFixed(0)}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const PhosphorIcon(PhosphorIconsRegular.caretRight, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final Color color;
  final Color textColor;

  const _TypeBadge({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
