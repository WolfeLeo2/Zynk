import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/adjustment_reason.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'batch_group_action_sheet.dart';

class BatchStockUpdateSheet extends ConsumerStatefulWidget {
  final ItemGroup group;
  final List<Product>? initialItems;

  const BatchStockUpdateSheet({
    super.key,
    required this.group,
    this.initialItems,
  });

  @override
  ConsumerState<BatchStockUpdateSheet> createState() =>
      _BatchStockUpdateSheetState();
}

class _BatchStockUpdateSheetState extends ConsumerState<BatchStockUpdateSheet> {
  final _qtyController = TextEditingController();
  final _referenceController = TextEditingController();
  String _mode = 'add'; // 'set' | 'add' | 'subtract'

  AdjustmentReason? _selectedReason;
  Branch? _selectedBranch;

  @override
  void dispose() {
    _qtyController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final reasonsAsync = ref.watch(adjustmentReasonsProvider);
    final branchesAsync = ref.watch(branchesProvider);
    final currentBranchId = ref.watch(currentBranchIdProvider);

    // Auto-select branch if not set:
    // 1. If tenant only has one branch, select it automatically.
    // 2. If current branch is specific (not 'all'), select it.
    if (_selectedBranch == null) {
      branchesAsync.whenData((branches) {
        final selectable = branches.where((b) => b.id != 'all').toList();
        Branch? toSelect;

        if (selectable.length == 1) {
          toSelect = selectable.first;
        } else if (currentBranchId != 'all') {
          toSelect = selectable
              .where((b) => b.id == currentBranchId)
              .firstOrNull;
        }

        if (toSelect != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedBranch == null) {
              setState(() => _selectedBranch = toSelect);
            }
          });
        }
      });
    }

    return BatchGroupActionSheet(
      group: widget.group,
      initialItems: widget.initialItems,
      title: 'Adjust Stock',
      actionLabel: 'Confirm Stock',
      configBuilder: (context, setSheetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            branchesAsync.when(
              data: (branches) {
                final selectableBranches = branches
                    .where((b) => b.id != 'all')
                    .toList();

                // If only one branch, don't show the selector (it's auto-selected anyway)
                if (selectableBranches.length <= 1)
                  return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<Branch>(
                    decoration: const InputDecoration(
                      labelText: 'Target Branch',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: PhosphorIcon(
                        PhosphorIconsRegular.storefront,
                        size: 20,
                      ),
                    ),
                    initialValue: _selectedBranch,
                    items: selectableBranches
                        .map(
                          (b) =>
                              DropdownMenuItem(value: b, child: Text(b.name)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedBranch = val);
                      setSheetState(() {});
                    },
                  ),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const Text('Error loading branches'),
            ),
            // Adjuster is the logged-in staffer (set on submit); no picker.
            reasonsAsync.when(
              data: (reasons) => DropdownButtonFormField<AdjustmentReason>(
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                initialValue: _selectedReason,
                items: reasons
                    .map(
                      (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedReason = val),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const Text('Error loading reasons'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'add', label: Text('Add')),
                ButtonSegment(value: 'subtract', label: Text('Subtract')),
                ButtonSegment(value: 'set', label: Text('Set to')),
              ],
              selected: {_mode},
              onSelectionChanged: (val) {
                setState(() => _mode = val.first);
                setSheetState(() {});
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _mode == 'set' ? 'New Quantity' : 'Amount',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      itemTrailingBuilder: (context, product, isSelected) {
        if (_selectedBranch == null) {
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Select branch',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          );
        }

        final stockAsync = ref.watch(
          stockByBranchProvider((
            productId: product.id,
            branchId: _selectedBranch?.id,
          )),
        );
        final currentStock = stockAsync.value?.quantity ?? 0;
        final amount = int.tryParse(_qtyController.text) ?? 0;

        int newStock;
        if (_mode == 'add') {
          newStock = currentStock + amount;
        } else if (_mode == 'subtract') {
          newStock = currentStock - amount;
        } else {
          newStock = amount;
        }

        final delta = newStock - currentStock;
        final color = delta > 0
            ? Colors.green
            : delta < 0
            ? theme.colorScheme.error
            : theme.colorScheme.onSurface;

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                '$currentStock',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
              if (isSelected && amount != 0) ...[
                const SizedBox(width: 8),
                PhosphorIcon(
                  PhosphorIconsRegular.arrowRight,
                  size: 12,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  '$newStock',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      onConfirm: (selectedIds) async {
        if (_selectedReason == null) {
          throw 'Please select a reason for adjustment';
        }

        final repo = ref.read(repositoryProvider);
        final tenantId = ref.read(tenantIdProvider) ?? '';
        final branchId = _selectedBranch?.id ?? '';
        final profile = ref.read(currentProfileProvider);
        final amount = int.tryParse(_qtyController.text) ?? 0;

        if (branchId.isEmpty) {
          throw 'Please select a branch first';
        }

        final items = <BatchAdjustmentItem>[];
        for (final id in selectedIds) {
          int quantityChange;
          if (_mode == 'set') {
            // We need current stock to calculate delta for 'set'
            // In a batch update, it's safer to let the repo handle the delta calculation
            // but the current batchAdjustStock expects quantityChange.
            // For now, we'll fetch current stock for each.
            final current = await repo.getProductStockValue(id, branchId);
            quantityChange = amount - current;
          } else if (_mode == 'add') {
            quantityChange = amount;
          } else {
            quantityChange = -amount;
          }

          if (quantityChange != 0) {
            items.add(
              BatchAdjustmentItem(
                productId: id,
                quantityChange: quantityChange,
              ),
            );
          }
        }

        if (items.isEmpty) return;

        await repo.batchAdjustStock(
          tenantId: tenantId,
          branchId: branchId,
          items: items,
          createdBy: profile?.userId ?? '',
          salespersonId: profile?.id,
          adjustmentType: 'auto',
          reasonId: _selectedReason?.id,
          referenceNumber: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock adjustments created')),
          );
        }
      },
    );
  }
}
