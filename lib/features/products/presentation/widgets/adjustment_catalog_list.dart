import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/utils/quantity.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/widgets/inventory_adjustment_shimmers.dart';

/// Searchable catalog of stock-tracked products, always visible (POS-style).
/// Each row shows current stock for the selected branch(es); tapping (or its ＋)
/// adds it to the adjustment basket. Owns its own search state.
class AdjustmentCatalogList extends ConsumerStatefulWidget {
  final Set<String> selectedBranchIds;

  const AdjustmentCatalogList({super.key, required this.selectedBranchIds});

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
                itemBuilder: (context, index) => _CatalogTile(
                  product: filtered[index],
                  selectedBranchIds: widget.selectedBranchIds,
                ),
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

/// One catalog row. Watches the product's per-branch stock so it can show the
/// live total across the selected branches.
class _CatalogTile extends ConsumerWidget {
  final Product product;
  final Set<String> selectedBranchIds;

  const _CatalogTile({required this.product, required this.selectedBranchIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isAdded = ref.watch(
      batchStockProvider.select(
        (items) => items.any((i) => i.product.id == product.id),
      ),
    );
    final stockAsync = ref.watch(branchStocksProvider(product.id));
    final currentStock =
        stockAsync.value
            ?.where((s) => selectedBranchIds.contains(s.branchId))
            .fold<num>(0, (sum, s) => sum + s.quantity) ??
        0;

    return ListTile(
      leading: Container(
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
      title: Text(product.name),
      subtitle: Row(
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.stack,
            size: 13,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            'In stock: ${formatQty(currentStock)}',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (product.sku != null) ...[
            Text(
              '  ·  ${product.sku}',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      trailing: isAdded
          ? PhosphorIcon(
              PhosphorIconsRegular.checkCircle,
              color: colorScheme.primary,
            )
          : IconButton(
              onPressed: () =>
                  ref.read(batchStockProvider.notifier).addItem(product),
              icon: const PhosphorIcon(PhosphorIconsRegular.plus),
              style: IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
            ),
      onTap: isAdded
          ? null
          : () => ref.read(batchStockProvider.notifier).addItem(product),
    );
  }
}
