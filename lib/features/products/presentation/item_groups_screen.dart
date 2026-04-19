import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/models/staff_model.dart';
import 'package:zynk/core/models/adjustment_reason.dart';

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
              Icon(
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
            icon: const Icon(PhosphorIconsBold.plus),
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

    return RepaintBoundary(
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: InkWell(
          onTap: () =>
              context.push('/products/groups/${group.id}', extra: group),
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
}

void _showBatchPriceSheet(
  BuildContext context,
  WidgetRef ref,
  ItemGroup group,
) {
  final controller = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Price for All Items in "${group.name}"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'This will update the base price for every item in this group.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'New Price',
              prefixText: 'KES ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final price = double.tryParse(controller.text);
                if (price == null) return;
                final repo = ref.read(repositoryProvider);
                await repo.batchSetPriceForGroup(group.id, price);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Price updated successfully for items in "${group.name}"',
                      ),
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: const Text('Apply to All Items'),
            ),
          ),
        ],
      ),
    ),
  );
}

void _showBatchStockSheet(
  BuildContext context,
  WidgetRef ref,
  ItemGroup group,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _BatchStockSheet(group: group),
  );
}

class _BatchStockSheet extends ConsumerStatefulWidget {
  final ItemGroup group;
  const _BatchStockSheet({required this.group});

  @override
  ConsumerState<_BatchStockSheet> createState() => _BatchStockSheetState();
}

class _BatchStockSheetState extends ConsumerState<_BatchStockSheet> {
  final _qtyController = TextEditingController();
  final _referenceController = TextEditingController();
  String _mode = 'set'; // 'set' | 'add' | 'subtract'

  StaffMember? _selectedAdjuster;
  AdjustmentReason? _selectedReason;
  bool _isLoading = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final qtyInfo = int.tryParse(_qtyController.text);
    if (qtyInfo == null || qtyInfo < 0) return;

    // created_by must reference auth.users(id), so we always use current profile userId.
    final currentUser = ref.read(currentProfileProvider);
    final adjusterId = currentUser?.userId;
    if (adjusterId == null) return;

    final tenantId = ref.read(tenantIdProvider) ?? '';
    final branchId = ref.read(currentBranchIdProvider) ?? '';

    if (branchId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a branch first.')),
        );
      }
      return;
    }

    final allBranchesMode = branchId == 'all';
    if (allBranchesMode && _mode != 'add') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'All Branches mode supports additions only. Use a specific branch for set/subtract.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(repositoryProvider);
      final referenceNumber = _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim();

      if (allBranchesMode) {
        final branches = (await repo.getBranches(
          tenantId,
        )).where((b) => b.id != 'all').toList();

        if (branches.isEmpty) {
          throw Exception('No branches found to apply stock additions.');
        }

        for (final branch in branches) {
          await repo.batchAdjustStockForGroup(
            groupId: widget.group.id,
            tenantId: tenantId,
            branchId: branch.id,
            quantity: qtyInfo,
            mode: _mode,
            adjusterId: adjusterId,
            adjustmentType: 'auto',
            reasonId: _selectedReason?.id,
            referenceNumber: referenceNumber,
          );
        }
      } else {
        await repo.batchAdjustStockForGroup(
          groupId: widget.group.id,
          tenantId: tenantId,
          branchId: branchId,
          quantity: qtyInfo,
          mode: _mode,
          adjusterId: adjusterId,
          adjustmentType: 'auto',
          reasonId: _selectedReason?.id,
          referenceNumber: referenceNumber,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allBranchesMode
                  ? 'Stock added for group "${widget.group.name}" across all branches'
                  : 'Stock updated successfully for items in "${widget.group.name}"',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final staffAsync = ref.watch(humanStaffProvider);
    final reasonsAsync = ref.watch(adjustmentReasonsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Batch Update Stock for "${widget.group.name}"',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 16),

          // Adjuster Selection
          Text('Adjuster', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          staffAsync.when(
            data: (staffList) {
              return DropdownButtonFormField<StaffMember>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                hint: const Text('Select a person...'),
                initialValue: _selectedAdjuster,
                items: staffList.map((staff) {
                  return DropdownMenuItem(
                    value: staff,
                    child: Text(staff.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedAdjuster = val),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Error loading staff'),
          ),
          const SizedBox(height: 16),

          // Reason Selection
          Text('Reason', style: theme.textTheme.labelMedium),
          const SizedBox(height: 8),
          reasonsAsync.when(
            data: (reasonsList) {
              return DropdownButtonFormField<AdjustmentReason>(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                hint: const Text('Select a reason...'),
                initialValue: _selectedReason,
                items: reasonsList.map((reason) {
                  return DropdownMenuItem(
                    value: reason,
                    child: Text(reason.label),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedReason = val),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text('Error loading reasons'),
          ),
          const SizedBox(height: 16),

          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'set', label: Text('Set to')),
              ButtonSegment(value: 'add', label: Text('Add')),
              ButtonSegment(value: 'subtract', label: Text('Subtract')),
            ],
            selected: {_mode},
            onSelectionChanged: (val) => setState(() => _mode = val.first),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _qtyController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _mode == 'set' ? 'New Quantity' : 'Amount',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Reference / Invoice #',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selectedAdjuster == null || _isLoading)
                  ? null
                  : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update Stock'),
            ),
          ),
        ],
      ),
    );
  }
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
