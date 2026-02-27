import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/presentation/item_groups_view.dart';
import 'package:zynk/features/products/presentation/batch_upload_screen.dart';

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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Products'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'All Products'),
              Tab(text: 'Item Groups'),
            ],
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorSize: TabBarIndicatorSize.label,
            splashFactory: InkRipple.splashFactory,
          ),
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
                    } else if (value == 'product') {
                      context.push('/add-product');
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'product',
                      child: Row(
                        children: [
                          Icon(PhosphorIconsBold.plus, size: 20),
                          SizedBox(width: 12),
                          Text('Add Product'),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
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
                        const SizedBox(width: 4),
                        Icon(
                          PhosphorIconsBold.caretDown,
                          size: 16,
                          color: theme.colorScheme.onSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      body: Consumer(
        builder: (context, ref, child) {
          final productsAsync = ref.watch(allProductsProvider);
          final categoriesAsync = ref.watch(allCategoriesProvider);
          final categories = categoriesAsync.value ?? [];

          return TabBarView(
            children: [
              // Tab 1: All Products
              Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search products by name...',
                      prefixIcon: const Icon(
                        PhosphorIconsDuotone.magnifyingGlass,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
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
                              label: const Text('All Categories'),
                              selected: _selectedCategoryId == null,
                              onSelected: (_) => setState(() => _selectedCategoryId = null),
                            ),
                          ),
                          ...categories.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(cat.name),
                                selected: _selectedCategoryId == cat.id,
                                onSelected: (_) => setState(() => _selectedCategoryId = _selectedCategoryId == cat.id ? null : cat.id),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Main Content
                  Expanded(
                    child: productsAsync.when(
                      data: (products) {
                        var filtered = products.toList();
                        if (_selectedCategoryId != null) {
                          filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
                        }
                        if (_searchQuery.isNotEmpty) {
                          filtered = filtered.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                        }

                        if (filtered.isEmpty) {
                          return _buildEmptyState(theme);
                        }
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 800) {
                              // Desktop/Tablet Grid
                              return _buildGridView(filtered, crossAxisCount: 4);
                            } else if (constraints.maxWidth > 600) {
                              // Small Tablet Grid
                              return _buildGridView(filtered, crossAxisCount: 3);
                            } else {
                              // Mobile List
                              return _buildGridView(filtered, crossAxisCount: 2);
                            }
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, s) => Center(child: Text('Error: $e')),
                    ),
                  ),
                ],
              ),
            // Tab 2: Item Groups
            const ItemGroupsView(),
          ],
        );
      },
      )
      )
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
            _searchQuery.isEmpty ? 'No Products Yet' : 'No Results Found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Get started by adding your first product to the catalog.'
                : 'Try adjusting your search query.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/add-product'),
              icon: const Icon(PhosphorIconsBold.plus),
              label: const Text('Add Your First Product'),
            ),
          ],
        ],
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

class _ProductGridCard extends StatelessWidget {
  final Product product;

  const _ProductGridCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => context.push('/product-details', extra: product),
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
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Icon(
                              PhosphorIconsDuotone.imageBroken,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            PhosphorIconsDuotone.package,
                            size: 40,
                            color: cs.outlineVariant,
                          ),
                        ),
                  // Inventory Badge Overlay
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsFill.circle,
                            size: 8,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Stocked', // Future: Wire real stock logic here
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'KES ${product.basePrice.toStringAsFixed(0)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
