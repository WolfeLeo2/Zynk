import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/widgets/product_selection_sheet.dart';
import 'package:zynk/features/products/presentation/widgets/mismatch_resolution_sheet.dart';

class AddItemGroupScreen extends ConsumerStatefulWidget {
  const AddItemGroupScreen({super.key});

  @override
  ConsumerState<AddItemGroupScreen> createState() => _AddItemGroupScreenState();
}

class _AddItemGroupScreenState extends ConsumerState<AddItemGroupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _commissionValueController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _buyingPriceController = TextEditingController();
  final _coverageController = TextEditingController();

  String _commissionType = 'none';
  String _pricingUnit = 'piece';

  Set<String> _assignedProductIds = {};

  bool _isSaving = false;

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

  Future<void> _selectProducts() async {
    final products = ref.read(allProductsProvider).value ?? [];

    final selectedIds = await ProductSelectionSheet.show(
      context,
      availableProducts: products,
      initiallySelectedIds: _assignedProductIds,
    );

    if (selectedIds != null && mounted) {
      setState(() {
        _assignedProductIds = selectedIds;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = ref.read(currentUserProfileProvider).value;
    final tenantId = profile?.tenantId ?? '';
    final branchId = ref.read(currentBranchIdProvider) ?? '';

    if (tenantId.isEmpty || branchId.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final repo = ref.read(repositoryProvider);

      final commissionValue = double.tryParse(_commissionValueController.text);
      final sellingPrice = double.tryParse(_sellingPriceController.text);
      final buyingPrice = double.tryParse(_buyingPriceController.text);
      final coverage = double.tryParse(_coverageController.text);

      final groupId = const Uuid().v4();
      final group = ItemGroup(
        id: groupId,
        tenantId: tenantId,
        branchId: branchId,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        defaultCommissionType: _commissionType == 'none'
            ? null
            : _commissionType,
        defaultCommissionValue: _commissionType == 'none'
            ? null
            : commissionValue,
        defaultSellingPrice: sellingPrice,
        defaultBuyingPrice: buyingPrice,
        defaultPricingUnit: _pricingUnit,
        defaultCoveragePerBox: _pricingUnit == 'sqm' ? coverage : null,
      );

      // Handle product assignment mismatches before saving group
      Map<String, bool>? resolutionDecisions = {};
      final products = ref.read(allProductsProvider).value ?? [];
      final assignedProducts = products
          .where((p) => _assignedProductIds.contains(p.id))
          .toList();

      if (assignedProducts.isNotEmpty) {
        final mismatchedProducts = assignedProducts
            .where(
              (p) =>
                  p.pricingUnit != group.defaultPricingUnit ||
                  p.coveragePerBox != group.defaultCoveragePerBox ||
                  p.basePrice != group.defaultSellingPrice ||
                  p.costPrice != group.defaultBuyingPrice,
            )
            .toList();

        if (mismatchedProducts.isNotEmpty) {
          resolutionDecisions = await MismatchResolutionSheet.show(
            context,
            targetGroup: group,
            mismatchedProducts: mismatchedProducts,
          );

          if (resolutionDecisions == null) {
            // User canceled the assignment process
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      // 1. Create the Group
      await repo.createItemGroup(group);

      // 2. Assign and normalize products
      for (final p in assignedProducts) {
        final normalize = resolutionDecisions[p.id] ?? true;
        var updatedProduct = p.copyWith(itemGroupId: groupId);

        if (normalize) {
          updatedProduct = updatedProduct.copyWith(
            pricingUnit: group.defaultPricingUnit,
            coveragePerBox: group.defaultCoveragePerBox,
            basePrice: group.defaultSellingPrice,
            costPrice: group.defaultBuyingPrice,
          );
        }
        await repo.updateProduct(updatedProduct);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item group created successfully.')),
        );
        context.pop();
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSaving = _isSaving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Item Group'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: isSaving ? null : _save,
              child: isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailsSection(theme, cs),
              Divider(
                height: 48,
                thickness: 1,
                color: cs.outlineVariant.withAlpha(50),
              ),
              _buildPricingSection(theme, cs),
              Divider(
                height: 48,
                thickness: 1,
                color: cs.outlineVariant.withAlpha(50),
              ),
              _buildCommissionSection(theme, cs),
              Divider(
                height: 48,
                thickness: 1,
                color: cs.outlineVariant.withAlpha(50),
              ),
              _buildAssignmentSection(theme, cs),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsSection(ThemeData theme, ColorScheme cs) {
    return _SectionCard(
      title: 'Group Details',
      icon: PhosphorIconsDuotone.folder,
      children: [
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name *',
            border: OutlineInputBorder(),
          ),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildPricingSection(ThemeData theme, ColorScheme cs) {
    return _SectionCard(
      title: 'Pricing Model',
      icon: PhosphorIconsDuotone.currencyCircleDollar,
      children: [
        DropdownButtonFormField<String>(
          value: _pricingUnit,
          decoration: const InputDecoration(
            labelText: 'Pricing Unit',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'piece', child: Text('Per Piece / Unit')),
            DropdownMenuItem(value: 'sqm', child: Text('Per Sqm (Coverage)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _pricingUnit = val);
          },
        ),
        if (_pricingUnit == 'sqm') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _coverageController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Coverage per Box (sqm)',
              hintText: 'e.g. 1.44',
              border: OutlineInputBorder(),
            ),
            validator: (val) {
              if (_pricingUnit == 'sqm' && (val == null || val.isEmpty)) {
                return 'Required for sqm pricing';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          controller: _sellingPriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Default Selling Price',
            hintText: 'e.g. 500',
            border: OutlineInputBorder(),
            prefixText: 'KES ',
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _buyingPriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Default Buying Price',
            hintText: 'e.g. 350',
            border: OutlineInputBorder(),
            prefixText: 'KES ',
          ),
        ),
      ],
    );
  }

  Widget _buildCommissionSection(ThemeData theme, ColorScheme cs) {
    return _SectionCard(
      title: 'Commission',
      icon: PhosphorIconsDuotone.percent,
      children: [
        Text(
          'Earned by staff when any item in this group is sold.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _commissionType,
          decoration: const InputDecoration(
            labelText: 'Commission Type',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('None')),
            DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount (KES)')),
            DropdownMenuItem(
              value: 'percentage',
              child: Text('Percentage (%)'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _commissionType = val);
          },
        ),
        if (_commissionType != 'none') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _commissionValueController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: _commissionType == 'percentage'
                  ? 'Commission Rate (%)'
                  : 'Commission Amount (KES)',
              hintText: _commissionType == 'percentage' ? 'e.g. 5' : 'e.g. 100',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAssignmentSection(ThemeData theme, ColorScheme cs) {
    return _SectionCard(
      title: 'Assign Products',
      icon: PhosphorIconsDuotone.package,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_assignedProductIds.length} Products Assigned',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _selectProducts,
              icon: const PhosphorIcon(PhosphorIconsRegular.plus),
              label: const Text('Assign Items'),
            ),
          ],
        ),
        if (_assignedProductIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Assigned products will inherit the group defaults unless preserved during conflict resolution.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final PhosphorIconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PhosphorIcon(icon, size: 22, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...children,
      ],
    );
  }
}
