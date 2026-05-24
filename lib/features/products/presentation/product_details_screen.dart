import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/services/product_pricing_service.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final Product product;

  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              actions: [
                IconButton(
                  onPressed: () {
                    context.push('/products/add', extra: product);
                  },
                  icon: const PhosphorIcon(PhosphorIconsDuotone.pencilSimple),
                  tooltip: 'Edit Item',
                ),
                IconButton(
                  onPressed: () {
                    context.push(
                      '/products/add',
                      extra: {'product': product, 'clone': true},
                    );
                  },
                  icon: const PhosphorIcon(PhosphorIconsDuotone.copy),
                  tooltip: 'Clone Item',
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  product.name,
                  style: TextStyle(
                    color: innerBoxIsScrolled ? colorScheme.onSurface : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (product.imageUrl != null)
                      CachedNetworkImage(
                        imageUrl: product.imageUrl!,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.tertiary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: PhosphorIcon(
                            PhosphorIconsDuotone.package,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    // Gradient overlay to ensure text readability
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    if (product.barcode != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsDuotone.barcode,
                            size: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
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
              const SizedBox(height: 24),
              const Divider(height: 1),

              // Category and Group Information
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                    const SizedBox(height: 24),
                    Consumer(
                      builder: (context, ref, child) {
                        final categories = ref.watch(allCategoriesProvider).value ?? [];
                        final categoryName = categories
                                .where((c) => c.id == product.categoryId)
                                .map((c) => c.name)
                                .firstOrNull ??
                            'No Category';

                        return Row(
                          children: [
                            PhosphorIcon(
                              PhosphorIconsRegular.folder,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoItem(
                                theme,
                                'Category',
                                categoryName,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Consumer(
                      builder: (context, ref, child) {
                        final groups = ref.watch(allItemGroupsProvider).value ?? [];
                        final groupName = groups
                                .where((g) => g.id == product.itemGroupId)
                                .map((g) => g.name)
                                .firstOrNull ??
                            'No Group';

                        return Row(
                          children: [
                            PhosphorIcon(
                              PhosphorIconsRegular.package,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoItem(
                                theme,
                                'Item Group',
                                groupName,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Pricing & Margins
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PhosphorIcon(
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
                    const SizedBox(height: 24),
                    Consumer(
                      builder: (context, ref, child) {
                        final group = product.itemGroupId != null
                            ? ref.watch(itemGroupProvider(product.itemGroupId!)).value
                            : null;
                        final pricingService = ref.watch(productPricingServiceProvider);
                        final resolvedSelling = pricingService.resolveSellingPrice(product, group);
                        final resolvedBuying = pricingService.resolveBuyingPrice(product, group);

                        return Row(
                          children: [
                            Expanded(
                              child: _buildInfoItem(
                                theme,
                                'Cost Price',
                                resolvedBuying > 0
                                    ? 'KES ${resolvedBuying.toStringAsFixed(2)}'
                                    : 'Not Set',
                              ),
                            ),
                            Expanded(
                              child: _buildInfoItem(
                                theme,
                                'Selling Price',
                                resolvedSelling > 0
                                    ? 'KES ${resolvedSelling.toStringAsFixed(2)}'
                                    : 'Not Set',
                                valueColor: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildInfoItem(
                      theme,
                      'Tax Category',
                      product.taxCategory?.toUpperCase() ?? 'STANDARD',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Inventory Status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        PhosphorIcon(
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
                    const SizedBox(height: 24),
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
                              final stockAsync = ref.watch(stockProvider(product.id));
                              return stockAsync.when(
                                data: (stock) => _buildInfoItem(
                                  theme,
                                  'Current Stock',
                                  stock?.quantity.toString() ?? '0',
                                ),
                                loading: () => _buildInfoItem(theme, 'Current Stock', '...'),
                                error: (_, _) => _buildInfoItem(theme, 'Current Stock', 'Err'),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (!product.isService) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final branchesAsync = ref.watch(allTenantBranchesProvider);
                      final branchStocksAsync = ref.watch(branchStocksProvider(product.id));

                      return branchesAsync.when(
                        data: (branches) {
                          final realBranches = branches.where((b) => b.id != 'all').toList();

                          return branchStocksAsync.when(
                            data: (stocks) {
                              final qtyByBranch = <String, int>{};
                              for (final stock in stocks) {
                                final prev = qtyByBranch[stock.branchId] ?? 0;
                                qtyByBranch[stock.branchId] = prev + stock.quantity;
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      PhosphorIcon(
                                        PhosphorIconsDuotone.storefront,
                                        color: colorScheme.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Branch Stock Matrix',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (realBranches.isEmpty)
                                    Text(
                                      'No branches available.',
                                      style: theme.textTheme.bodyMedium,
                                    )
                                  else
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingTextStyle: theme.textTheme.labelMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                        columns: const [
                                          DataColumn(label: Text('Branch')),
                                          DataColumn(label: Text('Quantity')),
                                        ],
                                        rows: realBranches.map(
                                          (branch) => DataRow(
                                            cells: [
                                              DataCell(Text(branch.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                              DataCell(
                                                Text(
                                                  (qtyByBranch[branch.id] ?? 0).toString(),
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ).toList(),
                                      ),
                                    ),
                                ],
                              );
                            },
                            loading: () => const LinearProgressIndicator(),
                            error: (_, _) => const Text('Failed to load branch stock.'),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('Failed to load branches.'),
                      );
                    },
                  ),
                ),
                
                // Transaction History (Flat list)
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
                  child: Text(
                    'Transaction History',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Consumer(
                  builder: (context, ref, child) {
                    final historyAsync = ref.watch(productTransactionHistoryProvider(product.id));
                    return historyAsync.when(
                      data: (history) {
                        if (history.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                'No transaction history recorded yet.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: history.length > 5 ? 5 : history.length, // Show latest 5
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final tx = history[index];
                            final isPositive = tx.quantityChange > 0;
                            final isSale = tx.type == 'sale';
                            
                            final title = tx.referenceNumber ?? (isSale ? 'Sale' : 'Adjustment');
                            final actor = tx.actorName ?? 'Unknown';
                            final timeStr = tx.createdAt != null
                                ? tx.createdAt!.toLocal().toString().substring(0, 16)
                                : '—';
                            
                            Widget icon;
                            if (isSale) {
                              icon = PhosphorIcon(
                                PhosphorIconsDuotone.receipt,
                                color: colorScheme.onPrimaryContainer,
                                size: 18,
                              );
                            } else {
                              icon = PhosphorIcon(
                                isPositive ? PhosphorIconsRegular.trendUp : PhosphorIconsRegular.trendDown,
                                color: isPositive ? Colors.green : Colors.red,
                                size: 18,
                              );
                            }

                            final tile = ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: isSale 
                                    ? colorScheme.primaryContainer 
                                    : (isPositive 
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1)),
                                child: icon,
                              ),
                              title: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '$actor · $timeStr',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              trailing: Text(
                                '${isPositive ? '+' : ''}${tx.quantityChange}',
                                style: TextStyle(
                                  color: isPositive ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onTap: isSale && tx.referenceId != null 
                                  ? () => context.push('/sales/${tx.referenceId}') 
                                  : null,
                            );

                            return isSale ? Material(color: Colors.transparent, child: tile) : tile;
                          },
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, st) => Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text('Failed to load history: $e'),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
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
