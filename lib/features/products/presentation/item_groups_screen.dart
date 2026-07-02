import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/utils/responsive_modal.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/widgets/batch_pricing_update_sheet.dart';
import 'package:zynk/features/products/presentation/widgets/batch_stock_update_sheet.dart';

class ItemGroupsScreen extends ConsumerWidget {
  const ItemGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final itemGroupsAsync = ref.watch(allItemGroupsProvider);

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
        title: const Text('Item Groups'),
        actions: const [],
      ),
      body: itemGroupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return _buildEmptyState(context, theme);
          }
          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return _buildGrid(context, groups, crossAxisCount: 3);
              } else if (constraints.maxWidth > 600) {
                return _buildGrid(context, groups, crossAxisCount: 2);
              }
              return _buildList(context, groups, theme);
            },
          );
        },
        loading: () => _buildShimmer(theme),
        error: (e, s) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                PhosphorIconsDuotone.warning,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to load item groups',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push("/products/groups/add"),
        icon: const PhosphorIcon(PhosphorIconsBold.plus),
        label: const Text("Add Group"),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: const PhosphorIcon(PhosphorIconsDuotone.folder, size: 64),
          ),
          const SizedBox(height: 24),
          Text(
            'No Item Groups Yet',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create item groups to manage product variants\nlike sizes and colors from one place.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.push('/products/groups/add'),
            icon: const PhosphorIcon(PhosphorIconsBold.plus),
            label: const Text('Create Item Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<ItemGroup> groups,
    ThemeData theme,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _ItemGroupCard(group: group);
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<ItemGroup> groups, {
    required int crossAxisCount,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: groups.length,
      itemBuilder: (context, index) => _ItemGroupCard(group: groups[index]),
    );
  }

  Widget _buildShimmer(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          height: 72,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      },
    );
  }
}

class _ItemGroupCard extends ConsumerWidget {
  final ItemGroup group;

  const _ItemGroupCard({required this.group});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final productCount = ref.watch(productCountByGroupProvider(group.id));

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              context.push('/products/groups/${group.id}', extra: group),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: PhosphorIcon(
                    PhosphorIconsDuotone.folder,
                    color: cs.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (group.description != null &&
                          group.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          group.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildStatChip(
                            cs,
                            theme,
                            PhosphorIconsRegular.package,
                            '$productCount Items',
                          ),
                          _buildStatChip(
                            cs,
                            theme,
                            PhosphorIconsRegular.tag,
                            'KES ${group.defaultSellingPrice?.toStringAsFixed(0) ?? "0"}',
                          ),
                          if (group.defaultCommissionValue != null &&
                              group.defaultCommissionValue! > 0)
                            _buildStatChip(
                              cs,
                              theme,
                              PhosphorIconsRegular.handCoins,
                              group.defaultCommissionType == 'percentage'
                                  ? '${group.defaultCommissionValue}%'
                                  : 'KES ${group.defaultCommissionValue}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.dotsThreeVertical,
                  ),
                  tooltip: 'Batch Actions',
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        context.push('/products?groupId=${group.id}');
                      case 'price':
                        _showBatchPriceSheet(context, ref, group);
                      case 'stock':
                        _showBatchStockSheet(context, ref, group);
                      case 'delete':
                        _showDeleteDialog(context, ref, group);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'view',
                      child: Text('View Items'),
                    ),
                    const PopupMenuItem(
                      value: 'price',
                      child: Text('Batch Update Price'),
                    ),
                    const PopupMenuItem(
                      value: 'stock',
                      child: Text('Batch Update Stock'),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete Group',
                        style: TextStyle(color: cs.error),
                      ),
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

  Widget _buildStatChip(
    ColorScheme cs,
    ThemeData theme,
    PhosphorIconData icon,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PhosphorIcon(icon, size: 13, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

void _showBatchPriceSheet(
  BuildContext context,
  WidgetRef ref,
  ItemGroup group,
) {
  showResponsiveModal(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BatchPricingUpdateSheet(group: group),
  );
}

void _showBatchStockSheet(
  BuildContext context,
  WidgetRef ref,
  ItemGroup group,
) {
  showResponsiveModal(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BatchStockUpdateSheet(group: group),
  );
}

void _showDeleteDialog(BuildContext context, WidgetRef ref, ItemGroup group) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${group.name}"'),
      content: const Text('What should happen to items in this group?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            final repo = ref.read(repositoryProvider);
            await repo.deleteGroupOnly(group.id);
          },
          child: const Text('Delete group, keep items'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () async {
            Navigator.pop(context);
            final repo = ref.read(repositoryProvider);
            await repo.deleteGroupAndAllItems(group.id);
          },
          child: const Text('Delete group + all items'),
        ),
      ],
    ),
  );
}
