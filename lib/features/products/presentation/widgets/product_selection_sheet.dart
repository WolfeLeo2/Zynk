import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/utils/currency.dart';
import 'package:zynk/core/utils/responsive_modal.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';

class ProductSelectionSheet extends ConsumerStatefulWidget {
  final List<Product> availableProducts;
  final Set<String> initiallySelectedIds;
  final String? branchId;

  const ProductSelectionSheet({
    super.key,
    required this.availableProducts,
    required this.initiallySelectedIds,
    this.branchId,
  });

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<Product> availableProducts,
    required Set<String> initiallySelectedIds,
    String? branchId,
  }) {
    return showResponsiveModal<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductSelectionSheet(
        availableProducts: availableProducts,
        initiallySelectedIds: initiallySelectedIds,
        branchId: branchId,
      ),
    );
  }

  @override
  ConsumerState<ProductSelectionSheet> createState() =>
      _ProductSelectionSheetState();
}

class _ProductSelectionSheetState
    extends ConsumerState<ProductSelectionSheet> {
  late final Set<String> _selectedIds;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initiallySelectedIds);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Product> get _filtered {
    if (_searchQuery.isEmpty) return widget.availableProducts;
    return widget.availableProducts
        .where(
          (p) =>
              p.name.toLowerCase().contains(_searchQuery) ||
              (p.sku?.toLowerCase().contains(_searchQuery) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = _filtered;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Items',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_selectedIds.isNotEmpty)
                          Text(
                            '${_selectedIds.length} selected',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedIds),
                    child: const Text('Add Selected'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const PhosphorIcon(PhosphorIconsRegular.x),
                  ),
                ],
              ),
            ),

            // ── Search ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name or SKU...',
                  prefixIcon: const PhosphorIcon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 18,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const PhosphorIcon(
                            PhosphorIconsRegular.x,
                            size: 16,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
              ),
            ),

            const Divider(height: 1),

            // ── Product List ─────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PhosphorIcon(
                            PhosphorIconsDuotone.magnifyingGlass,
                            size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No items match your search',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return _ProductSelectionTile(
                          product: product,
                          isSelected: _selectedIds.contains(product.id),
                          branchId: widget.branchId,
                          onToggle: (selected, stock) {
                            final isOutOfStock =
                                !product.isService && (stock ?? 0) <= 0;
                            if (isOutOfStock) return; // guard
                            setState(() {
                              if (selected) {
                                _selectedIds.add(product.id);
                              } else {
                                _selectedIds.remove(product.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),

            // ── Bottom action bar ────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _selectedIds.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedIds),
                    icon: const PhosphorIcon(PhosphorIconsBold.plus),
                    label: Text(
                      _selectedIds.isEmpty
                          ? 'Select items to add'
                          : 'Add ${_selectedIds.length} item${_selectedIds.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single product tile — watches stock reactively
// ─────────────────────────────────────────────────────────────────────────────

class _ProductSelectionTile extends ConsumerWidget {
  final Product product;
  final bool isSelected;
  final String? branchId;
  final void Function(bool selected, int? stock) onToggle;

  const _ProductSelectionTile({
    required this.product,
    required this.isSelected,
    required this.branchId,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final stockAsync = ref.watch(
      stockByBranchProvider((productId: product.id, branchId: branchId)),
    );

    final group = product.itemGroupId != null
        ? ref.watch(itemGroupProvider(product.itemGroupId!)).value
        : null;
    final pricingService = ref.watch(productPricingServiceProvider);
    final resolvedPrice = pricingService.resolveSellingPrice(product, group);

    return stockAsync.when(
      loading: () => _buildTile(
        context: context,
        cs: cs,
        theme: theme,
        stock: null,
        isLoading: true,
        resolvedPrice: resolvedPrice,
      ),
      error: (_, _) => _buildTile(
        context: context,
        cs: cs,
        theme: theme,
        stock: null,
        resolvedPrice: resolvedPrice,
      ),
      data: (stock) => _buildTile(
        context: context,
        cs: cs,
        theme: theme,
        stock: stock?.quantity,
        resolvedPrice: resolvedPrice,
      ),
    );
  }

  Widget _buildTile({
    required BuildContext context,
    required ColorScheme cs,
    required ThemeData theme,
    required double resolvedPrice,
    int? stock,
    bool isLoading = false,
  }) {
    final isOutOfStock = !product.isService && (stock ?? 0) <= 0;
    final isLowStock = !product.isService && (stock ?? 0) > 0 && (stock ?? 0) <= 5;

    Color? tileColor;
    if (isSelected) {
      tileColor = cs.primaryContainer.withValues(alpha: 0.25);
    } else if (isOutOfStock) {
      tileColor = cs.errorContainer.withValues(alpha: 0.08);
    }

    return InkWell(
      onTap: isOutOfStock
          ? null
          : () => onToggle(!isSelected, stock),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: tileColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Checkbox
            Checkbox(
              value: isSelected,
              onChanged: isOutOfStock
                  ? null
                  : (v) => onToggle(v == true, stock),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isOutOfStock
                          ? cs.onSurface.withValues(alpha: 0.4)
                          : null,
                    ),
                  ),
                  if (product.sku != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${product.sku}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Price chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          CurrencyHelper.format(resolvedPrice),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Stock indicator
                      if (!product.isService)
                        if (isLoading)
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: cs.onSurfaceVariant,
                            ),
                          )
                        else
                          _StockBadge(
                            stock: stock ?? 0,
                            isOutOfStock: isOutOfStock,
                            isLowStock: isLowStock,
                            cs: cs,
                            theme: theme,
                          )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Service',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
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

class _StockBadge extends StatelessWidget {
  final int stock;
  final bool isOutOfStock;
  final bool isLowStock;
  final ColorScheme cs;
  final ThemeData theme;

  const _StockBadge({
    required this.stock,
    required this.isOutOfStock,
    required this.isLowStock,
    required this.cs,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;
    final PhosphorIconData icon;

    if (isOutOfStock) {
      bgColor = cs.errorContainer;
      textColor = cs.onErrorContainer;
      label = 'Out of stock';
      icon = PhosphorIconsFill.warningCircle;
    } else if (isLowStock) {
      bgColor = cs.tertiaryContainer;
      textColor = cs.onTertiaryContainer;
      label = '$stock left';
      icon = PhosphorIconsFill.warningCircle;
    } else {
      bgColor = cs.secondaryContainer.withValues(alpha: 0.5);
      textColor = cs.onSecondaryContainer;
      label = '$stock in stock';
      icon = PhosphorIconsFill.circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 9, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
