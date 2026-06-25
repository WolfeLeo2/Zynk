import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

class _StatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null; // null = All

  void setStatus(String? status) => state = status;
}

final _adjustmentStatusFilterProvider =
    NotifierProvider.autoDispose<_StatusFilterNotifier, String?>(
      _StatusFilterNotifier.new,
    );

final _adjustmentsProvider = StreamProvider.autoDispose
    .family<List<StockAdjustment>, ({String tenantId, String? branchId})>((
      ref,
      args,
    ) {
      final repo = ref.watch(repositoryProvider);
      return repo.watchAllStockAdjustments(
        tenantId: args.tenantId,
        branchId: args.branchId,
        status: null, // Always fetch all to allow client-side filtering
      );
    });

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class AdjustmentsScreen extends ConsumerWidget {
  const AdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final tenantId = profile?.tenantId ?? '';
    final branchId = ref.watch(currentBranchIdProvider);

    // Can this user approve adjustments?
    final canApprove =
        profile?.role.isOwner == true ||
        profile?.permissions.contains(Permission.approveStock) == true;

    final statusFilter = ref.watch(_adjustmentStatusFilterProvider);

    final adjustmentsAsync = ref.watch(
      _adjustmentsProvider((tenantId: tenantId, branchId: branchId)),
    );

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
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
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.chartBar),
            tooltip: 'Stock Report',
            onPressed: () => context.push('/settings/stock-report'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: _StatusFilterBar(
            selected: statusFilter,
            onSelected: (v) =>
                ref.read(_adjustmentStatusFilterProvider.notifier).setStatus(v),
          ),
        ),
      ),
      body: adjustmentsAsync.when(
        loading: () => const _AdjustmentSkeletonList(),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (allAdjustments) {
          // Filter locally to prevent flashes
          final adjustments = allAdjustments.where((adj) {
            if (statusFilter == null) return true;
            return adj.status.name == statusFilter;
          }).toList();

          if (adjustments.isEmpty) {
            return _EmptyState(filter: statusFilter);
          }

          // Group by bundleId
          final grouped = <String, List<StockAdjustment>>{};
          for (final adj in adjustments) {
            final key = adj.bundleId ?? adj.id;
            grouped.putIfAbsent(key, () => []).add(adj);
          }
          final bundleIds = grouped.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            itemCount: bundleIds.length,
            itemBuilder: (context, i) {
              final bundleId = bundleIds[i];
              final items = grouped[bundleId]!;
              return _BundleTile(
                bundleId: bundleId,
                items: items,
                canApprove: canApprove,
              );
            },
          );
        },
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

  static final _options = [
    (label: 'All', value: null as String?),
    (label: 'Pending', value: StockAdjustmentStatus.pending.name),
    (label: 'Approved', value: StockAdjustmentStatus.approved.name),
    (label: 'Rejected', value: StockAdjustmentStatus.rejected.name),
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
            child: ChoiceChip(
              label: Text(opt.label),
              selected: isSelected,
              onSelected: (_) => onSelected(opt.value),
              showCheckmark: false,
              selectedColor: colorScheme.primary,
              backgroundColor: Colors.transparent,

              labelStyle: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bundle Tile
// ─────────────────────────────────────────────────────────────────────────────

class _BundleTile extends StatelessWidget {
  final String bundleId;
  final List<StockAdjustment> items;
  final bool canApprove;

  const _BundleTile({
    required this.bundleId,
    required this.items,
    required this.canApprove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateFmt = DateFormat('dd MMM yyyy');

    final first = items.first;
    final status = first.status;

    final (statusLabel, statusColor) = switch (status) {
      StockAdjustmentStatus.pending => ('Pending', colorScheme.secondary),
      StockAdjustmentStatus.approved => ('Approved', colorScheme.primary),
      StockAdjustmentStatus.rejected => ('Rejected', colorScheme.error),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: () => context.push('/settings/adjustments-review/$bundleId'),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        first.reasonLabel ??
                            'ADJ-${bundleId.substring(0, 5).toUpperCase()}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: first.reasonLabel != null
                              ? colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                    _StatusBadge(label: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 4),
                if (first.referenceNumber != null &&
                    first.referenceNumber!.isNotEmpty) ...[
                  Text(
                    'Ref: ${first.referenceNumber}',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  items.length == 1
                      ? first.productName ?? 'Unknown Product'
                      : '${first.productName ?? "Unknown"} and ${items.length - 1} others',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.user,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      first.adjusterName ?? 'System',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    PhosphorIcon(
                      PhosphorIconsRegular.calendar,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt.format(first.createdAt ?? DateTime.now()),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    const PhosphorIcon(
                      PhosphorIconsRegular.caretRight,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
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
      itemBuilder: (context, index) => Padding(
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const PhosphorIcon(
            PhosphorIconsRegular.warningCircle,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.filter});
  final String? filter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PhosphorIcon(
            PhosphorIconsRegular.clipboardText,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            filter == null
                ? 'No stock adjustments yet'
                : 'No $filter adjustments found',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
