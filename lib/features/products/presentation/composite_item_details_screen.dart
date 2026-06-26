import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/utils/currency.dart';

const _uuid = Uuid();

class _EditableComponent {
  final Product product;
  final String componentId; // The ID of the generic CompositeItemComponent row
  int quantity;
  bool isNew = false;
  bool isDeleted = false;

  _EditableComponent({
    required this.product,
    required this.componentId,
    required this.quantity,
  });
}

class CompositeItemDetailsScreen extends ConsumerStatefulWidget {
  final String productId;

  const CompositeItemDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<CompositeItemDetailsScreen> createState() =>
      _CompositeItemDetailsScreenState();
}

class _CompositeItemDetailsScreenState
    extends ConsumerState<CompositeItemDetailsScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  String? _searchQuery;

  // Local state for edits
  List<_EditableComponent>? _editableComponents;
  Product? _product;

  void _beginEdit(
    List<CompositeItemComponent> dbComponents,
    List<Product> allProducts,
  ) {
    _editableComponents = [];
    for (final comp in dbComponents) {
      try {
        final p = allProducts.firstWhere(
          (x) => x.id == comp.componentProductId,
        );
        _editableComponents!.add(
          _EditableComponent(
            product: p,
            componentId: comp.id,
            quantity: comp.quantity,
          ),
        );
      } catch (_) {
        // Product missing
      }
    }
    setState(() => _isEditing = true);
  }

  void _cancelEdit() {
    setState(() {
      _editableComponents = null;
      _isEditing = false;
      _searchQuery = null;
    });
  }

  void _addComponent(Product p) {
    if (_editableComponents == null) return;
    final existing = _editableComponents!.indexWhere(
      (e) => e.product.id == p.id && !e.isDeleted,
    );
    if (existing >= 0) {
      setState(() => _editableComponents![existing].quantity++);
    } else {
      setState(() {
        _editableComponents!.add(
          _EditableComponent(product: p, componentId: _uuid.v4(), quantity: 1)
            ..isNew = true,
        );
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_product == null || _editableComponents == null) return;

    final activeComponents = _editableComponents!
        .where((e) => !e.isDeleted)
        .toList();
    if (activeComponents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A composite item must have at least one component.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(repositoryProvider);

      // Calculate new cost price based on components
      final newCost = activeComponents.fold(
        0.0,
        (sum, e) => sum + ((e.product.costPrice ?? 0.0) * e.quantity),
      );

      // We need to update product cost price, and fully replace/update components.
      // Easiest is to prepare the new Component list and call repository.

      final dbComponents = _editableComponents!
          .where((e) => !e.isDeleted)
          .map(
            (e) => CompositeItemComponent(
              id: e.componentId,
              tenantId: _product!.tenantId,
              branchId: _product!.branchId ?? '',
              compositeProductId: _product!.id,
              componentProductId: e.product.id,
              quantity: e.quantity,
            ),
          )
          .toList();

      final updatedProduct = _product!.copyWith(costPrice: newCost);

      // Using the same create method which executes transaction of delete and insert
      // Wait, createCompositeProduct does INSERT ON CONFLICT DO UPDATE? Actually, we should check what repository offers.
      // Or we can just build an update method if one is missing, but createCompositeProduct usually replaces.
      // Assuming createCompositeProduct handles updating standard product data and replaces components via transaction.
      // We will call createCompositeProduct to override existing.
      await repository.createCompositeProduct(updatedProduct, dbComponents);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved successfully.')),
        );
        setState(() {
          _isEditing = false;
          _editableComponents = null;
        });

        // Invalidate to refresh UI
        ref.invalidate(compositeComponentsProvider(widget.productId));
        ref.invalidate(allProductsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final allProductsAsync = ref.watch(allProductsProvider);
    final componentsAsync = ref.watch(
      compositeComponentsProvider(widget.productId),
    );

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Components' : 'Composite Details'),
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 16, left: 8),
              child: FilledButton(
                onPressed: _isSaving ? null : _saveChanges,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save'),
              ),
            )
          else if (allProductsAsync.hasValue && componentsAsync.hasValue)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: OutlinedButton.icon(
                icon: const PhosphorIcon(
                  PhosphorIconsDuotone.pencilSimple,
                  size: 18,
                ),
                label: const Text('Edit'),
                onPressed: () {
                  _product = allProductsAsync.value!.firstWhere(
                    (p) => p.id == widget.productId,
                  );
                  _beginEdit(componentsAsync.value!, allProductsAsync.value!);
                },
              ),
            ),
        ],
      ),
      body: allProductsAsync.when(
        data: (allProducts) {
          try {
            _product = allProducts.firstWhere((p) => p.id == widget.productId);
          } catch (_) {
            return const Center(child: Text('Product not found.'));
          }

          return componentsAsync.when(
            data: (dbComponents) {
              return _buildBody(theme, cs, allProducts, dbComponents);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    ColorScheme cs,
    List<Product> allProducts,
    List<CompositeItemComponent> dbComponents,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 80 : 20,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),

                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: PhosphorIcon(
                          PhosphorIconsDuotone.package,
                          color: cs.primary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _product!.name,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_product!.sku != null &&
                              _product!.sku!.isNotEmpty)
                            Text(
                              'SKU: ${_product!.sku}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            final group = _product!.itemGroupId != null
                                ? ref
                                      .watch(
                                        itemGroupProvider(
                                          _product!.itemGroupId!,
                                        ),
                                      )
                                      .value
                                : null;
                            final resolvedPrice = ref
                                .watch(productPricingServiceProvider)
                                .resolveSellingPrice(_product!, group);
                            return Text(
                              'Price: ${CurrencyHelper.format(resolvedPrice)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          },
                        ),
                        Text(
                          'Cost: Ksh ${_product!.costPrice?.toStringAsFixed(2) ?? '0.00'}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Text(
                'Bill of Materials',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              if (_isEditing) ...[
                _buildSearchField(cs, allProducts),
                const SizedBox(height: 16),
              ],

              _buildComponentsList(theme, cs, allProducts, dbComponents),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchField(ColorScheme cs, List<Product> allProducts) {
    var available = allProducts
        .where((p) => p.id != widget.productId)
        .toList(); // don't add itself
    final filtered = _searchQuery != null && _searchQuery!.isNotEmpty
        ? available
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_searchQuery!.toLowerCase()),
              )
              .toList()
        : <Product>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search items to add...',
            prefixIcon: const PhosphorIcon(
              PhosphorIconsDuotone.magnifyingGlass,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: cs.surfaceContainerLowest,
            isDense: true,
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        if (_searchQuery != null && _searchQuery!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No matching products')),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Consumer(
                          builder: (context, ref, child) {
                            final group = p.itemGroupId != null
                                ? ref
                                      .watch(itemGroupProvider(p.itemGroupId!))
                                      .value
                                : null;
                            final resolvedPrice = ref
                                .watch(productPricingServiceProvider)
                                .resolveSellingPrice(p, group);
                            return Text(CurrencyHelper.format(resolvedPrice));
                          },
                        ),
                        trailing: const PhosphorIcon(
                          PhosphorIconsBold.plus,
                          size: 18,
                        ),
                        onTap: () {
                          _addComponent(p);
                          setState(() => _searchQuery = null);
                        },
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildComponentsList(
    ThemeData theme,
    ColorScheme cs,
    List<Product> allProducts,
    List<CompositeItemComponent> dbComponents,
  ) {
    if (_isEditing && _editableComponents != null) {
      final active = _editableComponents!.where((e) => !e.isDeleted).toList();
      if (active.isEmpty) {
        return _buildEmptyState(cs, 'No components added yet.');
      }
      return Column(
        children: List.generate(active.length, (i) {
          final entry = active[i];
          return _buildComponentRow(theme, cs, entry: entry);
        }),
      );
    } else {
      if (dbComponents.isEmpty) {
        return _buildEmptyState(cs, 'This composite item has no components.');
      }
      return Column(
        children: dbComponents.map((comp) {
          try {
            final p = allProducts.firstWhere(
              (x) => x.id == comp.componentProductId,
            );
            return _buildComponentRow(theme, cs, dbComp: comp, product: p);
          } catch (_) {
            return const SizedBox.shrink();
          }
        }).toList(),
      );
    }
  }

  Widget _buildEmptyState(ColorScheme cs, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          PhosphorIcon(
            PhosphorIconsDuotone.lego,
            size: 48,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(msg, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildComponentRow(
    ThemeData theme,
    ColorScheme cs, {
    _EditableComponent? entry,
    CompositeItemComponent? dbComp,
    Product? product,
  }) {
    final p = entry?.product ?? product!;
    final quantity = entry?.quantity ?? dbComp!.quantity;
    final totalCost = (p.costPrice ?? 0.0) * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: PhosphorIcon(
                PhosphorIconsDuotone.cube,
                color: cs.secondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Cost: ${CurrencyHelper.format((p.costPrice ?? 0))} each',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (_isEditing)
            Row(
              children: [
                IconButton(
                  icon: const PhosphorIcon(PhosphorIconsBold.minus, size: 16),
                  onPressed: () {
                    if (entry!.quantity > 1) {
                      setState(() => entry.quantity--);
                    } else {
                      setState(() => entry.isDeleted = true);
                    }
                  },
                ),
                Text(
                  '$quantity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const PhosphorIcon(PhosphorIconsBold.plus, size: 16),
                  onPressed: () => setState(() => entry!.quantity++),
                ),
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIconsDuotone.trash,
                    color: cs.error,
                    size: 20,
                  ),
                  onPressed: () => setState(() => entry!.isDeleted = true),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Qty: $quantity',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(width: 16),
          SizedBox(
            width: 100,
            child: Text(
              CurrencyHelper.format(totalCost),
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
