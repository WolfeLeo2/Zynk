import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null; // null = All

  void setStatus(String? status) => state = status;
}

final _adjustmentStatusFilterProvider =
    NotifierProvider<_StatusFilterNotifier, String?>(
  _StatusFilterNotifier.new,
);

final _adjustmentsProvider = StreamProvider.autoDispose
    .family<List<StockAdjustment>, ({String tenantId, String? status, String? branchId})>(
        (ref, args) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchAllStockAdjustments(
    tenantId: args.tenantId,
    branchId: args.branchId,
    status: args.status,
  );
});



// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdjustmentsScreen extends ConsumerWidget {
  const AdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(currentUserProfileProvider).value;
    final tenantId = profile?.tenantId ?? '';
    final branchId = ref.watch(currentBranchIdProvider);

    // Can this user approve/reject adjustments?
    final canApprove = profile?.role.isOwner == true ||
        profile?.role.isManager == true ||
        profile?.permissions.contains(Permission.manageStock) == true;

    final statusFilter = ref.watch(_adjustmentStatusFilterProvider);

    final adjustmentsAsync = ref.watch(
      _adjustmentsProvider((
        tenantId: tenantId,
        status: statusFilter,
        branchId: branchId,
      )),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: Builder(
              builder: (context) {
                if (MediaQuery.of(context).size.width < 840) {
                  return IconButton(
                    icon: const PhosphorIcon(PhosphorIconsRegular.list),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            title: const Text('Stock Adjustments'),
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.onSurface,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: _StatusFilterBar(
                selected: statusFilter,
                onSelected: (v) =>
                    ref.read(_adjustmentStatusFilterProvider.notifier).setStatus(v),
              ),
            ),
          ),
          adjustmentsAsync.when(
            loading: () => const SliverFillRemaining(
              child: _AdjustmentSkeletonList(),
            ),
            error: (e, _) => SliverFillRemaining(
              child: _ErrorState(message: e.toString()),
            ),
            data: (adjustments) {
              if (adjustments.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(filter: statusFilter),
                );
              }

              return SliverList.builder(
                itemCount: adjustments.length,
                itemBuilder: (context, i) => _AdjustmentTile(
                  adjustment: adjustments[i],
                  canApprove: canApprove,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _options = [
    (label: 'All', value: null),
    (label: 'Pending', value: 'pending'),
    (label: 'Approved', value: 'approved'),
    (label: 'Rejected', value: 'rejected'),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _options.map((opt) {
          final isSelected = selected == opt.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(opt.label),
              selected: isSelected,
              onSelected: (_) => onSelected(opt.value),
              showCheckmark: false,
              selectedColor: colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Adjustment Tile
// ─────────────────────────────────────────────────────────────────────────────

class _AdjustmentTile extends ConsumerWidget {
  const _AdjustmentTile({
    required this.adjustment,
    required this.canApprove,
  });

  final StockAdjustment adjustment;
  final bool canApprove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

    final isIncrease = adjustment.quantity > 0;
    final qtyText = isIncrease
        ? '+${adjustment.quantity}'
        : '${adjustment.quantity}';
    final qtyColor = isIncrease ? colorScheme.primary : colorScheme.error;

    final status = adjustment.status;
    final (statusColor, statusBg) = switch (status) {
      'approved' => (colorScheme.primary, colorScheme.primaryContainer),
      'rejected' => (colorScheme.error, colorScheme.errorContainer),
      _ => (colorScheme.onSurfaceVariant, colorScheme.surfaceContainerHigh),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withAlpha(80)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          adjustment.productName ?? 'Unknown Product',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (adjustment.adjusterName != null)
                          Text(
                            'By ${adjustment.adjusterName}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    qtyText,
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: qtyColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Meta row
              Row(
                children: [
                  if (adjustment.reasonLabel != null) ...[
                    Icon(
                      Icons.label_outline_rounded,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      adjustment.reasonLabel!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (adjustment.adjustmentType != null) ...[
                    Icon(
                      Icons.category_outlined,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      adjustment.adjustmentType!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (adjustment.notes != null && adjustment.notes!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  adjustment.notes!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (adjustment.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  dateFmt.format(adjustment.createdAt!),
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.outlineVariant,
                  ),
                ),
              ],
              // Approve/Reject buttons for pending adjustments
              if (status == 'pending' && canApprove) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _reject(context, ref),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _approve(context, ref),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(currentUserProfileProvider).value;
    if (profile == null) return;

    await ref.read(repositoryProvider).approveAdjustment(
          adjustmentId: adjustment.id,
          approverId: profile.userId,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjustment approved.')),
      );
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Adjustment'),
        content: const Text(
          'This will reverse the stock change. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(repositoryProvider).rejectAdjustment(
          adjustmentId: adjustment.id,
        );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adjustment rejected and stock reversed.')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeletons / States
// ─────────────────────────────────────────────────────────────────────────────

class _AdjustmentSkeletonList extends StatelessWidget {
  const _AdjustmentSkeletonList();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filter});
  final String? filter;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = filter == null ? 'adjustments' : '$filter adjustments';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 72,
            color: colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No $label found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message),
      ),
    );
  }
}
