import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/widgets/app_drawer.dart';
import 'package:zynk/core/models/adjustment_reason.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/features/products/providers/batch_stock_provider.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/core/models/staff_model.dart';

class InventoryAdjustmentScreen extends ConsumerStatefulWidget {
  const InventoryAdjustmentScreen({super.key});

  @override
  ConsumerState<InventoryAdjustmentScreen> createState() =>
      _InventoryAdjustmentScreenState();
}

class _InventoryAdjustmentScreenState
    extends ConsumerState<InventoryAdjustmentScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  bool _applyToAllBranches = false;
  String? _reasonId;
  StaffMember? _selectedAdjuster;

  @override
  void dispose() {
    _searchController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  Future<void> _submitBatch() async {
    final items = ref.read(batchStockProvider);

    if (_reasonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a reason for this adjustment.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (items.isEmpty) return;

    final profile = ref.read(currentProfileProvider);
    if (profile == null) return;

    if (_selectedAdjuster == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select an adjuster.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final adjusterId = profile.userId;

    final selectedBranchId = ref.read(currentBranchIdProvider);
    if (selectedBranchId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a branch first.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final allBranchesMode = selectedBranchId == 'all' || _applyToAllBranches;

    final adjustmentItems = items
        .where((item) => item.quantityChange != 0)
        .map(
          (item) => BatchAdjustmentItem(
            productId: item.product.id,
            quantityChange: item.quantityChange,
            notes: item.notes,
          ),
        )
        .toList();

    if (adjustmentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please enter a non-zero quantity for at least one item.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    if (allBranchesMode &&
        adjustmentItems.any((item) => item.quantityChange <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'All Branches mode supports stock additions only. Use a specific branch for reductions or resets.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(repositoryProvider);
      final referenceNumber = _referenceController.text.isNotEmpty
          ? _referenceController.text
          : null;

      if (allBranchesMode) {
        final visibleBranches = ref.read(branchesProvider).value;
        final branches =
            (visibleBranches ?? await repo.getBranches(profile.tenantId))
                .where((b) => b.id != 'all')
                .toList();

        if (branches.isEmpty) {
          throw Exception('No branches found to apply stock additions.');
        }

        for (final branch in branches) {
          await repo.batchAdjustStock(
            tenantId: profile.tenantId,
            branchId: branch.id,
            items: adjustmentItems,
            createdBy: adjusterId,
            adjustmentType: 'auto',
            reasonId: _reasonId,
            referenceNumber: referenceNumber,
          );
        }
      } else {
        await repo.batchAdjustStock(
          tenantId: profile.tenantId,
          branchId: selectedBranchId,
          items: adjustmentItems,
          createdBy: adjusterId,
          adjustmentType: 'auto',
          reasonId: _reasonId,
          referenceNumber: referenceNumber,
        );
      }

      if (mounted) {
        ref.read(batchStockProvider.notifier).clear();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              allBranchesMode
                  ? 'Added stock for ${adjustmentItems.length} item(s) across all branches.'
                  : 'Adjustment confirmed for ${adjustmentItems.length} item(s)!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showManageReasons(
    BuildContext context,
    List<AdjustmentReason> reasons,
    String tenantId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) =>
          _ManageReasonsSheet(reasons: reasons, tenantId: tenantId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final productsAsync = ref.watch(allProductsProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final batchItems = ref.watch(batchStockProvider);
    final selectedBranchId = ref.watch(currentBranchIdProvider);
    final effectiveAllBranchesMode =
        selectedBranchId == 'all' || _applyToAllBranches;

    final isInvalidBranch = selectedBranchId == null;

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
        title: const Text('Adjustments'),
        actions: [
          if (batchItems.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                ref.read(batchStockProvider.notifier).clear();
              },
              icon: const Icon(PhosphorIconsRegular.trash),
              label: const Text('Clear All'),
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
            ),
        ],
      ),
      body: isInvalidBranch
          ? _buildInvalidBranchState(context, colorScheme)
          : LayoutBuilder(
              builder: (context, constraints) {
                final leftPanel = Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SearchBar(
                        controller: _searchController,
                        hintText: 'Search items by name or SKU...',
                        leading: const Icon(
                          PhosphorIconsRegular.magnifyingGlass,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(horizontal: 16),
                        ),
                        elevation: const WidgetStatePropertyAll(0),
                        backgroundColor: WidgetStatePropertyAll(
                          colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    Expanded(
                      child: productsAsync.when(
                        data: (products) {
                          var filtered = products
                              .where((p) => !p.isService) // Only physical goods
                              .toList();

                          if (_searchQuery.isNotEmpty) {
                            filtered = filtered.where((p) {
                              final nameMatch = p.name.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              );
                              final skuMatch =
                                  p.sku?.toLowerCase().contains(
                                    _searchQuery.toLowerCase(),
                                  ) ??
                                  false;
                              return nameMatch || skuMatch;
                            }).toList();
                          }

                          if (filtered.isEmpty) {
                            return const Center(child: Text('No items found'));
                          }

                          return ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              final isAdded = batchItems.any(
                                (item) => item.product.id == product.id,
                              );

                              return ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                    image: product.imageUrl != null
                                        ? DecorationImage(
                                            image: CachedNetworkImageProvider(
                                              product.imageUrl!,
                                            ),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: product.imageUrl == null
                                      ? Icon(
                                          PhosphorIconsRegular.package,
                                          color: colorScheme.onPrimaryContainer,
                                        )
                                      : null,
                                ),
                                title: Text(product.name),
                                subtitle: Text(
                                  product.sku ?? 'No SKU',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isAdded
                                    ? Icon(
                                        PhosphorIconsRegular.checkCircle,
                                        color: colorScheme.primary,
                                      )
                                    : IconButton(
                                        onPressed: () {
                                          ref
                                              .read(batchStockProvider.notifier)
                                              .addItem(product);
                                        },
                                        icon: const Icon(
                                          PhosphorIconsRegular.plus,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                              colorScheme.primaryContainer,
                                          foregroundColor:
                                              colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                onTap: isAdded
                                    ? null
                                    : () {
                                        ref
                                            .read(batchStockProvider.notifier)
                                            .addItem(product);
                                      },
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (err, stack) =>
                            Center(child: Text('Error loading items: $err')),
                      ),
                    ),
                  ],
                );
                final rightPanel = Container(
                  color: colorScheme.surface,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Batch Settings Header
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Batch Settings',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              branchesAsync.when(
                                data: (branches) {
                                  final targetBranches =
                                      effectiveAllBranchesMode
                                      ? branches
                                      : branches
                                            .where(
                                              (b) => b.id == selectedBranchId,
                                            )
                                            .toList();
                                  final canToggleAll =
                                      selectedBranchId != 'all';

                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SwitchListTile.adaptive(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Apply to all branches',
                                          ),
                                          subtitle: Text(
                                            selectedBranchId == 'all'
                                                ? 'All Branches is selected in the top bar.'
                                                : effectiveAllBranchesMode
                                                ? 'Adds stock to every visible branch.'
                                                : 'Adds stock only to the selected branch.',
                                          ),
                                          value: effectiveAllBranchesMode,
                                          onChanged: canToggleAll
                                              ? (v) => setState(
                                                  () => _applyToAllBranches = v,
                                                )
                                              : null,
                                        ),
                                        if (effectiveAllBranchesMode) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'All-branches mode supports stock additions only. Use a specific branch for reductions or resets.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                        if (targetBranches.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: targetBranches
                                                .map(
                                                  (b) => Chip(
                                                    label: Text(b.name),
                                                    avatar: const Icon(
                                                      PhosphorIconsRegular
                                                          .storefront,
                                                      size: 14,
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                              const SizedBox(height: 16),
                              // Adjuster Selection
                              Consumer(
                                builder: (context, ref, _) {
                                  final staffAsync = ref.watch(
                                    humanStaffProvider,
                                  );
                                  return staffAsync.when(
                                    data: (staffList) =>
                                        DropdownButtonFormField<StaffMember>(
                                          initialValue: _selectedAdjuster,
                                          decoration: InputDecoration(
                                            labelText: 'Adjuster *',
                                            prefixIcon: const Icon(
                                              PhosphorIconsRegular.user,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            isDense: true,
                                          ),
                                          hint: const Text(
                                            'Select an adjuster',
                                          ),
                                          items: staffList
                                              .map(
                                                (s) =>
                                                    DropdownMenuItem<
                                                      StaffMember
                                                    >(
                                                      value: s,
                                                      child: Text(s.name),
                                                    ),
                                              )
                                              .toList(),
                                          onChanged: (v) => setState(
                                            () => _selectedAdjuster = v,
                                          ),
                                        ),
                                    loading: () =>
                                        const LinearProgressIndicator(),
                                    error: (e, _) =>
                                        Text('Error loading staff: $e'),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              // Reason picker row
                              Consumer(
                                builder: (context, ref, _) {
                                  final tenantId =
                                      ref.watch(tenantIdProvider) ?? '';
                                  final profile = ref.watch(
                                    currentProfileProvider,
                                  );
                                  final canManage =
                                      profile != null &&
                                      (profile.role.isOwner ||
                                          profile.role.isManager ||
                                          profile.permissions.contains(
                                            Permission.manageBusiness,
                                          ) ||
                                          profile.permissions.contains(
                                            Permission.manageStock,
                                          ));
                                  final reasonsAsync = ref.watch(
                                    adjustmentReasonsProvider,
                                  );
                                  return reasonsAsync.when(
                                    data: (reasons) => Row(
                                      children: [
                                        Expanded(
                                          child:
                                              DropdownButtonFormField<String>(
                                                initialValue: _reasonId,
                                                decoration: InputDecoration(
                                                  labelText: 'Reason *',
                                                  prefixIcon: const Icon(
                                                    PhosphorIconsRegular
                                                        .question,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  isDense: true,
                                                ),
                                                hint: const Text(
                                                  'Select a reason',
                                                ),
                                                items: reasons
                                                    .map(
                                                      (r) =>
                                                          DropdownMenuItem<
                                                            String
                                                          >(
                                                            value: r.id,
                                                            child: Text(
                                                              r.label,
                                                            ),
                                                          ),
                                                    )
                                                    .toList(),
                                                onChanged: (v) => setState(
                                                  () => _reasonId = v,
                                                ),
                                              ),
                                        ),
                                        if (canManage) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Manage reasons',
                                            onPressed: () => _showManageReasons(
                                              context,
                                              reasons,
                                              tenantId,
                                            ),
                                            icon: const Icon(
                                              PhosphorIconsRegular.pencilSimple,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    loading: () =>
                                        const LinearProgressIndicator(),
                                    error: (e, _) =>
                                        Text('Could not load reasons: $e'),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              // Reference number
                              TextField(
                                controller: _referenceController,
                                decoration: InputDecoration(
                                  labelText: 'Reference Number (Optional)',
                                  hintText:
                                      'e.g., PO-2023-001 or Delivery Note',
                                  prefixIcon: const Icon(
                                    PhosphorIconsRegular.receipt,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      // Selected Items List
                      Expanded(
                        child: batchItems.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      PhosphorIconsRegular.magnifyingGlassPlus,
                                      size: 64,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No items selected\nSearch and add items from the left',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(24),
                                itemCount: batchItems.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final item = batchItems[index];
                                  return _BatchItemCard(item: item);
                                },
                              ),
                      ),
                      // Bottom Actions
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: FilledButton.icon(
                          onPressed: batchItems.isEmpty || _isLoading
                              ? null
                              : _submitBatch,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(PhosphorIconsRegular.checkCircle),
                          label: Text(
                            _isLoading
                                ? 'Processing...'
                                : effectiveAllBranchesMode
                                ? 'Add to All Branches (${batchItems.length} item${batchItems.length == 1 ? '' : 's'})'
                                : 'Confirm Adjustment (${batchItems.length} item${batchItems.length == 1 ? '' : 's'})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (constraints.maxWidth > 800) {
                  return Row(
                    children: [
                      Expanded(flex: 4, child: leftPanel),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 6, child: rightPanel),
                    ],
                  );
                }

                return DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        tabs: [
                          const Tab(text: 'Select items'),
                          Tab(text: 'Review & Adjust (${batchItems.length})'),
                        ],
                        labelColor: colorScheme.primary,
                        unselectedLabelColor: colorScheme.onSurfaceVariant,
                        indicatorColor: colorScheme.primary,
                      ),
                      Expanded(
                        child: TabBarView(children: [leftPanel, rightPanel]),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildInvalidBranchState(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.storefront,
              size: 64,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 24),
            Text(
              'Branch Required',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please select a branch from the app bar drop-down before proceeding.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onErrorContainer.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.pop(),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.onErrorContainer,
                foregroundColor: colorScheme.errorContainer,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
              icon: const Icon(PhosphorIconsRegular.arrowLeft),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchItemCard extends ConsumerStatefulWidget {
  final BatchItemState item;

  const _BatchItemCard({required this.item});

  @override
  ConsumerState<_BatchItemCard> createState() => _BatchItemCardState();
}

class _BatchItemCardState extends ConsumerState<_BatchItemCard> {
  late TextEditingController _notesController;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes);
    _qtyController = TextEditingController(
      text: widget.item.quantityChange == 0
          ? ''
          : widget.item.quantityChange.toString(),
    );
  }

  @override
  void didUpdateWidget(_BatchItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantityChange != widget.item.quantityChange) {
      if (_qtyController.text != widget.item.quantityChange.toString() &&
          widget.item.quantityChange != 0) {
        _qtyController.text = widget.item.quantityChange.toString();
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _updateQuantity(String val) {
    // Allow empty field (treat as 0) and negative numbers
    final qty = int.tryParse(val) ?? 0;
    ref
        .read(batchStockProvider.notifier)
        .updateQuantity(widget.item.product.id, qty);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final product = widget.item.product;
    final stockAsync = ref.watch(stockProvider(product.id));
    final currentStock = stockAsync.value?.quantity ?? 0;
    final newStock = currentStock + widget.item.quantityChange;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  image: product.imageUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(product.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product.imageUrl == null
                    ? Icon(
                        PhosphorIconsRegular.package,
                        color: colorScheme.onPrimaryContainer,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (product.sku != null)
                      Text(
                        'SKU: ${product.sku}',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  ref.read(batchStockProvider.notifier).removeItem(product.id);
                },
                icon: const Icon(PhosphorIconsRegular.x),
                color: colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stock calculation
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Current Stock: $currentStock',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                    Icon(
                      PhosphorIconsRegular.arrowRight,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    Text(
                      'New Stock: $newStock',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.item.quantityChange < 0
                            ? colorScheme.error
                            : widget.item.quantityChange > 0
                            ? Colors.green
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Quantity Stepper/Input
              Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      ref
                          .read(batchStockProvider.notifier)
                          .updateQuantity(
                            product.id,
                            widget.item.quantityChange - 1,
                          );
                    },
                    icon: const Icon(PhosphorIconsRegular.minus, size: 16),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        signed: true,
                        decimal: false,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.item.quantityChange < 0
                            ? Colors.red
                            : widget.item.quantityChange > 0
                            ? Colors.green
                            : null,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: _updateQuantity,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () {
                      ref
                          .read(batchStockProvider.notifier)
                          .updateQuantity(
                            product.id,
                            widget.item.quantityChange + 1,
                          );
                    },
                    icon: const Icon(PhosphorIconsRegular.plus, size: 16),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Notes Input
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: 'Item notes (optional)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (val) {
                  ref
                      .read(batchStockProvider.notifier)
                      .updateNotes(product.id, val);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE REASONS BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ManageReasonsSheet extends ConsumerStatefulWidget {
  final List<AdjustmentReason> reasons;
  final String tenantId;

  const _ManageReasonsSheet({required this.reasons, required this.tenantId});

  @override
  ConsumerState<_ManageReasonsSheet> createState() =>
      _ManageReasonsSheetState();
}

class _ManageReasonsSheetState extends ConsumerState<_ManageReasonsSheet> {
  final _addController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addReason() async {
    final label = _addController.text.trim();
    if (label.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      final repo = ref.read(repositoryProvider);
      final reason = AdjustmentReason(
        id: const Uuid().v4(),
        tenantId: widget.tenantId,
        label: label,
        createdAt: DateTime.now().toUtc(),
      );
      await repo.createAdjustmentReason(reason);
      _addController.clear();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteReason(String id) async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteAdjustmentReason(id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Live-watch so additions/deletions reflect immediately
    final liveReasons = ref.watch(adjustmentReasonsProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Manage Adjustment Reasons',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Add row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addController,
                      decoration: InputDecoration(
                        hintText: 'New reason label...',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _addReason(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isAdding ? null : _addReason,
                    child: _isAdding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: liveReasons.when(
                data: (reasons) => reasons.isEmpty
                    ? Center(
                        child: Text(
                          'No reasons yet. Add one above.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: reasons.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) {
                          final r = reasons[i];
                          return ListTile(
                            leading: const Icon(PhosphorIconsRegular.tagSimple),
                            title: Text(r.label),
                            trailing: IconButton(
                              icon: Icon(
                                PhosphorIconsRegular.trash,
                                color: colorScheme.error,
                              ),
                              onPressed: () => _deleteReason(r.id),
                              tooltip: 'Delete',
                            ),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
