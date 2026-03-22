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

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
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
                  message: 'Complete some sales to see your top products here',
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

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length > 6 ? 6 : products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _TopProductItem(
                    product: product,
                    index: index,
                    maxSold: maxSold,
                    colorScheme: colorScheme,
                  );
                },
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
    final basePrice = (product['base_price'] as num?)?.toDouble() ?? 0;
    final imageUrl = product['image_url'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          // Product image or icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return PhosphorIcon(PhosphorIconsDuotone.package, color: colorScheme.onSurfaceVariant, size: 20);
                      },
                    )
                  : PhosphorIcon(PhosphorIconsDuotone.package, color: colorScheme.onSurfaceVariant, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'KES ${basePrice.toStringAsFixed(0)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'KES ${_formatRevenue(totalRevenue)}',
                style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary, fontSize: 14),
              ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$totalSold sold',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRevenue(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }
}
