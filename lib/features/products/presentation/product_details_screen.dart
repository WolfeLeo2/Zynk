import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/products/add', extra: product);
            },
            icon: const Icon(PhosphorIconsDuotone.pencilSimple),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Image & Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: product.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: product.imageUrl!,
                          fit: BoxFit.cover,
                        )
                      : Icon(
                          PhosphorIconsDuotone.package,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
                const SizedBox(width: 24),
                // Title & SKU
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          product.sku ?? 'NO-SKU',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        product.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.barcode != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              PhosphorIconsDuotone.barcode,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.barcode!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Category and Group Information
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Classification',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Consumer(
                    builder: (context, ref, child) {
                      final categories =
                          ref.watch(allCategoriesProvider).value ?? [];
                      final categoryName =
                          categories
                              .where((c) => c.id == product.categoryId)
                              .map((c) => c.name)
                              .firstOrNull ??
                          'No Category';

                      return Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.folder,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Category',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  categoryName,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(height: 1),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final groups =
                          ref.watch(allItemGroupsProvider).value ?? [];
                      final groupName =
                          groups
                              .where((g) => g.id == product.itemGroupId)
                              .map((g) => g.name)
                              .firstOrNull ??
                          'No Group';

                      return Row(
                        children: [
                          Icon(
                            PhosphorIconsRegular.package,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Item Group',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  groupName,
                                  style: theme.textTheme.titleSmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Variant Details Card
            if (product.variantOptions?.isNotEmpty == true) ...[  
              _buildVariantCard(context, theme, colorScheme, ref),
              const SizedBox(height: 24),
            ],

            // Pricing & Margins Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsDuotone.money,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pricing & Margin',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          theme,
                          'Cost Price',
                          product.costPrice != null
                              ? 'KES ${product.costPrice!.toStringAsFixed(2)}'
                              : 'Not Set',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          theme,
                          'Selling Price',
                          'KES ${product.basePrice.toStringAsFixed(2)}',
                          valueColor: Theme.of(context).colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          theme,
                          'Tax Category',
                          product.taxCategory?.toUpperCase() ?? 'STANDARD',
                        ),
                      ),
                      Expanded(child: Container()),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Inventory Status Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        PhosphorIconsDuotone.stack,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Inventory Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          theme,
                          'Track Stock',
                          product.isService ? 'No (Service)' : 'Yes',
                        ),
                      ),
                      Expanded(
                        child: Consumer(
                          builder: (context, ref, child) {
                            if (product.isService) {
                              return _buildInfoItem(
                                theme,
                                'Current Stock',
                                'N/A',
                              );
                            }
                            final stockAsync = ref.watch(
                              stockProvider(product.id),
                            );
                            return stockAsync.when(
                              data: (stock) => _buildInfoItem(
                                theme,
                                'Current Stock',
                                stock?.quantity.toString() ?? '0',
                              ),
                              loading: () =>
                                  _buildInfoItem(theme, 'Current Stock', '...'),
                              error: (_, _) =>
                                  _buildInfoItem(theme, 'Current Stock', 'Err'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (!product.isService) ...[
                    Text(
                      'Stock History',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, child) {
                        final historyAsync = ref.watch(
                          stockHistoryProvider(product.id),
                        );
                        return historyAsync.when(
                          data: (history) {
                            if (history.isEmpty) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No stock history recorded yet.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: history.length > 5
                                  ? 5
                                  : history.length, // Show latest 5
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (context, index) {
                                final adj = history[index];
                                final isPositive = adj.quantity > 0;
                                final title = adj.reasonLabel ??
                                    adj.adjustmentType?.toUpperCase() ??
                                    'Adjustment';
                                final adjuster = adj.adjusterName ??
                                    adj.createdBy ??
                                    'Unknown';
                                final timeStr = adj.createdAt != null
                                    ? adj.createdAt!
                                        .toLocal()
                                        .toString()
                                        .substring(0, 16)
                                    : '—';
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: isPositive
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    child: Icon(
                                      isPositive
                                          ? PhosphorIconsRegular.trendUp
                                          : PhosphorIconsRegular.trendDown,
                                      color: isPositive
                                          ? Colors.green
                                          : Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '$adjuster · $timeStr',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  trailing: Text(
                                    '${isPositive ? '+' : ''}${adj.quantity}',
                                    style: TextStyle(
                                      color: isPositive
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (_, _) => const Text('Failed to load history'),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantCard(BuildContext context, ThemeData theme, ColorScheme cs, WidgetRef ref) {
    final opts = product.variantOptions!;
    final variants = (ref.watch(allProductsProvider).value ?? [])
        .where((p) => p.parentId == product.id)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(PhosphorIconsDuotone.swatches, color: cs.primary, size: 20),
            const SizedBox(width: 8),
            Text('Variants', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const Divider(height: 24),
          ...opts.entries.map((e) {
            final values = e.value is List
                ? (e.value as List).map((v) => v.toString()).toList()
                : [e.value.toString()];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(e.key, style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 6, runSpacing: 6,
                      children: values.map((val) => Chip(
                        label: Text(val, style: theme.textTheme.bodySmall),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (variants.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Variant Items', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: variants.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
                itemBuilder: (context, index) {
                  final v = variants[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                            image: v.imageUrl != null ? DecorationImage(
                              image: CachedNetworkImageProvider(v.imageUrl!),
                              fit: BoxFit.cover,
                            ) : null,
                          ),
                          child: v.imageUrl == null ? Icon(PhosphorIconsDuotone.image, size: 20, color: cs.onSurfaceVariant) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              if (v.sku != null)
                                Text('SKU: ${v.sku}', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('KES ${v.basePrice.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary)),
                            const SizedBox(height: 4),
                            ref.watch(stockProvider(v.id)).when(
                              data: (stock) {
                                final qty = stock?.quantity ?? 0;
                                final isLow = qty <= 5;
                                return Text(
                                  '$qty in stock',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isLow ? cs.error : cs.onSurfaceVariant,
                                    fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
                                  ),
                                );
                              },
                              loading: () => const SizedBox(width: 20, height: 10, child: LinearProgressIndicator()),
                              error: (_, __) => const Text('-'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    ThemeData theme,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
