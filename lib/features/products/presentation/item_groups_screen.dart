import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/core/models/schema_models.dart';

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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => context.push('/products/groups/add'),
              icon: const Icon(PhosphorIconsBold.plus, size: 18),
              label: const Text('Add Group'),
            ),
          ),
        ],
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
              Icon(PhosphorIconsDuotone.warning, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load item groups', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('$e', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
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
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
            icon: const Icon(PhosphorIconsBold.plus),
            label: const Text('Create Item Group'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ItemGroup> groups, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return _ItemGroupCard(group: group);
      },
    );
  }

  Widget _buildGrid(BuildContext context, List<ItemGroup> groups, {required int crossAxisCount}) {
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

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: InkWell(
          onTap: () => context.push('/products/groups/${group.id}', extra: group),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PhosphorIcon(
                    PhosphorIconsDuotone.folder,
                    color: cs.onPrimaryContainer,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (group.description != null && group.description!.isNotEmpty) ...[
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
                    ],
                  ),
                ),
                const PhosphorIcon(PhosphorIconsRegular.caretRight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
