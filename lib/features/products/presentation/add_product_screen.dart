import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart'; // Add uuid import
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/core/providers/app_providers.dart'; // for repositoryProvider
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/providers/add_product_controller.dart';
import 'package:zynk/features/products/presentation/scanner_screen.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? existingProduct;

  const AddProductScreen({super.key, this.existingProduct});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _stockController = TextEditingController();
  final _costPriceController = TextEditingController(); // Added
  final _lowStockController =
      TextEditingController(); // Added missing controller

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategoryId;
  String? _selectedItemGroupId;
  String? _selectedUomId;
  final List<CompositeItemComponent> _selectedComponents = [];

  bool _autoGenerateSku = true;
  bool _trackStock = true;
  String? _existingImageUrl;

  // Item Group BottomSheet state
  String _newGroupCommissionType = 'none';
  final _newGroupDescController = TextEditingController();
  final _newGroupCommissionValueController = TextEditingController();

  // Logistics / Dimensions
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  // Variants
  bool _hasVariants = false;
  final Map<String, List<String>> _variantOptions = {};
  final _newVariantNameController = TextEditingController();
  final _newVariantValuesController = TextEditingController();

  String get _productType {
    final type = GoRouterState.of(context).uri.queryParameters['type'];
    return type ?? 'single';
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      final p = widget.existingProduct!;
      _nameController.text = p.name;
      _skuController.text = p.sku ?? '';
      _autoGenerateSku = p.sku == null || p.sku!.isEmpty;
      _barcodeController.text = p.barcode ?? '';
      _priceController.text = p.basePrice.toString();
      if (p.costPrice != null) {
        _costPriceController.text = p.costPrice.toString();
      }
      _selectedCategoryId = p.categoryId;
      _selectedItemGroupId = p.groupId;
      _selectedUomId = p.uomId;
      _existingImageUrl = p.imageUrl;

      // Logistics
      if (p.weight != null) _weightController.text = p.weight.toString();
      if (p.length != null) _lengthController.text = p.length.toString();
      if (p.width != null) _widthController.text = p.width.toString();
      if (p.height != null) _heightController.text = p.height.toString();

      if (p.variantOptions != null && p.variantOptions!.isNotEmpty) {
        _hasVariants = true;
        p.variantOptions!.forEach((key, value) {
          if (value is List) {
            _variantOptions[key] = value.map((e) => e.toString()).toList();
          }
        });
      }

      if (p.isComposite) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(compositeComponentsProvider(p.id).future).then((components) {
            if (mounted) {
              setState(() {
                _selectedComponents.clear();
                _selectedComponents.addAll(components);
              });
            }
          });
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _costPriceController.dispose();
    _lowStockController.dispose();
    _newGroupDescController.dispose();
    _newGroupCommissionValueController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _newVariantNameController.dispose();
    _newVariantValuesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    if (result != null) {
      setState(() {
        _barcodeController.text = result;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select a Category',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (_selectedItemGroupId == null && _productType == 'standard') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select an Item Group',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final price = double.tryParse(_priceController.text) ?? 0.0;
      final costPrice = double.tryParse(_costPriceController.text);

      String skuToSave = _skuController.text;
      if (_autoGenerateSku && skuToSave.isEmpty) {
        skuToSave =
            'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      }

      await ref
          .read(addProductControllerProvider.notifier)
          .saveProduct(
            id: widget.existingProduct?.id,
            existingImageUrl: _existingImageUrl,
            name: _nameController.text,
            categoryId: _selectedCategoryId,
            itemGroupId: _selectedItemGroupId,
            uomId: _selectedUomId,
            productType: _productType,
            price: price,
            costPrice: costPrice,
            weight: double.tryParse(_weightController.text),
            length: double.tryParse(_lengthController.text),
            width: double.tryParse(_widthController.text),
            height: double.tryParse(_heightController.text),
            sku: skuToSave,
            barcode: _barcodeController.text,
            imageFile: _selectedImage,
            initialStock: int.tryParse(_stockController.text),
            components: _productType == 'composite' ? _selectedComponents : null,
            variantOptions: _hasVariants && _productType == 'standard' && _variantOptions.isNotEmpty ? _variantOptions : null,
          );

      if (mounted) {
        final state = ref.read(addProductControllerProvider);
        if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error: ${state.error}',
                style: TextStyle(color: Theme.of(context).colorScheme.onError),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          context.pop(); // Go back to dashboard/pos
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Product Added Successfully!',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildSearchableDropdown<T extends Object>({
    Key? key,
    required String label,
    required PhosphorIconData icon,
    required List<T> items,
    required String Function(T) itemLabel,
    required String Function(T) itemId,
    required String? selectedItemId,
    required void Function(T?) onSelected,
    required VoidCallback onAddPressed,
  }) {
    final theme = Theme.of(context);
    final selectedItem = items.cast<T?>().firstWhere(
      (item) => item != null && itemId(item) == selectedItemId,
      orElse: () => null,
    );

    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Autocomplete<T>(
            displayStringForOption: itemLabel,
            initialValue: selectedItem != null
                ? TextEditingValue(text: itemLabel(selectedItem))
                : const TextEditingValue(),
            optionsBuilder: (TextEditingValue textEditingValue) {
              if (textEditingValue.text.isEmpty) {
                return items;
              }
              return items.where((T option) {
                return itemLabel(
                  option,
                ).toLowerCase().contains(textEditingValue.text.toLowerCase());
              });
            },
            onSelected: onSelected,
            fieldViewBuilder:
                (
                  BuildContext context,
                  TextEditingController fieldTextEditingController,
                  FocusNode fieldFocusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  return TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(icon),
                      suffixIcon: selectedItem != null
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                fieldTextEditingController.clear();
                                onSelected(null);
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) {
                      if (selectedItem != null &&
                          val != itemLabel(selectedItem)) {
                        onSelected(null);
                      }
                    },
                  );
                },
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 56, // Fixed height to match TextField
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            onPressed: onAddPressed,
            icon: Icon(
              PhosphorIconsBold.plus,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            tooltip: 'Add New $label',
          ),
        ),
      ],
    );
  }

  Future<void> _showAddCategoryDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Footwear',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final repo = ref.read(repositoryProvider);
                final tenantId = ref.read(tenantIdProvider);
                final branchId = ref.read(currentBranchIdProvider);

                if (tenantId != null && branchId != null && branchId != 'all') {
                  await repo.createCategory(
                    Category(
                      id: const Uuid().v4(),
                      tenantId: tenantId,
                      branchId: branchId,
                      name: controller.text,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddGroupBottomSheet() async {
    final nameController = TextEditingController();
    _newGroupDescController.clear();
    _newGroupCommissionValueController.clear();
    setState(() => _newGroupCommissionType = 'none');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 32,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Item Group',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Group Name *',
                  hintText: 'e.g. Beverages',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newGroupDescController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Short description of this group',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Commission',
                style: Theme.of(context).textTheme.labelLarge,
              ),
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
                      value: _newGroupCommissionType,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('None')),
                        DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount')),
                        DropdownMenuItem(value: 'percent', child: Text('Percentage')),
                      ],
                      onChanged: (val) {
                        setModalState(() => _newGroupCommissionType = val ?? 'none');
                        setState(() => _newGroupCommissionType = val ?? 'none');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _newGroupCommissionValueController,
                      keyboardType: TextInputType.number,
                      enabled: _newGroupCommissionType != 'none',
                      decoration: InputDecoration(
                        labelText: _newGroupCommissionType == 'percent' ? 'Rate (%)' : 'Amount',
                        hintText: _newGroupCommissionType == 'percent' ? 'e.g. 5' : 'e.g. 100',
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
                  onPressed: () async {
                    if (nameController.text.isEmpty) return;
                    final repo = ref.read(repositoryProvider);
                    final tenantId = ref.read(tenantIdProvider);
                    final branchId = ref.read(currentBranchIdProvider);

                    if (tenantId != null && branchId != null && branchId != 'all') {
                      final commissionValue = double.tryParse(
                        _newGroupCommissionValueController.text,
                      );
                      final newGroup = ItemGroup(
                        id: const Uuid().v4(),
                        tenantId: tenantId,
                        branchId: branchId,
                        name: nameController.text,
                        description: _newGroupDescController.text.isEmpty
                            ? null
                            : _newGroupDescController.text,
                        defaultCommissionType: _newGroupCommissionType == 'none'
                            ? null
                            : _newGroupCommissionType,
                        defaultCommissionValue: _newGroupCommissionType == 'none'
                            ? null
                            : commissionValue,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      await repo.createItemGroup(newGroup);
                      if (context.mounted) {
                        Navigator.pop(context);
                        setState(() => _selectedItemGroupId = newGroup.id);
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Create Group'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddUomBottomSheet() async {
    final labelController = TextEditingController();
    final abbrController = TextEditingController();
    final factorController = TextEditingController();
    String? baseUnitId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 32,
            left: 24,
            right: 24,
          ),
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('New Unit of Measurement', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 24),
              TextFormField(
                controller: labelController,
                decoration: const InputDecoration(
                  labelText: 'Unit Label (e.g. Box)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: abbrController,
                decoration: const InputDecoration(
                  labelText: 'Abbreviation (e.g. bx)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Conversion (Optional)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Define how many base units make up this unit(ie a Box can be 1X12 meaning 12 items make 1 box).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: factorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Factor',
                        hintText: '10',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('x'),
                  ),
                  Expanded(
                    child: ref.watch(allUomProvider).when(
                          data: (uoms) => DropdownButtonFormField<String>(
                            value: baseUnitId,
                            decoration: const InputDecoration(
                              labelText: 'Base Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: uoms
                                .map((u) => DropdownMenuItem(
                                      value: u.id,
                                      child: Text(u.label),
                                    ))
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => baseUnitId = val),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const Text('Error'),
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (labelController.text.isNotEmpty) {
                      final uom = UnitOfMeasurement(
                        id: const Uuid().v4(),
                        tenantId: ref.read(tenantIdProvider)!,
                        label: labelController.text,
                        abbreviation: abbrController.text,
                        baseUnitId: baseUnitId,
                        conversionFactor:
                            double.tryParse(factorController.text) ?? 1.0,
                      );
                      await ref
                          .read(repositoryProvider)
                          .createUnitOfMeasurement(uom);
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Unit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantsSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        Row(
          children: [
            Icon(PhosphorIconsDuotone.swatches, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Variants',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const Spacer(),
            Switch(
              value: _hasVariants,
              onChanged: (val) => setState(() {
                _hasVariants = val;
                if (!val) _variantOptions.clear();
              }),
            ),
          ],
        ),
        if (_hasVariants) ...[
          const SizedBox(height: 4),
          Text(
            'Define attributes like Size or Color. Each item in the cart will prompt the buyer to choose.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // Existing variant attributes
          if (_variantOptions.isNotEmpty)
            ..._variantOptions.entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: entry.value
                                .map((v) => Chip(
                                      label: Text(v, style: theme.textTheme.bodySmall),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _variantOptions.remove(entry.key)),
                      icon: Icon(PhosphorIconsBold.trash, size: 18, color: theme.colorScheme.error),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            }),

          // Add new attribute row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _newVariantNameController,
                  decoration: const InputDecoration(
                    labelText: 'Attribute (e.g. Size)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _newVariantValuesController,
                  decoration: const InputDecoration(
                    labelText: 'Values (comma-separated)',
                    hintText: 'S, M, L, XL',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {
                    final name = _newVariantNameController.text.trim();
                    final rawVals = _newVariantValuesController.text;
                    if (name.isEmpty || rawVals.isEmpty) return;
                    final values = rawVals
                        .split(',')
                        .map((v) => v.trim())
                        .where((v) => v.isNotEmpty)
                        .toList();
                    if (values.isEmpty) return;
                    setState(() {
                      _variantOptions[name] = values;
                      _newVariantNameController.clear();
                      _newVariantValuesController.clear();
                    });
                  },
                  icon: Icon(PhosphorIconsBold.plus, color: theme.colorScheme.onPrimaryContainer),
                  tooltip: 'Add Attribute',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildCompositeSection() {
    final productsAsync = ref.watch(allProductsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        _buildSectionHeader(
            theme, 'Composite Components', PhosphorIconsDuotone.listChecks),
        const SizedBox(height: 16),
        Text(
          'Select the items that make up this composite item and specify their quantities.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        productsAsync.when(
          data: (products) => _buildSearchableDropdown<Product>(
            key: const ValueKey('comp_items_data'),
            label: 'Add Component Item',
            icon: PhosphorIconsDuotone.plusCircle,
            items: products
                .where((p) =>
                    p.id != widget.existingProduct?.id && !p.isComposite)
                .toList(),
            itemLabel: (p) => p.name,
            itemId: (p) => p.id,
            selectedItemId: null,
            onSelected: (p) {
              if (p != null) {
                if (_selectedComponents
                    .any((c) => c.componentProductId == p.id)) {
                  return;
                }
                setState(() {
                  _selectedComponents.add(CompositeItemComponent(
                    id: const Uuid().v4(),
                    tenantId: ref.read(tenantIdProvider)!,
                    branchId: ref.read(currentBranchIdProvider) ?? '',
                    compositeProductId: widget.existingProduct?.id ?? '',
                    componentProductId: p.id,
                    quantity: 1,
                  ));
                });
              }
            },
            onAddPressed: () {},
          ),
          loading: () => const LinearProgressIndicator(),
          error: (e, s) => Text('Error: $e'),
        ),
        const SizedBox(height: 16),
        if (_selectedComponents.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTokens.textPrimary.withOpacity(0.02),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTokens.textPrimary.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Icon(PhosphorIconsDuotone.package,
                    size: 40, color: AppTokens.textSecondary.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text(
                  'No components added',
                  style: AppTokens.labelLarge
                      .copyWith(color: AppTokens.textSecondary),
                ),
                Text(
                  'Use the search above to add items',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedComponents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final component = _selectedComponents[index];
              final product = productsAsync.value
                  ?.firstWhere((p) => p.id == component.componentProductId);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppTokens.textPrimary.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTokens.electricBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(PhosphorIconsDuotone.package,
                          color: AppTokens.electricBlue, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product?.name ?? 'Unknown',
                              style: AppTokens.labelLarge),
                          Text('SKU: ${product?.sku ?? 'N/A'}',
                              style: AppTokens.bodySmall
                                  .copyWith(color: AppTokens.textSecondary)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTokens.textPrimary.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              if (component.quantity > 1) {
                                setState(() {
                                  _selectedComponents[index] =
                                      component.copyWith(
                                          quantity: component.quantity - 1);
                                });
                              }
                            },
                            icon: const Icon(Icons.remove, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text('${component.quantity}',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _selectedComponents[index] =
                                    component.copyWith(
                                        quantity: component.quantity + 1);
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedComponents.removeAt(index);
                        });
                      },
                      icon: const Icon(PhosphorIconsBold.trash,
                          color: Colors.red, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.existingProduct != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add New Product'),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(PhosphorIconsBold.x),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: _saveProduct,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: Text(isEditing ? 'Save Changes' : 'Save Product'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(
                  theme,
                  'Basic Info',
                  PhosphorIconsDuotone.info,
                ),
                const SizedBox(height: 16),
                _buildStep1(),
                if (_productType == 'composite') _buildCompositeSection(),
                if (_productType == 'standard') _buildVariantsSection(),
                const SizedBox(height: 32),

                _buildSectionHeader(
                  theme,
                  'Pricing & Commission',
                  PhosphorIconsDuotone.currencyCircleDollar,
                ),
                const SizedBox(height: 16),
                _buildStep2(),
                const SizedBox(height: 32),

                _buildSectionHeader(
                  theme,
                  'Inventory & Stock',
                  PhosphorIconsDuotone.package,
                ),
                const SizedBox(height: 16),
                _buildStep3(),
                const SizedBox(height: 48), // bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  // Step 1: Basic Info
  Widget _buildStep1() {
    // Use stable providers defined in product_providers.dart
    final categoriesAsync = ref.watch(allCategoriesProvider);
    final groupsAsync = ref.watch(allItemGroupsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image Picker
        Center(
          child: GestureDetector(
            onTap: () {
              showModalBottomSheet(
                showDragHandle: true,
                context: context,
                backgroundColor: Theme.of(context).colorScheme.surface,
                builder: (context) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const PhosphorIcon(PhosphorIconsDuotone.camera),
                      title: const Text('Take Photo'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                    ListTile(
                      leading: const PhosphorIcon(PhosphorIconsDuotone.image),
                      title: const Text('Choose from Gallery'),
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              );
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                image: _selectedImage != null
                    ? DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      )
                    : (_existingImageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(_existingImageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: (_selectedImage == null && _existingImageUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIconsDuotone.camera,
                          color: Colors.grey[400],
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 24),

        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Product Name',
            hintText: 'e.g. Vintage Denim Jacket',
            border: OutlineInputBorder(),
            prefixIcon: Icon(PhosphorIconsDuotone.tag),
          ),
          validator: (value) =>
              value == null || value.isEmpty ? 'Please enter a name' : null,
        ),
        const SizedBox(height: 16),

        // Categories Dropdown with Create New
        categoriesAsync.when(
          data: (categories) => _buildSearchableDropdown<Category>(
            key: const ValueKey('categories_data'),
            label: 'Category',
            icon: PhosphorIconsDuotone.folders,
            items: categories,
            itemLabel: (c) => c.name,
            itemId: (c) => c.id,
            selectedItemId: _selectedCategoryId,
            onSelected: (c) => setState(() => _selectedCategoryId = c?.id),
            onAddPressed: _showAddCategoryDialog,
          ),
          loading: () => _buildSearchableDropdown<Category>(
            key: const ValueKey('categories_loading'),
            label: 'Category',
            icon: PhosphorIconsDuotone.folders,
            items: const [],
            itemLabel: (c) => c.name,
            itemId: (c) => c.id,
            selectedItemId: _selectedCategoryId,
            onSelected: (c) {},
            onAddPressed: _showAddCategoryDialog,
          ),
          error: (e, s) => Text('Error loading categories: $e'),
        ),

        const SizedBox(height: 16),

        // Item Groups Dropdown with Create New
        groupsAsync.when(
          data: (groups) => _buildSearchableDropdown<ItemGroup>(
            key: const ValueKey('groups_data'),
            label: 'Item Group *',
            icon: PhosphorIconsDuotone.stackSimple,
            items: groups,
            itemLabel: (g) => g.name,
            itemId: (g) => g.id,
            selectedItemId: _selectedItemGroupId,
            onSelected: (g) => setState(() => _selectedItemGroupId = g?.id),
            onAddPressed: _showAddGroupBottomSheet,
          ),
          loading: () => _buildSearchableDropdown<ItemGroup>(
            key: const ValueKey('groups_loading'),
            label: 'Item Group *',
            icon: PhosphorIconsDuotone.stackSimple,
            items: const [],
            itemLabel: (g) => g.name,
            itemId: (g) => g.id,
            selectedItemId: _selectedItemGroupId,
            onSelected: (g) {},
            onAddPressed: _showAddGroupBottomSheet,
          ),
          error: (e, s) => const SizedBox(),
        ),

        const SizedBox(height: 16),

        // UOM Dropdown
        ref.watch(allUomProvider).when(
              data: (uoms) => _buildSearchableDropdown<UnitOfMeasurement>(
                key: const ValueKey('uom_data'),
                label: 'Unit of Measurement',
                icon: PhosphorIconsDuotone.ruler,
                items: uoms,
                itemLabel: (u) => '${u.label} (${u.abbreviation})',
                itemId: (u) => u.id,
                selectedItemId: _selectedUomId,
                onSelected: (u) => setState(() => _selectedUomId = u?.id),
                onAddPressed: _showAddUomBottomSheet,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error loading units: $e'),
            ),
      ],
    );
  }

  // Step 2: Pricing & Commission
  Widget _buildStep2() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _costPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cost Price',
                  prefixText: 'KES ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(PhosphorIconsDuotone.money),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling Price *',
                  prefixText: 'KES ',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(PhosphorIconsDuotone.currencyDollar),
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Step 3: Logistics
  Widget _buildStep3() {
    final measurementSystem = ref.watch(measurementSystemProvider);
    final isMetric = measurementSystem == MeasurementSystem.metric;
    final lengthUnit = isMetric ? 'cm' : 'in';
    final weightUnit = isMetric ? 'kg' : 'lb';

    return Column(
      children: [
        // SKU Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Auto-generate SKU'),
                subtitle: const Text('Create unique ID automatically'),
                value: _autoGenerateSku,
                onChanged: (val) => setState(() => _autoGenerateSku = val),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_autoGenerateSku)
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'Manual SKU',
                    border: OutlineInputBorder(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Barcode
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _barcodeController,
                decoration: InputDecoration(
                  labelText: 'Barcode (Optional)',
                  hintText: 'Scan or type',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSecondary.withValues(alpha: 0.5),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _scanBarcode,
              icon: Icon(
                PhosphorIconsDuotone.barcode,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Stock
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Track Stock'),
                subtitle: const Text('Manage inventory levels for this item'),
                value: _trackStock,
                onChanged: (val) => setState(() => _trackStock = val),
                contentPadding: EdgeInsets.zero,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Initial Stock *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Please enter initial stock'
                            : null,
                      ),
                    ),
                    if (_trackStock) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lowStockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Low Stock Alert',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Dimensions & Weight
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Physical Dimensions',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Weight',
                        suffixText: weightUnit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                        controller: _lengthController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Length',
                          suffixText: lengthUnit,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _widthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Width',
                        suffixText: lengthUnit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                     child: TextFormField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Height',
                        suffixText: lengthUnit,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
