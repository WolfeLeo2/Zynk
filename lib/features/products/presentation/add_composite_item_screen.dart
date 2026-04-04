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
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

const _uuid = Uuid();

enum _CompositeType { assembly, kit }

class _ComponentEntry {
  Product product;
  int quantity;

  _ComponentEntry({required this.product}) : quantity = 1;
}

// Using local setState for UI saving states

class AddCompositeItemScreen extends ConsumerStatefulWidget {
  const AddCompositeItemScreen({super.key});

  @override
  ConsumerState<AddCompositeItemScreen> createState() => _AddCompositeItemScreenState();
}

class _AddCompositeItemScreenState extends ConsumerState<AddCompositeItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSaving = false;

  _CompositeType _compositeType = _CompositeType.assembly;
  final List<_ComponentEntry> _components = [];
  String? _searchQuery;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  double get _totalCost {
    return _components.fold(0.0, (sum, e) => sum + (e.product.costPrice ?? 0.0) * e.quantity);
  }

  void _addComponent(Product product) {
    final existing = _components.indexWhere((e) => e.product.id == product.id);
    if (existing >= 0) {
      setState(() => _components[existing].quantity++);
    } else {
      setState(() => _components.add(_ComponentEntry(product: product)));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_components.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one component to the composite item.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final profile = ref.read(currentUserProfileProvider).value;
      final tenantId = profile?.tenantId ?? '';
      final branchId = ref.read(currentBranchIdProvider) ?? '';
      final price = double.tryParse(_priceController.text) ?? _totalCost;

      final product = Product(
        id: _uuid.v4(),
        tenantId: tenantId,
        branchId: branchId,
        name: _nameController.text.trim(),
        sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        basePrice: price,
        costPrice: _totalCost,
        isService: false,
      );

      final components = _components.map((e) => CompositeItemComponent(
        id: _uuid.v4(),
        tenantId: tenantId,
        branchId: branchId,
        compositeProductId: product.id,
        componentProductId: e.product.id,
        quantity: e.quantity,
      )).toList();

      await ref.read(repositoryProvider).createCompositeProduct(product, components);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Composite item "${product.name}" created.'),
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
        title: const Text('New Composite Item'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton(
              onPressed: isSaving ? null : _save,
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Item'),
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
                        Expanded(flex: 3, child: _buildComponentsPanel(theme, cs)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftPanel(theme, cs),
                        const SizedBox(height: 24),
                        _buildComponentsPanel(theme, cs),
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
        // Type Toggle
        _SectionCard(
          title: 'Item Type',
          icon: PhosphorIconsDuotone.arrowsSplit,
          children: [
            Row(
              children: _CompositeType.values.map((type) {
                final selected = _compositeType == type;
                final icon = type == _CompositeType.assembly
                    ? PhosphorIconsDuotone.wrench
                    : PhosphorIconsDuotone.package;
                final label = type == _CompositeType.assembly ? 'Assembly Item' : 'Kit Item';
                final desc = type == _CompositeType.assembly
                    ? 'Physically built from components'
                    : 'Bundled items sold together';

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _compositeType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: type == _CompositeType.assembly
                          ? const EdgeInsets.only(right: 6)
                          : const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? cs.primary : cs.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PhosphorIcon(icon, color: selected ? cs.primary : cs.onSurfaceVariant, size: 22),
                          const SizedBox(height: 8),
                          Text(
                            label,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              color: selected ? cs.primary : cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Basic Info
        _SectionCard(
          title: 'Basic Details',
          icon: PhosphorIconsDuotone.info,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Item Name *'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Pricing
        _SectionCard(
          title: 'Pricing',
          icon: PhosphorIconsDuotone.currencyDollar,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Auto-calculated cost:', style: theme.textTheme.bodyMedium),
                  Text(
                    'KES ${_totalCost.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: InputDecoration(
                labelText: 'Selling Price (defaults to cost if empty)',
                hintText: _totalCost > 0 ? _totalCost.toStringAsFixed(2) : '0.00',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComponentsPanel(ThemeData theme, ColorScheme cs) {
    final productsAsync = ref.watch(allProductsProvider);

    return _SectionCard(
      title: 'Associated Items',
      icon: PhosphorIconsDuotone.listBullets,
      trailing: _components.isNotEmpty
          ? Text(
              '${_components.length} items',
              style: theme.textTheme.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
            )
          : null,
      children: [
        // Search
        productsAsync.when(
          data: (allProducts) {
            final available = allProducts.toList();
            final filtered = _searchQuery != null && _searchQuery!.isNotEmpty
                ? available.where((p) => p.name.toLowerCase().contains(_searchQuery!.toLowerCase())).toList()
                : available;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search items to add...',
                    prefixIcon: const Icon(PhosphorIconsDuotone.magnifyingGlass),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
                if (_searchQuery != null && _searchQuery!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: Text('No matching items')),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              return ListTile(
                                dense: true,
                                title: Text(p.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                                subtitle: Text('KES ${p.basePrice.toStringAsFixed(0)}', style: theme.textTheme.bodySmall),
                                trailing: const Icon(PhosphorIconsBold.plus, size: 18),
                                onTap: () {
                                  _addComponent(p);
                                  setState(() => _searchQuery = null);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ],
            );
          },
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
        const SizedBox(height: 16),

        // Components list
        if (_components.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  PhosphorIcon(PhosphorIconsDuotone.listBullets, size: 48, color: cs.outlineVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Search and add items above.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          )
        else
          ...List.generate(_components.length, (i) => _buildComponentRow(_components[i], i, theme, cs)),
      ],
    );
  }

  Widget _buildComponentRow(_ComponentEntry entry, int index, ThemeData theme, ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.product.name, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                Text(
                  'Cost: KES ${(entry.product.costPrice ?? 0).toStringAsFixed(2)} × ${entry.quantity}',
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Quantity stepper
          Row(
            children: [
              IconButton(
                icon: const Icon(PhosphorIconsBold.minus, size: 16),
                onPressed: () {
                  if (entry.quantity > 1) {
                    setState(() => entry.quantity--);
                  } else {
                    setState(() => _components.removeAt(index));
                  }
                },
              ),
              Text('${entry.quantity}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(PhosphorIconsBold.plus, size: 16),
                onPressed: () => setState(() => entry.quantity++),
              ),
            ],
          ),
          Text(
            'KES ${((entry.product.costPrice ?? 0) * entry.quantity).toStringAsFixed(2)}',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Shared section card (same as in add_item_group_screen) ───────────

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
              ?trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
