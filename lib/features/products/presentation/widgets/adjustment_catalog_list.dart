import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/widgets/inventory_adjustment_shimmers.dart';

/// Searchable catalog of stock-tracked products. Tapping a row (or its ＋)
/// adds it to the adjustment basket; already-added rows show a check.
/// Owns its own search state so the host screen stays lean.
class AdjustmentCatalogList extends ConsumerStatefulWidget {
  const AdjustmentCatalogList({super.key});

  @override
  ConsumerState<AdjustmentCatalogList> createState() =>
      _AdjustmentCatalogListState();
}

class _AdjustmentCatalogListState extends ConsumerState<AdjustmentCatalogList> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final productsAsync = ref.watch(allProductsProvider);
    final batchItems = ref.watch(batchStockProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search items by name or SKU...',
            leading: const PhosphorIcon(PhosphorIconsRegular.magnifyingGlass),
            onChanged: (val) => setState(() => _query = val),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16),
            ),
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStatePropertyAll(
              colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        Expanded(
          child: productsAsync.when(
            data: (products) {
              final q = _query.toLowerCase();
              final filtered = products.where((p) {
                if (p.isService) return false; // physical goods only
                if (q.isEmpty) return true;
                return p.name.toLowerCase().contains(q) ||
                    (p.sku?.toLowerCase().contains(q) ?? false);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('No items found'));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final isAdded = batchItems.any(
                    (item) => item.product.id == product.id,
                  );

                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                        image: product.imageUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(
                                  product.imageUrl!,
                                ),
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
                    title: Text(product.name),
                    subtitle: Text(
                      product.sku ?? 'No SKU',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    trailing: isAdded
                        ? PhosphorIcon(
                            PhosphorIconsRegular.checkCircle,
                            color: colorScheme.primary,
                          )
                        : IconButton(
                            onPressed: () => ref
                                .read(batchStockProvider.notifier)
                                .addItem(product),
                            icon: const PhosphorIcon(PhosphorIconsRegular.plus),
                            style: IconButton.styleFrom(
                              backgroundColor: colorScheme.primaryContainer,
                              foregroundColor: colorScheme.onPrimaryContainer,
                            ),
                          ),
                    onTap: isAdded
                        ? null
                        : () => ref
                              .read(batchStockProvider.notifier)
                              .addItem(product),
                  );
                },
              );
            },
            loading: () => const InventoryItemsShimmer(),
            error: (err, stack) =>
                Center(child: Text('Error loading items: $err')),
          ),
        ),
      ],
    );
  }
}
