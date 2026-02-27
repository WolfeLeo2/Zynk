import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/providers/app_providers.dart';

class AdjustStockSheet extends ConsumerStatefulWidget {
  final Product product;

  const AdjustStockSheet({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AdjustStockSheet(product: product),
      ),
    );
  }

  @override
  ConsumerState<AdjustStockSheet> createState() => _AdjustStockSheetState();
}

class _AdjustStockSheetState extends ConsumerState<AdjustStockSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();
  String _adjustmentType = 'addition';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _adjustmentTypes = [
    {
      'value': 'addition',
      'label': 'Add Stock',
      'icon': PhosphorIconsRegular.plusCircle,
      'color': Colors.green,
    },
    {
      'value': 'reduction',
      'label': 'Remove Stock',
      'icon': PhosphorIconsRegular.minusCircle,
      'color': Colors.orange,
    },
    {
      'value': 'damage',
      'label': 'Report Damage',
      'icon': PhosphorIconsRegular.warningCircle,
      'color': Colors.red,
    },
  ];

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final quantity = int.parse(_quantityController.text);
      final profile = ref.read(currentProfileProvider);
      if (profile == null) throw Exception('Profile not loaded');

      final selectedBranchId = ref.read(currentBranchIdProvider);
      if (selectedBranchId == null)
        throw Exception('No branch selected. Please select a branch first.');

      final repo = ref.read(repositoryProvider);

      int quantityChange = quantity;
      if (_adjustmentType == 'reduction' || _adjustmentType == 'damage') {
        quantityChange = -quantity;
      }

      await repo.adjustStock(
        tenantId: profile.tenantId,
        branchId: selectedBranchId,
        productId: widget.product.id,
        adjustmentType: _adjustmentType,
        quantityChange: quantityChange,
        createdBy: profile.userId,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock updated successfully!')),
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Adjust Stock',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(PhosphorIconsRegular.x),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.product.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 32),

            // Adjustment Type Selection
            Text(
              'Adjustment Type',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _adjustmentTypes.map((type) {
                final isSelected = _adjustmentType == type['value'];
                final typeColor = type['color'] as Color;

                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        type['icon'] as IconData,
                        size: 16,
                        color: isSelected ? colorScheme.onPrimary : typeColor,
                      ),
                      const SizedBox(width: 6),
                      Text(type['label'] as String),
                    ],
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _adjustmentType = type['value'] as String);
                    }
                  },
                  selectedColor: typeColor,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Quantity Input
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter absolute amount (e.g. 5)',
                prefixIcon: const Icon(PhosphorIconsRegular.hash),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                final num = int.tryParse(val);
                if (num == null || num <= 0) return 'Must be > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Notes Input
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Reason for adjustment...',
                prefixIcon: const Icon(PhosphorIconsRegular.textAa),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            // Submit Button
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
              label: Text(_isLoading ? 'Saving...' : 'Confirm Adjustment'),
            ),
          ],
        ),
      ),
    );
  }
}
