import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/shared/widgets/variant_grid_editor.dart';

const _uuid = Uuid();

// --- Models used only within this screen ---

class _Attribute {
  String name;
  final TextEditingController nameController;
  List<String> options;
  final TextEditingController optionInputController;

  _Attribute()
      : name = '',
        nameController = TextEditingController(),
        options = [],
        optionInputController = TextEditingController();

  void dispose() {
    nameController.dispose();
    optionInputController.dispose();
  }
}

// --- Provider for saving ---
// Using local setState for UI saving states

class AddItemGroupScreen extends ConsumerStatefulWidget {
  const AddItemGroupScreen({super.key});

  @override
  ConsumerState<AddItemGroupScreen> createState() => _AddItemGroupScreenState();
}

class _AddItemGroupScreenState extends ConsumerState<AddItemGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _isSaving = false;

  final List<_Attribute> _attributes = [];
  List<VariantRowData> _variants = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (final a in _attributes) {
      a.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _addAttribute() {
    setState(() => _attributes.add(_Attribute()));
    _regenerateVariants();
  }

  void _removeAttribute(int index) {
    setState(() {
      _attributes[index].dispose();
      _attributes.removeAt(index);
    });
    _regenerateVariants();
  }

  void _addOption(_Attribute attr) {
    final text = attr.optionInputController.text.trim();
    if (text.isNotEmpty && !attr.options.contains(text)) {
      setState(() => attr.options.add(text));
      attr.optionInputController.clear();
      _regenerateVariants();
    }
  }

  void _removeOption(_Attribute attr, String option) {
    setState(() => attr.options.remove(option));
    _regenerateVariants();
  }

  void _regenerateVariants() {
    // Dispose old variants
    for (final v in _variants) v.dispose();

    // Build permutations
    final validAttrs = _attributes
        .where((a) => a.nameController.text.trim().isNotEmpty && a.options.isNotEmpty)
        .toList();

    if (validAttrs.isEmpty) {
      setState(() => _variants = []);
      return;
    }

    List<Map<String, String>> permutations = [{}];
    for (final attr in validAttrs) {
      final attrName = attr.nameController.text.trim();
      permutations = [
        for (final perm in permutations)
          for (final opt in attr.options)
            {...perm, attrName: opt},
      ];
    }

    setState(() => _variants = permutations.map((p) => VariantRowData(p)).toList());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_variants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one attribute with options to generate variants.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = ref.read(currentUserProfileProvider).value;
      final tenantId = profile?.tenantId ?? '';
      final branchId = ref.read(currentBranchIdProvider) ?? '';
      final repo = ref.read(repositoryProvider);

      // 1. Create the item group
      final attributeNames = _attributes
          .map((a) => a.nameController.text.trim())
          .where((n) => n.isNotEmpty)
          .toList();

      final group = ItemGroup(
        id: _uuid.v4(),
        tenantId: tenantId,
        branchId: branchId,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        attributes: attributeNames,
      );
      await repo.createItemGroup(group);

      // 2. Create a product per variant
      for (final variant in _variants) {
        final costPrice = double.tryParse(variant.costController.text) ?? 0.0;
        final price = double.tryParse(variant.priceController.text) ?? 0.0;
        final sku = variant.skuController.text.trim();
        // Variant name: "Group Name - Size: M, Color: Red"
        final variantLabel = variant.attributes.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        final product = Product(
          id: _uuid.v4(),
          tenantId: tenantId,
          branchId: branchId,
          itemGroupId: group.id,
          name: '${group.name} - $variantLabel',
          sku: sku.isEmpty ? null : sku,
          basePrice: price,
          costPrice: costPrice,
          productType: 'standard',
          variantOptions: variant.attributes,
          isService: false,
        );
        await repo.createProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Item group created with ${_variants.length} variants.'),
            backgroundColor: AppTokens.brandSecondary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Theme.of(context).colorScheme.error),
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
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: isSaving ? null : _save,
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Group'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 20, vertical: 24),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildLeftPanel(theme, cs)),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: _buildRightPanel(theme, cs)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftPanel(theme, cs),
                        const SizedBox(height: 24),
                        _buildRightPanel(theme, cs),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLeftPanel(ThemeData theme, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Group Details',
          icon: PhosphorIconsDuotone.folder,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Group Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Attributes',
          icon: PhosphorIconsDuotone.tag,
          trailing: TextButton.icon(
            onPressed: _addAttribute,
            icon: const Icon(PhosphorIconsBold.plus, size: 16),
            label: const Text('Add Attribute'),
          ),
          children: [
            if (_attributes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'No attributes yet.\nPress "Add Attribute" to define variants like Size or Color.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
            ...List.generate(_attributes.length, (i) => _buildAttributeEditor(_attributes[i], i, theme, cs)),
          ],
        ),
      ],
    );
  }

  Widget _buildAttributeEditor(_Attribute attr, int index, ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: attr.nameController,
                  decoration: InputDecoration(
                    labelText: 'Attribute Name (e.g. Size)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => _regenerateVariants(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeAttribute(index),
                icon: const Icon(PhosphorIconsBold.trash, size: 18),
                color: cs.error,
                tooltip: 'Remove attribute',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Options Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: attr.optionInputController,
                  decoration: InputDecoration(
                    hintText: 'Add option (e.g. Small)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixIcon: IconButton(
                      onPressed: () => _addOption(attr),
                      icon: const Icon(PhosphorIconsBold.plus, size: 16),
                    ),
                  ),
                  onSubmitted: (_) => _addOption(attr),
                ),
              ),
            ],
          ),
          if (attr.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: attr.options.map((opt) {
                return Chip(
                  label: Text(opt),
                  deleteIcon: const Icon(PhosphorIconsBold.x, size: 14),
                  onDeleted: () => _removeOption(attr, opt),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRightPanel(ThemeData theme, ColorScheme cs) {
    return _SectionCard(
      title: 'Variant Matrix',
      icon: PhosphorIconsDuotone.gridFour,
      trailing: _variants.isNotEmpty
          ? Text(
              '${_variants.length} variants',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            )
          : null,
      children: [
        if (_variants.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  PhosphorIcon(PhosphorIconsDuotone.gridFour, size: 48, color: cs.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Add attributes with options to\nauto-generate variants here.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else ...[
          VariantGridEditor(
            variants: _variants,
            showStockColumn: false, // Groups don't define stock directly
            onCopyToAll: () {
              if (_variants.isEmpty) return;
              final firstPrice = _variants.first.priceController.text;
              final firstCost = _variants.first.costController.text;
              if (firstPrice.isNotEmpty || firstCost.isNotEmpty) {
                setState(() {
                  for (var i = 1; i < _variants.length; i++) {
                    _variants[i].priceController.text = firstPrice;
                    _variants[i].costController.text = firstCost;
                  }
                });
              }
            },
          ),
        ],
      ],
    );
  }
} // End of State class

// ─── Shared widget ─────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
