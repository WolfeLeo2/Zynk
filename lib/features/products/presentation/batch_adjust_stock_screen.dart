import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

class BatchAdjustStockScreen extends ConsumerStatefulWidget {
  const BatchAdjustStockScreen({super.key});

  @override
  ConsumerState<BatchAdjustStockScreen> createState() =>
      _BatchAdjustStockScreenState();
}

class _BatchAdjustStockScreenState
    extends ConsumerState<BatchAdjustStockScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  String _searchQuery = '';
  String _adjustmentType = 'addition';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _adjustmentTypes = [
    {
      'value': 'addition',
      'label': 'Add Stock',
      'icon': PhosphorIconsRegular.plusCircle,
      'color': Colors.green,
    },
    {
      'value': 'reduction',
      'label': 'Remove Stock',
      'icon': PhosphorIconsRegular.minusCircle,
      'color': Colors.orange,
    },
    {
      'value': 'damage',
      'label': 'Report Damage',
      'icon': PhosphorIconsRegular.warningCircle,
      'color': Colors.red,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submitBatch() async {
    final items = ref.read(batchStockProvider);
    if (items.isEmpty) return;

    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    final selectedBranchId = ref.read(currentBranchIdProvider);
    if (selectedBranchId == null || selectedBranchId == 'all') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a specific branch first.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(repositoryProvider);

      final adjustmentItems = items.map((item) {
        int qty = item.quantityChange;
        if (_adjustmentType == 'reduction' || _adjustmentType == 'damage') {
          qty = -qty;
        }
        return BatchAdjustmentItem(
          productId: item.product.id,
          quantityChange: qty,
          notes: item.notes,
        );
      }).toList();

      await repo.batchAdjustStock(
        tenantId: profile.tenantId,
        branchId: selectedBranchId,
        adjustmentType: _adjustmentType,
        items: adjustmentItems,
        createdBy: profile.userId,
        referenceNumber: _referenceController.text.isNotEmpty
            ? _referenceController.text
            : null,
      );

      if (mounted) {
        ref.read(batchStockProvider.notifier).clear();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Batch stock updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final productsAsync = ref.watch(allProductsProvider);
    final batchItems = ref.watch(batchStockProvider);
    final selectedBranchId = ref.watch(currentBranchIdProvider);

    final isInvalidBranch =
        selectedBranchId == null || selectedBranchId == 'all';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Adjust Stock'),
        actions: [
          if (batchItems.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ref.read(batchStockProvider.notifier).clear();
              },
              icon: const Icon(PhosphorIconsRegular.trash),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            ),
        ],
      ),
      body: isInvalidBranch
          ? _buildInvalidBranchState(context, colorScheme)
          : Row(
              children: [
                // Left Panel: Search and Add Products
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SearchBar(
                          controller: _searchController,
                          hintText: 'Search products by name or SKU...',
                          leading: const Icon(
                            PhosphorIconsRegular.magnifyingGlass,
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
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
                            var filtered = products
                                .where(
                                  (p) => !p.isService,
                                ) // Only physical goods
                                .toList();

                            if (_searchQuery.isNotEmpty) {
                              filtered = filtered.where((p) {
                                final nameMatch = p.name.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                );
                                final skuMatch =
                                    p.sku?.toLowerCase().contains(
                                      _searchQuery.toLowerCase(),
                                    ) ??
                                    false;
                                return nameMatch || skuMatch;
                              }).toList();
                            }

                            if (filtered.isEmpty) {
                              return const Center(
                                child: Text('No products found'),
                              );
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
                                        ? Icon(
                                            PhosphorIconsRegular.package,
                                            color:
                                                colorScheme.onPrimaryContainer,
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
                                      ? Icon(
                                          PhosphorIconsRegular.checkCircle,
                                          color: colorScheme.primary,
                                        )
                                      : IconButton(
                                          onPressed: () {
                                            ref
                                                .read(
                                                  batchStockProvider.notifier,
                                                )
                                                .addItem(product);
                                          },
                                          icon: const Icon(
                                            PhosphorIconsRegular.plus,
                                          ),
                                          style: IconButton.styleFrom(
                                            backgroundColor:
                                                colorScheme.primaryContainer,
                                            foregroundColor:
                                                colorScheme.onPrimaryContainer,
                                          ),
                                        ),
                                  onTap: isAdded
                                      ? null
                                      : () {
                                          ref
                                              .read(batchStockProvider.notifier)
                                              .addItem(product);
                                        },
                                );
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (err, stack) => Center(
                            child: Text('Error loading products: $err'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                // Right Panel: Form and Selected Items
                Expanded(
                  flex: 3,
                  child: Container(
                    color: colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Batch Settings Header
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Batch Settings',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _referenceController,
                                decoration: InputDecoration(
                                  labelText: 'Reference Number (Optional)',
                                  hintText:
                                      'e.g., PO-2023-001 or Delivery Note',
                                  prefixIcon: const Icon(
                                    PhosphorIconsRegular.receipt,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Adjustment Type',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _adjustmentTypes.map((type) {
                                  final isSelected =
                                      _adjustmentType == type['value'];
                                  final typeColor = type['color'] as Color;

                                  return ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          type['icon'] as IconData,
                                          size: 16,
                                          color: isSelected
                                              ? colorScheme.onPrimary
                                              : typeColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(type['label'] as String),
                                      ],
                                    ),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      if (selected) {
                                        setState(
                                          () => _adjustmentType =
                                              type['value'] as String,
                                        );
                                      }
                                    },
                                    selectedColor: typeColor,
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurface,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    side: BorderSide.none,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        // Selected Items List
                        Expanded(
                          child: batchItems.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        PhosphorIconsRegular
                                            .magnifyingGlassPlus,
                                        size: 64,
                                        color: colorScheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No items selected\nSearch and add items from the left',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(24),
                                  itemCount: batchItems.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 16),
                                  itemBuilder: (context, index) {
                                    final item = batchItems[index];
                                    return _BatchItemCard(item: item);
                                  },
                                ),
                        ),
                        // Bottom Actions
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.shadow.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -5),
                              ),
                            ],
                          ),
                          child: FilledButton.icon(
                            onPressed: batchItems.isEmpty || _isLoading
                                ? null
                                : _submitBatch,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(PhosphorIconsRegular.checkCircle),
                            label: Text(
                              _isLoading
                                  ? 'Processing...'
                                  : 'Confirm ${_adjustmentType.toUpperCase()} for ${batchItems.length} items',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInvalidBranchState(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.storefront,
              size: 64,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 24),
            Text(
              'Specific Branch Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stock adjustments must physically occur at a specific location. You currently have "All Branches" selected.\n\nPlease select a specific branch from the app bar drop-down before proceeding.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onErrorContainer,
                foregroundColor: colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchItemCard extends ConsumerStatefulWidget {
  final BatchItemState item;

  const _BatchItemCard({required this.item});

  @override
  ConsumerState<_BatchItemCard> createState() => _BatchItemCardState();
}

class _BatchItemCardState extends ConsumerState<_BatchItemCard> {
  late TextEditingController _notesController;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes);
    _qtyController = TextEditingController(
      text: widget.item.quantityChange.toString(),
    );
  }

  @override
  void didUpdateWidget(_BatchItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantityChange != widget.item.quantityChange) {
      if (_qtyController.text != widget.item.quantityChange.toString()) {
        _qtyController.text = widget.item.quantityChange.toString();
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _updateQuantity(String val) {
    final qty = int.tryParse(val) ?? 0;
    if (qty > 0) {
      ref
          .read(batchStockProvider.notifier)
          .updateQuantity(widget.item.product.id, qty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final product = widget.item.product;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                    ? Icon(
                        PhosphorIconsRegular.package,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (product.sku != null)
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(batchStockProvider.notifier).removeItem(product.id);
                },
                icon: const Icon(PhosphorIconsRegular.x),
                color: colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity Stepper/Input
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: widget.item.quantityChange > 1
                          ? () {
                              ref
                                  .read(batchStockProvider.notifier)
                                  .updateQuantity(
                                    product.id,
                                    widget.item.quantityChange - 1,
                                  );
                            }
                          : null,
                      icon: const Icon(PhosphorIconsRegular.minus, size: 16),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8, // matching icon button height roughly
                          ),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: _updateQuantity,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () {
                        ref
                            .read(batchStockProvider.notifier)
                            .updateQuantity(
                              product.id,
                              widget.item.quantityChange + 1,
                            );
                      },
                      icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Notes Input
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _notesController,
                  decoration: InputDecoration(
                    hintText: 'Item notes (optional)',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (val) {
                    ref
                        .read(batchStockProvider.notifier)
                        .updateNotes(product.id, val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
