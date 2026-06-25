import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

class ProductTransactionHistoryScreen extends ConsumerWidget {
  final String productId;
  final String productName;

  const ProductTransactionHistoryScreen({
    super.key,
    required this.productId,
    required this.productName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final historyAsync = ref.watch(
      productTransactionHistoryProvider(productId),
    );

    return Scaffold(
      appBar: AppBar(title: Text('History: $productName')),
      body: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIconsDuotone.clockCounterClockwise,
                    size: 48,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No transaction history found',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: history.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final tx = history[index];
              return _buildTransactionTile(theme, colorScheme, tx, context);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            'Failed to load history: $e',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(
    ThemeData theme,
    ColorScheme colorScheme,
    ProductTransaction tx,
    BuildContext context,
  ) {
    final isPositive = tx.quantityChange > 0;
    final isSale = tx.type == 'sale';

    return ListTile(
      onTap: isSale && tx.referenceId != null
          ? () => context.push('/sales/${tx.referenceId}')
          : null,
      leading: CircleAvatar(
        backgroundColor: isSale
            ? colorScheme.primaryContainer
            : (isPositive
                  ? colorScheme.tertiaryContainer
                  : colorScheme.errorContainer),
        child: PhosphorIcon(
          isSale
              ? PhosphorIconsDuotone.receipt
              : (isPositive
                    ? PhosphorIconsDuotone.trendUp
                    : PhosphorIconsDuotone.trendDown),
          color: isSale
              ? colorScheme.onPrimaryContainer
              : (isPositive
                    ? colorScheme.onTertiaryContainer
                    : colorScheme.onErrorContainer),
        ),
      ),
      title: Text(tx.referenceNumber ?? (isSale ? 'Sale' : 'Adjustment')),
      subtitle: Text(
        '${tx.actorName ?? 'Unknown'} · ${tx.createdAt != null ? DateFormat('MMM d, y HH:mm').format(tx.createdAt!) : ''}',
      ),
      trailing: Text(
        '${isPositive ? '+' : ''}${tx.quantityChange}',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isPositive ? colorScheme.tertiary : colorScheme.error,
        ),
      ),
    );
  }
}
