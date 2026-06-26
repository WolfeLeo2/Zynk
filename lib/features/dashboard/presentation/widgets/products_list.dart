import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/dashboard/providers/dashboard_providers.dart';
import 'skeleton_widgets.dart';
import 'empty_error_states.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TOP SELLING ITEMS LIST
// ─────────────────────────────────────────────────────────────────────────────

class TopSellingProductsList extends ConsumerWidget {
  const TopSellingProductsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final productsAsync = ref.watch(topProductsProvider);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Selling Items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/products'),
                  child: const Text('See All'),
                ),
              ],
            ),
            const SizedBox(height: 2),
            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return EmptyState(
                    colorScheme: colorScheme,
                    title: 'No sales data yet',
                    message:
                        'Complete some sales to see your top products here',
                    icon: PhosphorIconsDuotone.package,
                  );
                }

                // Find max sold for progress bar scaling
                final maxSold = products.fold<double>(
                  1,
                  (m, p) => ((p['total_sold'] as num?)?.toDouble() ?? 0) > m
                      ? ((p['total_sold'] as num?)?.toDouble() ?? 0)
                      : m,
                );

                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 16),
                  child: Column(
                    children: List.generate(
                      products.length > 5 ? 5 : products.length,
                      (index) {
                        final product = products[index];
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                index ==
                                    (products.length > 5
                                            ? 5
                                            : products.length) -
                                        1
                                ? 0
                                : 16,
                          ),
                          child: _TopProductItem(
                            product: product,
                            index: index,
                            maxSold: maxSold,
                            colorScheme: colorScheme,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              loading: () => Column(
                children: List.generate(
                  3,
                  (_) => SkeletonListItem(colorScheme: colorScheme),
                ),
              ),
              error: (error, stack) => ErrorState(
                colorScheme: colorScheme,
                message: 'Failed to load products',
                onRetry: () => ref.invalidate(topProductsProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP PRODUCT ITEM
// ─────────────────────────────────────────────────────────────────────────────

class _TopProductItem extends StatelessWidget {
  final Map<String, dynamic> product;
  final int index;
  final double maxSold;
  final ColorScheme colorScheme;

  const _TopProductItem({
    required this.product,
    required this.index,
    required this.maxSold,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name'] as String? ?? 'Unknown';
    final totalSold = (product['total_sold'] as num?)?.toInt() ?? 0;
    final totalRevenue = (product['total_revenue'] as num?)?.toDouble() ?? 0;
    final progress = maxSold <= 0 ? 0.0 : totalSold / maxSold;

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$totalSold sold',
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Ksh ${_formatRevenue(totalRevenue)}',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatRevenue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
