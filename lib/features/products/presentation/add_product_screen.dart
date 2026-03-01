import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart'; // Add uuid import
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

  bool _autoGenerateSku = true;
  bool _trackStock = true;
  String? _existingImageUrl;

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
      _existingImageUrl = p.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _stockController.dispose();
    _costPriceController.dispose(); // Added
    _lowStockController.dispose();
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
            price: price,
            costPrice: costPrice,
            sku: skuToSave,
            barcode: _barcodeController.text,
            imageFile: _selectedImage,
            initialStock: int.tryParse(_stockController.text),
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

  Future<void> _showAddGroupDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Item Group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group Name',
            hintText: 'e.g. Summer Collection',
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
                  await repo.createItemGroup(
                    ItemGroup(
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
            label: 'Item Group (Optional)',
            icon: PhosphorIconsDuotone.stackSimple,
            items: groups,
            itemLabel: (g) => g.name,
            itemId: (g) => g.id,
            selectedItemId: _selectedItemGroupId,
            onSelected: (g) => setState(() => _selectedItemGroupId = g?.id),
            onAddPressed: _showAddGroupDialog,
          ),
          loading: () => _buildSearchableDropdown<ItemGroup>(
            key: const ValueKey('groups_loading'),
            label: 'Item Group (Optional)',
            icon: PhosphorIconsDuotone.stackSimple,
            items: const [],
            itemLabel: (g) => g.name,
            itemId: (g) => g.id,
            selectedItemId: _selectedItemGroupId,
            onSelected: (g) {},
            onAddPressed: _showAddGroupDialog,
          ),
          error: (e, s) => const SizedBox(),
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
      ],
    );
  }
}
