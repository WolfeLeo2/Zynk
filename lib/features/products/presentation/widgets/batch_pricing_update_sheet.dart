import 'package:button_group_m3e/button_group_m3e.dart';
import 'package:button_m3e/button_m3e.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/utils/currency.dart';

import 'batch_group_action_sheet.dart';

class BatchPricingUpdateSheet extends ConsumerStatefulWidget {
  final ItemGroup group;
  final List<Product>? initialItems;
  final ItemGroup? groupToUpdate;
  final double? oldPrice;

  const BatchPricingUpdateSheet({
    super.key,
    required this.group,
    this.initialItems,
    this.groupToUpdate,
    this.oldPrice,
  });

  @override
  ConsumerState<BatchPricingUpdateSheet> createState() =>
      _BatchPricingUpdateSheetState();
}

class _BatchPricingUpdateSheetState
    extends ConsumerState<BatchPricingUpdateSheet> {
  bool _useInheritance = true;
  final _manualPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.group.defaultSellingPrice != null) {
      _manualPriceController.text = widget.group.defaultSellingPrice!
          .toString();
    }
  }

  @override
  void dispose() {
    _manualPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final inheritedPrice = widget.group.defaultSellingPrice ?? 0.0;

    return BatchGroupActionSheet(
      group: widget.group,
      initialItems: widget.initialItems,
      title: 'Update Pricing',
      actionLabel: 'Update Prices',
      configBuilder: (context, setSheetState) {
        return Column(
          children: [
            ButtonGroupM3E(
              selection: true,
              overflow: ButtonGroupM3EOverflow.none,
              type: ButtonGroupM3EType.connected,
              style: ButtonM3EStyle.filled,
              expanded: true,
              size: ButtonGroupM3ESize.md,
              selectedIndex: _useInheritance ? 0 : 1,
              actions: [
                ButtonGroupM3EAction(
                  label: const Text('Adopt Price'),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.treeStructure,
                    size: 18,
                  ),
                  style: _useInheritance ? ButtonM3EStyle.tonal : null,
                  onPressed: () {
                    setState(() => _useInheritance = true);
                    setSheetState(() {});
                  },
                ),
                ButtonGroupM3EAction(
                  label: const Text('Manual Price'),
                  icon: const PhosphorIcon(
                    PhosphorIconsRegular.pencilSimple,
                    size: 18,
                  ),
                  style: !_useInheritance ? ButtonM3EStyle.tonal : null,
                  onPressed: () {
                    setState(() => _useInheritance = false);
                    setSheetState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                // Slide from right to left if switching to manual (false), else left to right
                final isManual = child.key == const ValueKey(false);
                final offsetAnimation =
                    Tween<Offset>(
                      begin: Offset(isManual ? 1.0 : -1.0, 0.0),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      ),
                    );

                return SlideTransition(
                  position: offsetAnimation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: _useInheritance
                  ? Container(
                      key: const ValueKey(true),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          PhosphorIcon(
                            PhosphorIconsDuotone.info,
                            color: cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Items will use the group price (${CurrencyHelper.format(inheritedPrice)}) and react to future group updates.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: cs.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : TextField(
                      key: const ValueKey(false),
                      controller: _manualPriceController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'New Fixed Price',
                        prefixText: 'KES ',
                        helperText:
                            'This will override the group default for selected items.',
                        border: OutlineInputBorder(),
                      ),
                    ),
            ),
          ],
        );
      },
      infoBox: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            PhosphorIcon(
              PhosphorIconsRegular.info,
              size: 16,
              color: cs.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Note: Deselected items will maintain their current setup. If they have no override, they will follow the new group price.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
      itemTrailingBuilder: (context, item, isSelected) {
        final currentPrice =
            item.basePrice ?? widget.group.defaultSellingPrice ?? 0.0;
        final targetPrice = _useInheritance
            ? inheritedPrice
            : (double.tryParse(_manualPriceController.text) ?? currentPrice);
        final isDifferent = isSelected && currentPrice != targetPrice;

        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                CurrencyHelper.format(currentPrice),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDifferent ? cs.onSurfaceVariant : cs.primary,
                  decoration: isDifferent ? TextDecoration.lineThrough : null,
                ),
              ),
              if (isDifferent) ...[
                const SizedBox(width: 8),
                const PhosphorIcon(PhosphorIconsRegular.arrowRight, size: 12),
                const SizedBox(width: 8),
                Text(
                  CurrencyHelper.format(targetPrice),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        );
      },
      onConfirm: (selectedIds) async {
        final repo = ref.read(repositoryProvider);
        final ids = selectedIds.toList();
        final manualPrices = <String, double>{};
        final adoptGroupIds = <String>[];

        if (_useInheritance) {
          adoptGroupIds.addAll(ids);
        } else {
          final price = double.tryParse(_manualPriceController.text);
          if (price != null) {
            for (final id in ids) {
              manualPrices[id] = price;
            }
          }
        }

        // THE FREEZE LOGIC
        if (widget.oldPrice != null && widget.initialItems != null) {
          for (final p in widget.initialItems!) {
            if (!selectedIds.contains(p.id) && p.basePrice == null) {
              manualPrices[p.id] = widget.oldPrice!;
            }
          }
        }

        await repo.batchUpdatePricingAndGroup(
          adoptGroupIds: adoptGroupIds,
          manualPrices: manualPrices,
          updatedGroup: widget.groupToUpdate,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prices updated successfully')),
          );
        }
      },
    );
  }
}
