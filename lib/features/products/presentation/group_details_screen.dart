import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';
import 'package:zynk/features/products/presentation/widgets/batch_pricing_update_sheet.dart';
import 'package:zynk/features/products/presentation/widgets/batch_stock_update_sheet.dart';
import 'package:zynk/features/products/presentation/widgets/edit_item_group_sheet.dart';

import 'package:zynk/features/products/presentation/widgets/product_selection_sheet.dart';
import 'package:zynk/features/products/presentation/widgets/mismatch_resolution_sheet.dart';
import 'package:zynk/core/utils/currency.dart';
import 'package:zynk/core/utils/responsive_modal.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final ItemGroup group;
  const GroupDetailsScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  final Set<String> _selectedProductIds = {};
  bool _selectionMode = false;
  late ItemGroup _currentGroup;

  @override
  void initState() {
    super.initState();
    _currentGroup = widget.group;
  }

  void _toggleSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
        if (_selectedProductIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
      _selectionMode = false;
    });
  }

  Future<void> _showAssignProducts() async {
    final products = ref.read(allProductsProvider).value ?? [];
    final availableProducts = products
        .where((p) => p.itemGroupId != _currentGroup.id)
        .toList();

    if (availableProducts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other items available to assign')),
        );
      }
      return;
    }

    final selectedIds = await ProductSelectionSheet.show(
      context,
      availableProducts: availableProducts,
      initiallySelectedIds: {},
    );

    if (selectedIds != null && selectedIds.isNotEmpty && mounted) {
      final selectedProducts = availableProducts
          .where((p) => selectedIds.contains(p.id))
          .toList();
      final mismatchedProducts = selectedProducts
          .where(
            (p) =>
                p.pricingUnit != _currentGroup.defaultPricingUnit ||
                p.coveragePerBox != _currentGroup.defaultCoveragePerBox ||
                p.basePrice != _currentGroup.defaultSellingPrice ||
                p.costPrice != _currentGroup.defaultBuyingPrice,
          )
          .toList();

      Map<String, bool>? resolutionDecisions = {};

      if (mismatchedProducts.isNotEmpty) {
        resolutionDecisions = await MismatchResolutionSheet.show(
          context,
          targetGroup: _currentGroup,
          mismatchedProducts: mismatchedProducts,
        );
        if (resolutionDecisions == null) {
          // User canceled
          return;
        }
      }

      final repo = ref.read(repositoryProvider);

      // Perform updates
      for (final p in selectedProducts) {
        final normalize =
            resolutionDecisions[p.id] ??
            true; // if no mismatch, normalize logic is harmless

        var updatedProduct = p.copyWith(itemGroupId: _currentGroup.id);

        if (normalize) {
          updatedProduct = updatedProduct.copyWith(
            pricingUnit: _currentGroup.defaultPricingUnit,
            coveragePerBox: _currentGroup.defaultCoveragePerBox,
            basePrice: _currentGroup.defaultSellingPrice,
            costPrice: _currentGroup.defaultBuyingPrice,
          );
        }

        await repo.updateProduct(updatedProduct);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items assigned successfully.')),
        );
      }
    }
  }

  Future<void> _editGroupDetails() async {
    final updated = await EditItemGroupSheet.show(
      context,
      existingGroup: _currentGroup,
    );
    if (updated != null && mounted) {
      setState(() {
        _currentGroup = updated;
      });
      // Optionally trigger batch price update prompt if prices changed
      if (updated.defaultSellingPrice != widget.group.defaultSellingPrice ||
          updated.defaultBuyingPrice != widget.group.defaultBuyingPrice) {
        // Simple prompt for batch update
        _promptBatchPriceUpdate(updated);
      }
    }
  }

  Future<void> _promptBatchPriceUpdate(ItemGroup updatedGroup) async {
    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply to all items?'),
        content: const Text(
          'You changed the default prices. Would you like to apply these to all existing items in this group?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (apply == true && mounted) {
      final products = ref.read(allProductsProvider).value ?? [];
      final groupProducts = products
          .where((p) => p.itemGroupId == updatedGroup.id)
          .toList();

      showResponsiveModal(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => BatchPricingUpdateSheet(
          group: updatedGroup,
          initialItems: groupProducts,
          groupToUpdate: updatedGroup,
          oldPrice: widget.group.defaultSellingPrice,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final productsAsync = ref.watch(allProductsProvider);

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: _selectionMode
                ? Text('${_selectedProductIds.length} Selected')
                : Text(_currentGroup.name),
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            leading: _selectionMode
                ? IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.x),
                    onPressed: _clearSelection,
                  )
                : null,
            backgroundColor: colorScheme.surface,
            actions: [
              if (!_selectionMode)
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit')
                      _editGroupDetails();
                    else if (val == 'assign')
                      _showAssignProducts();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Group Details'),
                    ),
                    PopupMenuItem(
                      value: 'assign',
                      child: Text('Assign Products'),
                    ),
                  ],
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primaryContainer.withAlpha(150),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_currentGroup.name}',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${productsAsync.value?.where((p) => p.itemGroupId == _currentGroup.id).length ?? 0} Items',
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (_currentGroup.defaultPricingUnit ?? 'piece')
                                .toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_currentGroup.description != null &&
                        _currentGroup.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _currentGroup.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _StatItem(
                          label: 'Selling',
                          value: _currentGroup.defaultSellingPrice != null
                              ? 'KES ${_currentGroup.defaultSellingPrice}'
                              : '-',
                        ),
                        const SizedBox(width: 24),
                        _StatItem(
                          label: 'Buying',
                          value: _currentGroup.defaultBuyingPrice != null
                              ? 'KES ${_currentGroup.defaultBuyingPrice}'
                              : '-',
                        ),
                        const SizedBox(width: 24),
                        _StatItem(
                          label: 'Commission',
                          value:
                              _currentGroup.defaultCommissionType == 'none' ||
                                  _currentGroup.defaultCommissionType == null
                              ? 'None'
                              : '${_currentGroup.defaultCommissionValue}${_currentGroup.defaultCommissionType == 'percentage' ? '%' : ''}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: productsAsync.when(
          data: (products) {
            final groupProducts = products
                .where((p) => p.itemGroupId == _currentGroup.id)
                .toList();

            if (groupProducts.isEmpty) {
              return Center(
                child: Text(
                  'No items in this group.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.only(
                bottom: _selectionMode ? 100 : 24,
                top: 8,
              ),
              itemCount: groupProducts.length,
              itemBuilder: (context, index) {
                final product = groupProducts[index];
                final isSelected = _selectedProductIds.contains(product.id);

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: colorScheme.surfaceContainerHighest,
                  leading: CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    backgroundImage: product.imageUrl != null
                        ? CachedNetworkImageProvider(product.imageUrl!)
                        : null,
                    child: product.imageUrl == null
                        ? PhosphorIcon(
                            PhosphorIconsDuotone.package,
                            color: colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  trailing: _selectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(product.id),
                        )
                      : null,
                  title: Text(product.name),
                  subtitle: Consumer(
                    builder: (context, ref, child) {
                      final resolvedPrice = ref
                          .watch(productPricingServiceProvider)
                          .resolveSellingPrice(product, _currentGroup);
                      return Text(CurrencyHelper.format(resolvedPrice));
                    },
                  ),
                  onLongPress: () {
                    if (!_selectionMode) {
                      setState(() {
                        _selectionMode = true;
                        _selectedProductIds.add(product.id);
                      });
                    }
                  },
                  onTap: () {
                    if (_selectionMode) {
                      _toggleSelection(product.id);
                    } else {
                      // Navigate to product details if implemented, else nothing
                    }
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        ),
      ),
      bottomSheet: _selectionMode && _selectedProductIds.isNotEmpty
          ? _BatchOperationsBar(
              selectedCount: _selectedProductIds.length,
              onUpdatePricing: () {
                final products = ref.read(allProductsProvider).value ?? [];
                final toProcess = products
                    .where((p) => _selectedProductIds.contains(p.id))
                    .toList();
                showResponsiveModal(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => BatchPricingUpdateSheet(
                    group: _currentGroup,
                    initialItems: toProcess,
                  ),
                );
              },
              onUpdateStock: () {
                final products = ref.read(allProductsProvider).value ?? [];
                final toProcess = products
                    .where((p) => _selectedProductIds.contains(p.id))
                    .toList();
                showResponsiveModal(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => BatchStockUpdateSheet(
                    group: _currentGroup,
                    initialItems: toProcess,
                  ),
                );
              },
              onRemove: () async {
                final rep = ref.read(repositoryProvider);
                await rep.batchUpdateProductGroups(
                  _selectedProductIds.toList(),
                  null,
                );
                _clearSelection();
              },
            )
          : null,
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _BatchOperationsBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onUpdatePricing;
  final VoidCallback onUpdateStock;
  final VoidCallback onRemove;

  const _BatchOperationsBar({
    required this.selectedCount,
    required this.onUpdatePricing,
    required this.onUpdateStock,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: PhosphorIconsRegular.pencilSimple,
            label: 'Prices',
            onTap: onUpdatePricing,
          ),
          _ActionButton(
            icon: PhosphorIconsRegular.package,
            label: 'Stock',
            onTap: onUpdateStock,
          ),
          _ActionButton(
            icon: PhosphorIconsRegular.signOut,
            label: 'Remove',
            onTap: onRemove,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final PhosphorIconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
