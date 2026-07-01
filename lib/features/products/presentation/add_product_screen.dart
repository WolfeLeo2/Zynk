import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart'; // Add uuid import
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/app_providers.dart'; // for repositoryProvider
import 'package:zynk/core/utils/responsive_modal.dart';
import 'package:zynk/features/products/presentation/providers/add_product_controller.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/scanner_screen.dart';
import 'package:zynk/features/products/presentation/widgets/edit_item_group_sheet.dart';
import 'package:zynk/shared/widgets/app_bottom_sheet.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Product? existingProduct;
  final bool isCloneMode;

  const AddProductScreen({
    super.key,
    this.existingProduct,
    this.isCloneMode = false,
  });

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
  final _costPriceController = TextEditingController();
  final _lowStockController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategoryId;
  String? _selectedItemGroupId;
  String? _selectedUomId;
  bool _autoGenerateSku = true;
  String? _existingImageUrl;

  // Inheritance / Overrides
  bool _overrideSellingPrice = false;
  bool _overrideBuyingPrice = false;
  bool _overridePricingUnit = false;
  bool _overrideCoverage = false;

  String _pricingUnit = 'piece';
  final _coverageController = TextEditingController();

  // Logistics / Dimensions
  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

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
      _selectedItemGroupId = p.itemGroupId;
      _selectedUomId = p.uomId;
      _existingImageUrl = p.imageUrl;

      // Initialize override flags
      _overrideSellingPrice = p.basePrice != null;
      _overrideBuyingPrice = p.costPrice != null;
      _overridePricingUnit = p.pricingUnit != null;
      _overrideCoverage = p.coveragePerBox != null;

      _pricingUnit = p.pricingUnit ?? 'piece';
      if (p.coveragePerBox != null) {
        _coverageController.text = p.coveragePerBox.toString();
      }

      // Logistics
      if (p.weight != null) _weightController.text = p.weight.toString();
      if (p.length != null) _lengthController.text = p.length.toString();
      if (p.width != null) _widthController.text = p.width.toString();
      if (p.height != null) _heightController.text = p.height.toString();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _lowStockController.dispose();
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _coverageController.dispose();

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

  void _updateInheritedGroupSettings() {
    if (_selectedItemGroupId == null) return;

    final groupsAsync = ref.read(allItemGroupsProvider);
    final group = groupsAsync.whenOrNull(
      data: (groups) =>
          groups.where((g) => g.id == _selectedItemGroupId).firstOrNull,
    );

    if (group != null) {
      if (!_overridePricingUnit && group.defaultPricingUnit != null) {
        _pricingUnit = group.defaultPricingUnit!;
      }
      if (!_overrideCoverage && group.defaultCoveragePerBox != null) {
        _coverageController.text = group.defaultCoveragePerBox!.toString();
      }
      if (!_overrideSellingPrice && group.defaultSellingPrice != null) {
        _priceController.text = group.defaultSellingPrice!.toString();
      }
      if (!_overrideBuyingPrice && group.defaultBuyingPrice != null) {
        _costPriceController.text = group.defaultBuyingPrice!.toString();
      }
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedItemGroupId == null) {
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

      final price = _overrideSellingPrice || _selectedItemGroupId == null
          ? double.tryParse(_priceController.text.trim())
          : null;

      final costPrice = _overrideBuyingPrice || _selectedItemGroupId == null
          ? double.tryParse(_costPriceController.text.trim())
          : null;

      final coverage =
          (_pricingUnit == 'sqm' &&
              (_overrideCoverage || _selectedItemGroupId == null))
          ? double.tryParse(_coverageController.text.trim())
          : null;

      // Validation: If no group, we MUST have a selling price
      if (_selectedItemGroupId == null && price == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please provide a price or select an Item Group to inherit prices.',
            ),
          ),
        );
        return;
      }

      String skuToSave = _skuController.text;
      if (_autoGenerateSku && skuToSave.isEmpty) {
        skuToSave =
            'PRD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      }

      await ref
          .read(addProductControllerProvider.notifier)
          .saveProduct(
            id: widget.isCloneMode ? null : widget.existingProduct?.id,
            targetBranchIds: const [], // Products are global; branchId = null
            existingImageUrl: _existingImageUrl,
            name: _nameController.text,
            categoryId: _selectedCategoryId,
            itemGroupId: _selectedItemGroupId,
            uomId: _selectedUomId,
            pricingUnit: _pricingUnit,
            coveragePerBox: coverage,
            price: price,
            costPrice: costPrice,
            sku: skuToSave,
            barcode: _barcodeController.text,
            imageFile: _selectedImage,
            initialStock: null, // Stock is managed via Inventory Adjustments
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
                      prefixIcon: PhosphorIcon(icon),
                      suffixIcon: selectedItem != null
                          ? IconButton(
                              icon: const PhosphorIcon(PhosphorIconsRegular.x),
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
            icon: PhosphorIcon(
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
                if (tenantId != null) {
                  await repo.createCategory(
                    Category(
                      id: const Uuid().v4(),
                      tenantId: tenantId,
                      branchId: null, // Categories are also global
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
    final newGroup = await EditItemGroupSheet.show(context);
    if (newGroup != null && mounted) {
      setState(() => _selectedItemGroupId = newGroup.id);
    }
  }

  Future<void> _showAddUomBottomSheet() async {
    final labelController = TextEditingController();
    final abbrController = TextEditingController();
    final factorController = TextEditingController();
    String? baseUnitId;

    await showResponsiveModal(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AppBottomSheet(
          title: 'Unit of measure',
          icon: PhosphorIconsDuotone.ruler,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    child: ref
                        .watch(allUomProvider)
                        .when(
                          data: (uoms) => DropdownButtonFormField<String>(
                            initialValue: baseUnitId,
                            decoration: const InputDecoration(
                              labelText: 'Base Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: uoms
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u.id,
                                    child: Text(u.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => baseUnitId = val),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (err, stack) => const Text('Error'),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEditing = widget.existingProduct != null && !widget.isCloneMode;
    final isCloning = widget.existingProduct != null && widget.isCloneMode;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'Edit Product'
              : (isCloning ? 'Clone Product' : 'Add New Product'),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const PhosphorIcon(PhosphorIconsBold.x),
        ),
        actions: [
          TextButton.icon(
            onPressed: _saveProduct,
            icon: const PhosphorIcon(PhosphorIconsBold.check),
            label: Text("Save"),
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
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
                const SizedBox(height: 32),
                _buildSectionHeader(
                  theme,
                  'Identifiers',
                  PhosphorIconsDuotone.package,
                ),

                _buildStep3(),
                const SizedBox(height: 16),

                _buildSectionHeader(
                  theme,
                  'Pricing & Commission',
                  PhosphorIconsDuotone.currencyCircleDollar,
                ),
                const SizedBox(height: 16),
                _buildStep2(),
                const SizedBox(height: 16),

                const SizedBox(height: 48), // bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    ThemeData theme,
    String title,
    PhosphorIconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PhosphorIcon(icon, color: theme.colorScheme.primary, size: 20),
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
    final measurementSystem = ref.watch(measurementSystemProvider);
    final isMetric = measurementSystem == MeasurementSystem.metric;
    final lengthUnit = isMetric ? 'cm' : 'in';
    final weightUnit = isMetric ? 'kg' : 'lb';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Image Picker
        Center(
          child: GestureDetector(
            onTap: () {
              showResponsiveModal(
                showDragHandle: true,
                context: context,
                backgroundColor: Theme.of(context).colorScheme.surface,
                builder: (context) => AppBottomSheet(
                  title: 'Choose image',
                  icon: PhosphorIconsDuotone.image,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const PhosphorIcon(
                          PhosphorIconsDuotone.camera,
                        ),
                        title: const Text('Take Photo'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const PhosphorIcon(
                          PhosphorIconsDuotone.image,
                        ),
                        title: const Text('Choose from Gallery'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
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
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
              ),
              child: (_selectedImage == null && _existingImageUrl == null)
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhosphorIcon(
                          PhosphorIconsDuotone.camera,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add Photo',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 32),

        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Product Name',
            hintText: 'e.g. Vintage Denim Jacket',
            border: OutlineInputBorder(),
            prefixIcon: PhosphorIcon(PhosphorIconsDuotone.tag),
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
            onSelected: (g) {
              setState(() {
                _selectedItemGroupId = g?.id;
              });
              _updateInheritedGroupSettings();
            },
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
        ref
            .watch(allUomProvider)
            .when(
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
        const SizedBox(height: 16),
        // Dimensions & Weight
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Physical Dimensions',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Weight',
                suffixText: weightUnit,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lengthController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Length',
                suffixText: lengthUnit,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _widthController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Width',
                suffixText: lengthUnit,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _heightController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Height',
                suffixText: lengthUnit,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
      ],
    );
  }

  // _buildBranchSelector removed — products are global (branchId = null).

  // Step 2: Pricing & Commission
  Widget _buildStep2() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedItemGroupId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  PhosphorIcon(
                    PhosphorIconsDuotone.info,
                    size: 20,
                    color: cs.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select an Item Group to enable price inheritance.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Pricing Unit Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Pricing Unit',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_selectedItemGroupId != null)
              _buildOverrideChip(
                isOverridden: _overridePricingUnit,
                onTap: () {
                  setState(() => _overridePricingUnit = !_overridePricingUnit);
                  if (!_overridePricingUnit) _updateInheritedGroupSettings();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _pricingUnit,
          decoration: InputDecoration(
            labelText: _overridePricingUnit
                ? 'Custom Pricing Unit'
                : 'Inherited Pricing Unit',
            border: const OutlineInputBorder(),
            fillColor: (_selectedItemGroupId != null && !_overridePricingUnit)
                ? cs.surfaceContainerHighest.withValues(alpha: 0.8)
                : null,
            filled: (_selectedItemGroupId != null && !_overridePricingUnit),
            helperText: _selectedItemGroupId != null
                ? (_overridePricingUnit
                      ? 'Using custom pricing unit'
                      : 'Using group default pricing unit')
                : 'Per piece or per sqm',
          ),
          items: const [
            DropdownMenuItem(value: 'piece', child: Text('Per Piece / Unit')),
            DropdownMenuItem(value: 'sqm', child: Text('Per Sqm (Coverage)')),
          ],
          onChanged: (_selectedItemGroupId != null && !_overridePricingUnit)
              ? null
              : (val) {
                  if (val != null) setState(() => _pricingUnit = val);
                },
        ),
        const SizedBox(height: 24),

        // Coverage Section (only if sqm)
        if (_pricingUnit == 'sqm') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Coverage per Box',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_selectedItemGroupId != null)
                _buildOverrideChip(
                  isOverridden: _overrideCoverage,
                  onTap: () {
                    setState(() => _overrideCoverage = !_overrideCoverage);
                    if (!_overrideCoverage) _updateInheritedGroupSettings();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _coverageController,
            readOnly: _selectedItemGroupId != null && !_overrideCoverage,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _overrideCoverage
                  ? 'Custom Coverage (sqm)'
                  : 'Inherited Coverage (sqm)',
              hintText: 'e.g. 1.44',
              border: const OutlineInputBorder(),
              prefixIcon: const PhosphorIcon(PhosphorIconsDuotone.ruler),
              fillColor: (_selectedItemGroupId != null && !_overrideCoverage)
                  ? cs.surfaceContainerHighest.withValues(alpha: 0.8)
                  : null,
              filled: (_selectedItemGroupId != null && !_overrideCoverage),
              helperText: _selectedItemGroupId != null
                  ? (_overrideCoverage
                        ? 'Using custom coverage'
                        : 'Using group default coverage')
                  : 'Coverage area per box',
            ),
            validator: (val) {
              if (_pricingUnit == 'sqm' && (val == null || val.isEmpty)) {
                return 'Required for sqm pricing';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
        ],

        // Selling Price Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Selling Price',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_selectedItemGroupId != null)
              _buildOverrideChip(
                isOverridden: _overrideSellingPrice,
                onTap: () {
                  setState(
                    () => _overrideSellingPrice = !_overrideSellingPrice,
                  );
                  if (!_overrideSellingPrice) _updateInheritedGroupSettings();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _priceController,
          readOnly: _selectedItemGroupId != null && !_overrideSellingPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _overrideSellingPrice
                ? 'Custom Selling Price'
                : 'Inherited Selling Price',
            prefixText: 'KES ',
            hintText: '0.00',
            border: const OutlineInputBorder(),
            prefixIcon: const PhosphorIcon(
              PhosphorIconsDuotone.currencyCircleDollar,
            ),
            fillColor: (_selectedItemGroupId != null && !_overrideSellingPrice)
                ? cs.surfaceContainerHighest.withValues(alpha: 0.8)
                : null,
            filled: (_selectedItemGroupId != null && !_overrideSellingPrice),
            helperText: _selectedItemGroupId != null
                ? (_overrideSellingPrice
                      ? 'Using custom override price'
                      : 'Using group default price')
                : 'Enter standard selling price',
            helperStyle: TextStyle(
              color: _overrideSellingPrice ? cs.primary : cs.onSurfaceVariant,
              fontWeight: _overrideSellingPrice ? FontWeight.bold : null,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Cost Price Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Cost Price',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_selectedItemGroupId != null)
              _buildOverrideChip(
                isOverridden: _overrideBuyingPrice,
                onTap: () {
                  setState(() => _overrideBuyingPrice = !_overrideBuyingPrice);
                  if (!_overrideBuyingPrice) _updateInheritedGroupSettings();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _costPriceController,
          readOnly: _selectedItemGroupId != null && !_overrideBuyingPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _overrideBuyingPrice
                ? 'Custom Cost Price'
                : 'Inherited Cost Price',
            prefixText: 'KES ',
            hintText: '0.00',
            border: const OutlineInputBorder(),
            prefixIcon: const PhosphorIcon(PhosphorIconsDuotone.money),
            fillColor: (_selectedItemGroupId != null && !_overrideBuyingPrice)
                ? cs.surfaceContainerHighest.withValues(alpha: 0.8)
                : null,
            filled: (_selectedItemGroupId != null && !_overrideBuyingPrice),
            helperText: _selectedItemGroupId != null
                ? (_overrideBuyingPrice
                      ? 'Using custom override cost'
                      : 'Using group default cost')
                : 'Enter standard purchase cost',
            helperStyle: TextStyle(
              color: _overrideBuyingPrice ? cs.primary : cs.onSurfaceVariant,
              fontWeight: _overrideBuyingPrice ? FontWeight.bold : null,
            ),
          ),
        ),
      ],
    );
  }

  // Step 3: Logistics
  Widget _buildStep3() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // SKU Section
        Column(
          children: [
            SwitchListTile(
              title: const Text('Auto-generate SKU'),
              subtitle: const Text('Create unique ID automatically'),
              value: _autoGenerateSku,
              onChanged: (val) => setState(() => _autoGenerateSku = val),
              contentPadding: EdgeInsets.zero,
            ),
            if (!_autoGenerateSku)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'Manual SKU',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
          ],
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
              icon: PhosphorIcon(
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

        // Stock info banner — stock is managed via Inventory Adjustments
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.secondaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PhosphorIcon(
                PhosphorIconsDuotone.info,
                size: 18,
                color: Theme.of(context).colorScheme.secondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Stock levels are managed per-branch via Inventory Adjustments.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildOverrideChip({
    required bool isOverridden,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isOverridden
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PhosphorIcon(
              isOverridden
                  ? PhosphorIconsBold.check
                  : PhosphorIconsDuotone.link,
              size: 14,
              color: isOverridden
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              isOverridden ? 'Overridden' : 'Inherited',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isOverridden
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
