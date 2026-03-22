import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/presentation/batch_upload_screen.dart';
import 'package:zynk/core/widgets/app_drawer.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _searchQuery = '';
  String? _selectedCategoryId;

  void importCsv(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BatchUploadScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(allProductsProvider);
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final categories = categoriesAsync.value ?? [];

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
        title: const Text('Items'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Theme(
              data: theme.copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tooltip: 'Add options',
                onSelected: (value) {
                  if (value == 'csv') {
                    importCsv(context);
                  } else if (value == 'item') {
                    context.push('/products/add');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'item',
                    child: Row(
                      children: [
                        Icon(PhosphorIconsBold.plus, size: 20),
                        SizedBox(width: 12),
                        Text('Add item'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'csv',
                    child: Row(
                      children: [
                        Icon(PhosphorIconsDuotone.fileCsv, size: 20),
                        SizedBox(width: 12),
                        Text('Import CSV'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsBold.plus,
                        size: 18,
                        color: theme.colorScheme.onSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add',
                        style: TextStyle(
                          color: theme.colorScheme.onSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search item by name...',
                prefixIcon: const Icon(PhosphorIconsDuotone.magnifyingGlass),
                filled: true,
                fillColor: theme.colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.colorScheme.primary),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Category Filter Chips
          if (categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      showCheckmark: false,
                      label: const Text('All Categories'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) => setState(() => _selectedCategoryId = null),
                    ),
                  ),
                  ...categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        showCheckmark: false,
                        label: Text(cat.name),
                        selected: _selectedCategoryId == cat.id,
                        onSelected: (_) => setState(
                          () => _selectedCategoryId =
                              _selectedCategoryId == cat.id ? null : cat.id,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main Product Grid
          Expanded(
            child: productsAsync.when(
              data: (products) {
                // Filter out non-standard items — those have their own screens
                var filtered = products
                    .where((p) => p.productType == 'standard')
                    .toList();

                if (_selectedCategoryId != null) {
                  filtered = filtered
                      .where((p) => p.categoryId == _selectedCategoryId)
                      .toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
                      .toList();
                }

                if (filtered.isEmpty) {
                  return _buildEmptyState(theme);
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return _buildGridView(filtered, crossAxisCount: 4);
                    } else if (constraints.maxWidth > 600) {
                      return _buildGridView(filtered, crossAxisCount: 3);
                    } else {
                      return _buildGridView(filtered, crossAxisCount: 2);
                    }
                  },
                );
              },
              loading: () => _buildShimmer(theme),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
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
            child: Icon(
              PhosphorIconsDuotone.package,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'No Items Yet' : 'No Results Found',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Get started by adding your first product.'
                : 'Try adjusting your search or category filter.',
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/products/add'),
              icon: const Icon(PhosphorIconsBold.plus),
              label: const Text('Add Your First Item'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShimmer(ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildGridView(List<Product> products, {required int crossAxisCount}) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return _ProductGridCard(product: product);
      },
    );
  }
}

class _ProductGridCard extends ConsumerWidget {
  final Product product;

  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return RepaintBoundary(
      child: InkWell(
        onTap: () => context.push('/products/details', extra: product),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Square Image Area
            AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outlineVariant, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    product.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox.shrink(),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(PhosphorIconsDuotone.imageBroken, color: cs.onSurfaceVariant),
                            ),
                          )
                        : Center(
                            child: Icon(PhosphorIconsDuotone.package, size: 40, color: cs.outlineVariant),
                          ),
                    // Inventory Badge Overlay
                    if (!product.isService)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: ref.watch(stockProvider(product.id)).when(
                          data: (stock) {
                            final quantity = stock?.quantity ?? 0;
                            final isLowStock = quantity <= 5;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: isLowStock
                                    ? cs.errorContainer.withValues(alpha: 0.9)
                                    : cs.surface.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isLowStock ? PhosphorIconsFill.warningCircle : PhosphorIconsFill.circle,
                                    size: 10,
                                    color: isLowStock ? cs.error : cs.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isLowStock ? '$quantity Left' : 'Stocked',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isLowStock ? cs.onErrorContainer : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Name and Details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (product.variantOptions?.isNotEmpty == true) ...[  
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Has Variants',
                        style: theme.textTheme.labelSmall?.copyWith(color: cs.onSecondaryContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'KES ${product.basePrice.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
