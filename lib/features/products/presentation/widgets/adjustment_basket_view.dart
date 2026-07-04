import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/dashboard/presentation/widgets/empty_error_states.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';
import 'package:zynk/features/products/presentation/widgets/batch_item_card.dart';

/// The adjustment basket: the list of items being adjusted, or a shared
/// empty state when nothing has been added yet.
class AdjustmentBasketView extends ConsumerWidget {
  final Set<String> selectedBranchIds;
  final String mode;

  const AdjustmentBasketView({
    super.key,
    required this.selectedBranchIds,
    required this.mode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final batchItems = ref.watch(batchStockProvider);

    if (batchItems.isEmpty) {
      return EmptyState(
        colorScheme: colorScheme,
        icon: PhosphorIconsDuotone.stack,
        title: 'No items yet',
        message: 'Add items from the catalog to adjust their stock.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: batchItems.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => BatchItemCard(
        item: batchItems[index],
        selectedBranchIds: selectedBranchIds,
        mode: mode,
      ),
    );
  }
}
