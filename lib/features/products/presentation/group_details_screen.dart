import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final ItemGroup group;
  const GroupDetailsScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  final Set<String> _selectedProductIds = {};
  late TextEditingController _nameController;
  late TextEditingController _commissionValueController;
  late String _commissionType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _commissionValueController = TextEditingController(
      text: widget.group.defaultCommissionValue?.toString() ?? '',
    );
    final existingType = (widget.group.defaultCommissionType ?? 'none')
        .toLowerCase();
    _commissionType = existingType == 'percent' ? 'percentage' : existingType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commissionValueController.dispose();
    super.dispose();
  }

  void _toggleSelection(String productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  Future<void> _updateGroupSettings() async {
    final rep = ref.read(repositoryProvider);
    final val = double.tryParse(_commissionValueController.text);

    final updated = ItemGroup(
      id: widget.group.id,
      tenantId: widget.group.tenantId,
      name: _nameController.text.isNotEmpty
          ? _nameController.text
          : widget.group.name,
      description: widget.group.description,
      defaultCommissionType: _commissionType,
      defaultCommissionValue: val,
      createdAt: widget.group.createdAt,
      updatedAt: DateTime.now(),
    );
    await rep.updateItemGroup(updated);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Group settings updated')));
    }
  }

  Future<void> _showBatchOperations() async {
    if (_selectedProductIds.isEmpty) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(PhosphorIconsRegular.signOut),
                title: const Text('Remove from Group'),
                onTap: () async {
                  Navigator.pop(context);
                  final rep = ref.read(repositoryProvider);
                  await rep.batchUpdateProductGroups(
                    _selectedProductIds.toList(),
                    null,
                  );
                  setState(() {
                    _selectedProductIds.clear();
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  PhosphorIconsRegular.trash,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete item',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Optional: full deletion of products.
                  // For now, let's keep it simple and just remove them from group.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Deletion requires explicit confirmation. Please remove from group first.',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAssignProducts() async {
    final products = ref.read(allProductsProvider).value ?? [];
    final groups = ref.read(allItemGroupsProvider).value ?? [];
    final groupMap = {for (var g in groups) g.id: g.name};

    // Only show products not already in this group
    final availableProducts = products
        .where((p) => p.itemGroupId != widget.group.id)
        .toList();

    if (availableProducts.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No other items available')),
        );
      }
      return;
    }

    // Local state for bottom sheet
    final Set<String> toAssign = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Assign items',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          TextButton(
                            onPressed: () async {
                              final navigator = Navigator.of(context);
                              if (toAssign.isNotEmpty) {
                                final rep = ref.read(repositoryProvider);
                                await rep.batchUpdateProductGroups(
                                  toAssign.toList(),
                                  widget.group.id,
                                );
                              }
                              if (mounted) {
                                navigator.pop();
                              }
                            },
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: availableProducts.length,
                        itemBuilder: (context, index) {
                          final p = availableProducts[index];
                          final isSelected = toAssign.contains(p.id);
                          final currentGroupName =
                              groupMap[p.itemGroupId] ?? 'No Group';
                          return CheckboxListTile(
                            value: isSelected,
                            title: Text(p.name),
                            subtitle: Text(
                              'SKU: ${p.sku ?? "None"} • $currentGroupName',
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  toAssign.add(p.id);
                                } else {
                                  toAssign.remove(p.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productsAsync = ref.watch(allProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        actions: [
          if (_selectedProductIds.isNotEmpty)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.cards),
              onPressed: _showBatchOperations,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAssignProducts,
        icon: const Icon(PhosphorIconsRegular.plus),
        label: const Text('Assign items'),
      ),
      body: CustomScrollView(
        slivers: [
          // Commission Settings
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            PhosphorIconsDuotone.gear,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Group Settings',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _updateGroupSettings,
                            child: const Text('Save Updates'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Group Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Default Commission',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _commissionType,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('None'),
                                ),
                                DropdownMenuItem(
                                  value: 'fixed',
                                  child: Text('Fixed'),
                                ),
                                DropdownMenuItem(
                                  value: 'percentage',
                                  child: Text('Percentage'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _commissionType = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _commissionValueController,
                              keyboardType: TextInputType.number,
                              enabled: _commissionType != 'none',
                              decoration: InputDecoration(
                                labelText: 'Value',
                                hintText: _commissionType == 'percentage'
                                    ? 'e.g. 5'
                                    : 'e.g. 100',
                                border: const OutlineInputBorder(),
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
          ),

          // Header for Items
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Text(
                    'Items in Group',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_selectedProductIds.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      '${_selectedProductIds.length} selected',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Product List
          productsAsync.when(
            data: (products) {
              final groupProducts = products
                  .where((p) => p.itemGroupId == widget.group.id)
                  .toList();

              if (groupProducts.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No items in this group.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = groupProducts[index];
                  final isSelected = _selectedProductIds.contains(product.id);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      backgroundImage: product.imageUrl != null
                          ? CachedNetworkImageProvider(product.imageUrl!)
                          : null,
                      child: product.imageUrl == null
                          ? Icon(
                              PhosphorIconsRegular.package,
                              color: theme.colorScheme.onSurfaceVariant,
                            )
                          : null,
                    ),
                    title: Text(product.name),
                    subtitle: Text(
                      'KES ${product.basePrice.toStringAsFixed(2)}',
                    ),
                    trailing: Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(product.id),
                    ),
                    onTap: () => _toggleSelection(product.id),
                  );
                }, childCount: groupProducts.length),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, s) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ),

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}
