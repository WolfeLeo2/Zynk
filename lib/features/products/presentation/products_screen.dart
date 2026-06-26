import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/features/products/presentation/batch_upload_screen.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/shared/widgets/product_card.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  final String? initialGroupId;

  const ProductsScreen({super.key, this.initialGroupId});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String _searchQuery = '';
  String? _selectedCategoryId;
  String? _filterGroupId;

  @override
  void initState() {
    super.initState();
    _filterGroupId = widget.initialGroupId;
  }

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
        title: const Text('Products'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search item by name...',
                prefixIcon: const PhosphorIcon(
                  PhosphorIconsRegular.magnifyingGlass,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Category Filter Chips
          if (categories.isNotEmpty || _filterGroupId != null)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  if (_filterGroupId != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        showCheckmark: true,
                        label: const Text('Filtered by Group'),
                        selected: true,
                        onSelected: (_) =>
                            setState(() => _filterGroupId = null),
                        selectedColor: theme.colorScheme.primaryContainer,
                        checkmarkColor: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      showCheckmark: false,
                      label: const Text('All Categories'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) =>
                          setState(() => _selectedCategoryId = null),
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
                var filtered = products.toList();

                if (_selectedCategoryId != null) {
                  filtered = filtered
                      .where((p) => p.categoryId == _selectedCategoryId)
                      .toList();
                }
                if (_filterGroupId != null) {
                  filtered = filtered
                      .where((p) => p.itemGroupId == _filterGroupId)
                      .toList();
                }
                if (_searchQuery.isNotEmpty) {
                  filtered = filtered
                      .where(
                        (p) => p.name.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
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
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        label: const Text('Add item'),
        spacing: 3,
        childPadding: const EdgeInsets.all(5),
        spaceBetweenChildren: 4,
        tooltip: 'Add Item',
        heroTag: 'add-item-speed-dial',
        elevation: 3.0, // Standard M3 FAB elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Standard M3 FAB shape
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        children: [
          SpeedDialChild(
            child: const PhosphorIcon(PhosphorIconsBold.plus),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            label: 'Add item',
            onTap: () => context.push('/products/add'),
          ),
          SpeedDialChild(
            child: const PhosphorIcon(PhosphorIconsDuotone.fileCsv),
            backgroundColor: theme.colorScheme.secondaryContainer,
            foregroundColor: theme.colorScheme.onSecondaryContainer,
            label: 'Import CSV',
            onTap: () => importCsv(context),
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
            child: PhosphorIcon(
              PhosphorIconsDuotone.package,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'No Items Yet' : 'No Results Found',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Get started by adding your first product.'
                : 'Try adjusting your search or category filter.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/products/add'),
              icon: const PhosphorIcon(PhosphorIconsBold.plus),
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
    return SharedProductCard(
      product: product,
      onTap: () => context.push('/products/details', extra: product),
      showCartBadges: false,
    );
  }
}
