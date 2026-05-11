import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/features/products/presentation/providers/inventory_providers.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:m3e_card_list/m3e_card_list.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final adjustmentDetailProvider = StreamProvider.autoDispose.family<List<StockAdjustment>, String>((ref, bundleId) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchStockAdjustmentsByBundle(bundleId);
});

class ActionLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool val) => state = val;
}

final _actionLoadingProvider = NotifierProvider.autoDispose<ActionLoadingNotifier, bool>(ActionLoadingNotifier.new);

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdjustmentDetailScreen extends ConsumerWidget {
  final String bundleId;
  const AdjustmentDetailScreen({super.key, required this.bundleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adjustmentsAsync = ref.watch(adjustmentDetailProvider(bundleId));
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return adjustmentsAsync.when(
      loading: () => const _LoadingView(),
      error: (err, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Error: $err')),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('No details found.')),
          );
        }
        final first = items.first;
        final status = first.status;
        final (statusLabel, statusColor) = switch (status) {
          StockAdjustmentStatus.pending => ('Pending', colorScheme.secondary),
          StockAdjustmentStatus.approved => ('Approved', colorScheme.primary),
          StockAdjustmentStatus.rejected => ('Rejected', colorScheme.error),
        };
        final productIds = items.map((i) => i.productId).toList()..sort();
        final branchId = first.branchId;
        final stockKey = '$branchId:${productIds.join(',')}';
        final stockAsync = ref.watch(adjustmentStockLevelsProvider(stockKey));

        final profile = ref.watch(currentUserProfileProvider).value;
        final canApprove = profile?.role.isOwner == true ||
            profile?.permissions.contains(Permission.approveStock) == true;

        return Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                title: Text('Stock Adjustments'),
                expandedHeight: 180,
                pinned: true,
                stretch: true,
                backgroundColor: colorScheme.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          statusColor.withAlpha(50),
                          colorScheme.surface,
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy').format(first.createdAt ?? DateTime.now()),
                              style: textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              first.reasonLabel ?? 'Manual Adjustment',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: _StatusBadge(status: first.status),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (first.status == StockAdjustmentStatus.pending && canApprove)
                    _AdjustmentPopupMenu(bundleId: bundleId, items: items),
                ],
              ),
            ],
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _MetadataSection(adjustment: first),
                const SizedBox(height: 32),
                _ItemsSection(
                  items: items,
                  stockLevels: stockAsync.value,
                  isLoadingStock: stockAsync.isLoading && stockAsync.value == null,
                  canEdit: canApprove && first.status == StockAdjustmentStatus.pending,
                ),
                if (first.notes != null && first.notes!.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _NotesSection(notes: first.notes!),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StockAdjustmentStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      StockAdjustmentStatus.pending => ('PENDING APPROVAL', Colors.orange),
      StockAdjustmentStatus.approved => ('APPROVED', colorScheme.primary),
      StockAdjustmentStatus.rejected => ('REJECTED', colorScheme.error),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(90),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MetadataSection extends ConsumerWidget {
  final StockAdjustment adjustment;
  const _MetadataSection({required this.adjustment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider).value ?? [];
    final branchName = branches.firstWhere((b) => b.id == adjustment.branchId, orElse: () => Branch(id: adjustment.branchId, tenantId: '', name: adjustment.branchId)).name;

    return Column(
      children: [
        _MetaItem(
          label: 'Reference',
          value: (adjustment.referenceNumber != null && adjustment.referenceNumber!.isNotEmpty)
              ? adjustment.referenceNumber!
              : 'ADJ-${adjustment.bundleId?.substring(0, 5).toUpperCase() ?? adjustment.id.substring(0, 5).toUpperCase()}',
        ),
        _MetaItem(label: 'Account', value: adjustment.adjusterName ?? 'System'),
        _MetaItem(label: 'Adjusted By', value: adjustment.staffName ?? adjustment.adjusterName ?? 'System'),
        _MetaItem(label: 'Adjustment Type', value: 'Quantity'),
        _MetaItem(label: 'Branch', value: branchName),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetaItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  final List<StockAdjustment> items;
  final Map<String, int>? stockLevels;
  final bool isLoadingStock;
  final bool canEdit;

  const _ItemsSection({
    required this.items,
    required this.stockLevels,
    required this.isLoadingStock,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Adjusted Items',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        M3ECardList(
          padding: EdgeInsets.zero,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            
            if (isLoadingStock || stockLevels == null) {
               return _AdjustmentItemRow(
                 item: item,
                 previousStock: 0,
                 newStock: 0,
                 canEdit: false,
                 isLoading: true,
               );
            }

            final currentStock = stockLevels![item.productId] ?? 0;
            
            final isApproved = item.status == StockAdjustmentStatus.approved;
            
            final int previousStock;
            final int newStock;

            if (isApproved && item.previousQuantity != null) {
              previousStock = item.previousQuantity!;
              newStock = item.previousQuantity! + item.quantity;
            } else {
              previousStock = isApproved ? (currentStock - item.quantity) : currentStock;
              newStock = isApproved ? currentStock : (previousStock + item.quantity);
            }

            return _AdjustmentItemRow(
              item: item,
              previousStock: previousStock,
              newStock: newStock,
              canEdit: canEdit,
              isLoading: false,
            );
          },
        ),
      ],
    );
  }
}

class _AdjustmentItemRow extends StatelessWidget {
  final StockAdjustment item;
  final int previousStock;
  final int newStock;
  final bool canEdit;
  final bool isLoading;

  const _AdjustmentItemRow({
    required this.item,
    required this.previousStock,
    required this.newStock,
    required this.canEdit,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(100),
              borderRadius: BorderRadius.circular(8),
            ),
            child: PhosphorIcon(
              PhosphorIconsRegular.package,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName ?? 'Unknown Product',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.uomAbbreviation ?? 'Units',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isLoading)
                Shimmer.fromColors(
                  baseColor: colorScheme.surfaceContainerHighest.withAlpha(100),
                  highlightColor: colorScheme.surfaceContainerHighest.withAlpha(200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 80,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 40,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$previousStock → $newStock',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (canEdit) ...[
                          const SizedBox(width: 8),
                          _EditQuantityButton(adjustment: item),
                        ],
                      ],
                    ),
                    Text(
                      '${item.quantity > 0 ? '+' : ''}${item.quantity}',
                      style: textTheme.bodySmall?.copyWith(
                        color: item.quantity > 0 ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditQuantityButton extends ConsumerWidget {
  final StockAdjustment adjustment;
  const _EditQuantityButton({required this.adjustment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: const PhosphorIcon(PhosphorIconsRegular.pencilSimple, size: 18),
      onPressed: () => _showEditDialog(context, ref),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: adjustment.quantity.toString());
    
    final newQty = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New Adjustment Quantity',
            helperText: 'Positive for addition, negative for reduction',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newQty != null) {
      await ref.read(repositoryProvider).updateStockAdjustmentQuantity(
        adjustmentId: adjustment.id,
        newQuantity: newQty,
      );
    }
  }
}

class _AdjustmentPopupMenu extends ConsumerWidget {
  final String bundleId;
  final List<StockAdjustment> items;

  const _AdjustmentPopupMenu({required this.bundleId, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (val) => _handleAction(context, ref, val),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'approve', child: Text('Approve')),
        const PopupMenuItem(value: 'reject', child: Text('Reject')),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
      ],
      icon: const PhosphorIcon(PhosphorIconsRegular.dotsThreeVertical),
    );
  }

  Future<void> _handleAction(BuildContext context, WidgetRef ref, String action) async {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    switch (action) {
      case 'approve':
        await _runAction(context, ref, () => ref.read(inventoryServiceProvider).approveAdjustment(
          tenantId: profile.tenantId,
          bundleId: bundleId,
        ), 'Adjustment approved.');
        break;
      case 'reject':
        _handleReject(context, ref, profile.tenantId);
        break;
      case 'delete':
        await _runAction(context, ref, () => ref.read(inventoryServiceProvider).deleteAdjustment(
          tenantId: profile.tenantId,
          bundleId: bundleId,
        ), 'Adjustment deleted.');
        break;
    }
  }

  Future<void> _runAction(BuildContext context, WidgetRef ref, Future<void> Function() fn, String successMsg) async {
    try {
      ref.read(_actionLoadingProvider.notifier).set(true);
      await fn();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMsg)));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      ref.read(_actionLoadingProvider.notifier).set(false);
    }
  }

  Future<void> _handleReject(BuildContext context, WidgetRef ref, String tenantId) async {
    final controller = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Adjustment'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Reject', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (proceed == true) {
      if (!context.mounted) return;
      await _runAction(context, ref, () => ref.read(inventoryServiceProvider).rejectAdjustment(
        tenantId: tenantId,
        bundleId: bundleId,
        reason: controller.text.isNotEmpty ? controller.text : 'Rejected by manager',
      ), 'Adjustment rejected.');
    }
  }
}

class _NotesSection extends StatelessWidget {
  final String notes;
  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
          ),
          child: Text(notes, style: textTheme.bodyMedium),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Column(
            children: [
              Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
              const SizedBox(height: 24),
              Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
            ],
          ),
        ),
      ),
    );
  }
}
