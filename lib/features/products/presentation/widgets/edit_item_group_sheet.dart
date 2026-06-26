import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/utils/responsive_modal.dart';

class EditItemGroupSheet extends ConsumerStatefulWidget {
  final ItemGroup? existingGroup;
  final String? defaultBranchId;

  const EditItemGroupSheet({
    super.key,
    this.existingGroup,
    this.defaultBranchId,
  });

  static Future<ItemGroup?> show(
    BuildContext context, {
    ItemGroup? existingGroup,
    String? defaultBranchId,
  }) {
    return showResponsiveModal<ItemGroup>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => EditItemGroupSheet(
        existingGroup: existingGroup,
        defaultBranchId: defaultBranchId,
      ),
    );
  }

  @override
  ConsumerState<EditItemGroupSheet> createState() => _EditItemGroupSheetState();
}

class _EditItemGroupSheetState extends ConsumerState<EditItemGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _commissionValueController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _buyingPriceController;
  late final TextEditingController _coverageController;

  String _commissionType = 'none';
  String _pricingUnit = 'piece';

  @override
  void initState() {
    super.initState();
    final g = widget.existingGroup;
    _nameController = TextEditingController(text: g?.name ?? '');
    _descController = TextEditingController(text: g?.description ?? '');

    _commissionType = g?.defaultCommissionType ?? 'none';
    _commissionValueController = TextEditingController(
      text: g?.defaultCommissionValue?.toString() ?? '',
    );
    _sellingPriceController = TextEditingController(
      text: g?.defaultSellingPrice?.toString() ?? '',
    );
    _buyingPriceController = TextEditingController(
      text: g?.defaultBuyingPrice?.toString() ?? '',
    );

    _pricingUnit = g?.defaultPricingUnit ?? 'piece';
    _coverageController = TextEditingController(
      text: g?.defaultCoveragePerBox?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _commissionValueController.dispose();
    _sellingPriceController.dispose();
    _buyingPriceController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
          top: 32,
          left: 24,
          right: 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingGroup == null
                    ? 'New Item Group'
                    : 'Edit Item Group',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                autofocus: widget.existingGroup == null,
                decoration: const InputDecoration(
                  labelText: 'Group Name *',
                  hintText: 'e.g. Beverages',
                  border: OutlineInputBorder(),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Short description of this group',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Pricing Model',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _pricingUnit,
                      decoration: const InputDecoration(
                        labelText: 'Pricing Unit',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'piece',
                          child: Text('Per Piece / Unit'),
                        ),
                        DropdownMenuItem(
                          value: 'sqm',
                          child: Text('Per Sqm (Coverage)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _pricingUnit = val);
                        }
                      },
                    ),
                  ),
                  if (_pricingUnit == 'sqm') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _coverageController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Coverage per Box (sqm)',
                          hintText: 'e.g. 1.44',
                          border: OutlineInputBorder(),
                        ),
                        validator: (val) {
                          if (_pricingUnit == 'sqm' &&
                              (val == null || val.isEmpty)) {
                            return 'Required for sqm';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _sellingPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Default Selling Price',
                        hintText: 'e.g. 500',
                        border: OutlineInputBorder(),
                        prefixText: 'KES ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _buyingPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Default Buying Price',
                        hintText: 'e.g. 350',
                        border: OutlineInputBorder(),
                        prefixText: 'KES ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Commission', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                'Earned by staff when any item in this group is sold.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _commissionType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(
                          value: 'fixed',
                          child: Text('Fixed Amount'),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _commissionValueController,
                      keyboardType: TextInputType.number,
                      enabled: _commissionType != 'none',
                      decoration: InputDecoration(
                        labelText: _commissionType == 'percentage'
                            ? 'Rate (%)'
                            : 'Amount',
                        hintText: _commissionType == 'percentage'
                            ? 'e.g. 5'
                            : 'e.g. 100',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveGroup,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.existingGroup == null
                        ? 'Create Group'
                        : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveGroup() async {
    debugPrint('[EditItemGroupSheet] _saveGroup() called');

    final isValid = _formKey.currentState!.validate();
    debugPrint('[EditItemGroupSheet] Form valid: $isValid');
    if (!isValid) return;

    final repo = ref.read(repositoryProvider);
    final tenantId = ref.read(tenantIdProvider);
    // Groups are global — branchId is intentionally null.
    // We do NOT gate on branchId here.
    debugPrint(
      '[EditItemGroupSheet] tenantId=$tenantId, existingGroup=${widget.existingGroup?.id}',
    );

    if (tenantId == null) {
      debugPrint('[EditItemGroupSheet] ❌ tenantId is null — aborting save');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Not logged in to a tenant.')),
        );
      }
      return;
    }

    final commissionValue = double.tryParse(_commissionValueController.text);
    final sellingPrice = double.tryParse(_sellingPriceController.text);
    final buyingPrice = double.tryParse(_buyingPriceController.text);
    final coverage = double.tryParse(_coverageController.text);

    debugPrint(
      '[EditItemGroupSheet] pricingUnit=$_pricingUnit, coverage=$coverage, sellingPrice=$sellingPrice',
    );

    final group = ItemGroup(
      id: widget.existingGroup?.id ?? const Uuid().v4(),
      tenantId: tenantId,
      branchId: null, // Groups are always tenant-wide
      name: _nameController.text.trim(),
      description: _descController.text.isEmpty
          ? null
          : _descController.text.trim(),
      defaultCommissionType: _commissionType == 'none' ? null : _commissionType,
      defaultCommissionValue: _commissionType == 'none'
          ? null
          : commissionValue,
      defaultSellingPrice: sellingPrice,
      defaultBuyingPrice: buyingPrice,
      defaultPricingUnit: _pricingUnit,
      defaultCoveragePerBox: _pricingUnit == 'sqm' ? coverage : null,
      createdAt: widget.existingGroup?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      if (widget.existingGroup == null) {
        debugPrint('[EditItemGroupSheet] Creating new group: ${group.name}');
        await repo.createItemGroup(group);
        debugPrint('[EditItemGroupSheet] ✅ Group created successfully');
      } else {
        debugPrint('[EditItemGroupSheet] Updating group: ${group.id}');
        await repo.updateItemGroup(group);
        debugPrint('[EditItemGroupSheet] ✅ Group updated successfully');
      }

      if (mounted) {
        Navigator.pop(context, group);
      }
    } catch (e, stack) {
      debugPrint('[EditItemGroupSheet] ❌ Error saving group: $e');
      debugPrint(stack.toString());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    }
  }
}
