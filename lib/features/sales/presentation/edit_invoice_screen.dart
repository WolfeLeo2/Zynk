import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/customers/providers/customer_providers.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';
import 'package:zynk/core/services/sales_service.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/widgets/product_selection_sheet.dart';
import 'package:zynk/shared/widgets/stock_availability_label.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/utils/currency.dart';

class EditInvoiceScreen extends ConsumerStatefulWidget {
  final String saleId;
  final bool wasApproved;

  const EditInvoiceScreen({
    super.key,
    required this.saleId,
    this.wasApproved = false,
  });

  @override
  ConsumerState<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends ConsumerState<EditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Customer fields
  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Editable line items in memory
  List<_EditableSaleItem> _items = [];
  Sale? _sale;
  Customer? _customer;
  bool _initialized = false;
  DateTime? _dueDate;
  String? _salespersonId;

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _notesCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _initialize(
    Sale sale,
    List<SaleItem> items,
    Customer? customer,
    List<Product> products,
  ) {
    if (_initialized) return;
    _initialized = true;
    _sale = sale;
    _customer = customer;
    _salespersonId = sale.salespersonId;
    _customerNameCtrl.text = customer?.name ?? '';
    _customerPhoneCtrl.text = customer?.phone ?? '';
    _notesCtrl.text = sale.notes ?? '';
    _dueDate = sale.dueDate;

    _items = [];
    for (final item in items) {
      final product = products.where((p) => p.id == item.productId).firstOrNull;
      final itemGroup = (product != null && product.itemGroupId != null)
          ? ref.read(itemGroupProvider(product.itemGroupId!)).value
          : null;
      final isSqmBased =
          product != null &&
          (product.pricingUnit == 'sqm' ||
              itemGroup?.defaultPricingUnit == 'sqm');
      final coverage =
          (product?.coveragePerBox ?? itemGroup?.defaultCoveragePerBox) ?? 1.0;

      _items.add(
        _EditableSaleItem(
          id: item.id,
          productId: item.productId,
          costPrice: item.costPrice,
          taxAmount: item.taxAmount,
          initialName: item.productName ?? item.productId,
          initialQty: item.quantity,
          initialPrice: item.unitPrice,
          isSqmBased: isSqmBased,
          coveragePerBox: coverage,
        ),
      );
    }
  }

  double _computeSubtotal() =>
      _items.fold(0, (sum, item) => sum + item.resolvedLine().total);

  /// Build a fresh editable line item from a catalogue product (qty defaults to 1).
  _EditableSaleItem _editableFromProduct(Product product) {
    final itemGroup = product.itemGroupId != null
        ? ref.read(itemGroupProvider(product.itemGroupId!)).value
        : null;
    final isSqmBased =
        product.pricingUnit == 'sqm' || itemGroup?.defaultPricingUnit == 'sqm';
    final coverage =
        (product.coveragePerBox ?? itemGroup?.defaultCoveragePerBox) ?? 1.0;
    return _EditableSaleItem(
      id: const Uuid().v4(),
      productId: product.id,
      costPrice: product.costPrice ?? 0,
      taxAmount: 0,
      initialName: product.name,
      initialQty: 1,
      initialPrice: product.basePrice ?? 0,
      isSqmBased: isSqmBased,
      coveragePerBox: coverage,
    );
  }

  /// Opens the product picker and appends the chosen products (those not already
  /// on the invoice) as new line items. New items are inserted server-side by
  /// `update_draft` (which replaces the sale's items wholesale).
  Future<void> _addItems(List<Product> products) async {
    final existingIds = _items.map((i) => i.productId).toSet();
    final available = products
        .where((p) => !existingIds.contains(p.id))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All products are already on this invoice.'),
        ),
      );
      return;
    }
    final selected = await ProductSelectionSheet.show(
      context,
      availableProducts: available,
      initiallySelectedIds: const {},
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() {
      for (final id in selected) {
        final product = products.where((p) => p.id == id).firstOrNull;
        if (product != null) _items.add(_editableFromProduct(product));
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final sale = _sale;
    if (sale == null) return;

    if (_salespersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a salesperson before saving.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(repositoryProvider);
      final tenantId = ref.read(tenantIdProvider);
      final branchId = sale.branchId;

      if (tenantId == null) {
        throw Exception('Missing tenant context');
      }

      // Build updated SaleItem list
      final updatedItems = <SaleItem>[];
      for (final item in _items) {
        final line = item.resolvedLine();
        final qty = line.quantity;
        if (qty <= 0) continue;

        final price = line.unitPrice;

        final name = item.nameCtr.text.trim().isEmpty
            ? item.initialName
            : item.nameCtr.text.trim();

        // Stock validation — skip when no stock row exists (e.g. services)
        final available = await repo.getProductStockOrNull(
          item.productId,
          branchId,
        );
        if (available != null) {
          if (qty > available) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Not enough stock for "$name". Available: $available',
                  ),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            setState(() => _isLoading = false);
            return;
          }
        }

        updatedItems.add(
          SaleItem(
            id: item.id,
            saleId: sale.id,
            productId: item.productId,
            tenantId: tenantId,
            quantity: qty,
            unitPrice: price,
            costPrice: item.costPrice,
            taxAmount: item.taxAmount,
            discount: 0,
            total: line.total,
            productName: name,
          ),
        );
      }

      if (updatedItems.isEmpty) {
        throw Exception('At least one item is required.');
      }

      // Update customer fields if changed
      final customer = _customer;
      if (customer != null) {
        final newName = _customerNameCtrl.text.trim();
        final newPhone = _customerPhoneCtrl.text.trim();
        if (newName != customer.name || newPhone != (customer.phone ?? '')) {
          await repo.updateCustomer(
            Customer(
              id: customer.id,
              tenantId: customer.tenantId,
              branchId: customer.branchId,
              name: newName.isEmpty ? customer.name : newName,
              phone: newPhone.isEmpty ? null : newPhone,
              email: customer.email,
            ),
          );
        }
      }

      await ref
          .read(salesServiceProvider)
          .updateDraftInvoice(
            saleId: sale.id,
            tenantId: tenantId,
            customerId: sale.customerId ?? customer?.id ?? '',
            items: updatedItems,
            salespersonId: _salespersonId,
            notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
            dueDate: _dueDate?.toIso8601String(),
          );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final saleAsync = ref.watch(saleDetailProvider(widget.saleId));
    final itemsAsync = ref.watch(saleItemsProvider(widget.saleId));
    final customersAsync = ref.watch(allCustomersProvider);
    final productsAsync = ref.watch(allProductsProvider);

    return saleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (sale) {
        if (sale == null) {
          return const Scaffold(body: Center(child: Text('Invoice not found')));
        }

        return itemsAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (saleItems) {
            return productsAsync.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
              data: (products) {
                final customers = customersAsync.value ?? [];
                final customer = customers.firstWhere(
                  (c) => c.id == sale.customerId,
                  orElse: () => Customer(
                    id: sale.customerId ?? '',
                    tenantId: sale.tenantId,
                    branchId: sale.branchId,
                    name: '',
                  ),
                );
                _initialize(sale, saleItems, customer, products);

                return Scaffold(
                  appBar: AppBar(
                    leading: IconButton(
                      icon: const PhosphorIcon(PhosphorIconsRegular.x),
                      onPressed: () => context.pop(),
                    ),
                    title: Text('Edit ${sale.invoiceNumber ?? 'Invoice'}'),
                    centerTitle: true,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              ref
                                      .watch(branchesProvider)
                                      .value
                                      ?.where((b) => b.id == sale.branchId)
                                      .firstOrNull
                                      ?.name ??
                                  '',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  body: Form(
                    key: _formKey,
                    onChanged: () => setState(() {}),
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        // ── Previously Approved Banner ──
                        if (widget.wasApproved)
                          Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.tertiary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsDuotone.info,
                                  color: theme.colorScheme.onTertiaryContainer,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This invoice was previously approved. Saving will resubmit it for re-approval.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // ── Customer ──
                        Text(
                          'Billed To',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: cs.outline.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _customerNameCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Customer Name',
                                  prefixIcon: const PhosphorIcon(
                                    PhosphorIconsRegular.user,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _customerPhoneCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Phone',
                                  prefixIcon: const PhosphorIcon(
                                    PhosphorIconsRegular.phone,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Due Date ──
                        Text(
                          'Due Date (Optional)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _dueDate ??
                                  DateTime.now().add(const Duration(days: 30)),
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 365),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 365),
                              ),
                            );
                            if (picked != null)
                              setState(() => _dueDate = picked);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: cs.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsRegular.calendar,
                                  color: cs.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _dueDate != null
                                      ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                      : 'Select due date',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: _dueDate != null
                                        ? cs.onSurface
                                        : cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Salesperson ──
                        Text(
                          'Salesperson (Required)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Consumer(
                          builder: (context, ref, child) {
                            final staffAsync = ref.watch(
                              humanStaffByBranchProvider(sale.branchId),
                            );
                            return staffAsync.when(
                              data: (staffList) {
                                if (staffList.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return DropdownButtonFormField<String>(
                                  initialValue: _salespersonId,
                                  decoration: InputDecoration(
                                    prefixIcon: const PhosphorIcon(
                                      PhosphorIconsRegular.user,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    isDense: true,
                                    filled: true,
                                    fillColor: cs.surfaceContainerHighest
                                        .withValues(alpha: 0.2),
                                  ),
                                  hint: const Text(
                                    'Select Salesperson (Required)',
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('None'),
                                    ),
                                    ...staffList.map(
                                      (s) => DropdownMenuItem<String>(
                                        value: s.id,
                                        child: Text(s.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _salespersonId = v),
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (_, _) => const SizedBox.shrink(),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Items ──
                        Text(
                          'Items',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ..._items.map(
                          (item) => _buildItemRow(
                            item,
                            cs,
                            theme,
                            branchId: sale.branchId,
                            onRemove: () {
                              setState(() {
                                item.dispose();
                                _items.remove(item);
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: () => _addItems(products),
                          icon: const PhosphorIcon(
                            PhosphorIconsBold.plus,
                            size: 18,
                          ),
                          label: const Text('Add Item'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Total ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estimated Total',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                CurrencyHelper.format(_computeSubtotal()),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Notes ──
                        Text(
                          'Notes (Optional)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'e.g., Net 30 payment terms',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: cs.surface,
                          ),
                        ),
                        const SizedBox(height: 32),

                        FilledButton.icon(
                          onPressed: _isLoading ? null : _save,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const PhosphorIcon(
                                  PhosphorIconsBold.floppyDisk,
                                ),
                          label: Text(
                            _isLoading ? 'Saving...' : 'Save Changes',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildItemRow(
    _EditableSaleItem item,
    ColorScheme cs,
    ThemeData theme, {
    required String branchId,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StockAvailabilityLabel(productId: item.productId, branchId: branchId),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: item.nameCtr,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Product Name',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: PhosphorIcon(
                  PhosphorIconsRegular.trash,
                  color: cs.error,
                  size: 20,
                ),
                tooltip: 'Remove item',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: item.qtyCtr,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: item.isSqmBased ? 'sqm' : 'Qty',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: item.isSqmBased
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: [
                    if (item.isSqmBased)
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                    else
                      FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (v) {
                    final qty = double.tryParse(v ?? '');
                    if (qty == null || qty <= 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: item.priceCtr,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: item.isSqmBased
                        ? 'Price/sqm (Ksh)'
                        : 'Unit Price (Ksh)',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  validator: (v) {
                    final p = double.tryParse(v ?? '');
                    if (p == null || p < 0) return 'Invalid';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyHelper.format(item.resolvedLine().total),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (item.isSqmBased) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final line = item.resolvedLine();
                final actualSqm = line.quantity * item.coveragePerBox;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Price/box: ${CurrencyHelper.format(line.unitPrice)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      'Total boxes: ${line.quantity} (${actualSqm.toStringAsFixed(2)} sqm)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary.withValues(alpha: 0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER: Holds controllers for one editable sale item
// ─────────────────────────────────────────────────────────────────────────────

class _EditableSaleItem {
  final String id;
  final String productId;
  final double costPrice;
  final double taxAmount;
  final String initialName;
  final int initialQty; // number of boxes from DB
  final double
  initialPrice; // unit price (per box if sqm-based, per piece if piece-based)
  final bool isSqmBased;
  final double coveragePerBox;

  late final TextEditingController nameCtr;
  late final TextEditingController qtyCtr;
  late final TextEditingController priceCtr;

  _EditableSaleItem({
    required this.id,
    required this.productId,
    required this.costPrice,
    required this.taxAmount,
    required this.initialName,
    required this.initialQty,
    required this.initialPrice,
    required this.isSqmBased,
    required this.coveragePerBox,
  }) {
    nameCtr = TextEditingController(text: initialName);

    // For sqm-based items, display quantity as initialQty (boxes) * coveragePerBox (total sqm)
    final displayQty = isSqmBased
        ? (initialQty * coveragePerBox)
        : initialQty.toDouble();
    qtyCtr = TextEditingController(
      text: isSqmBased ? displayQty.toStringAsFixed(2) : initialQty.toString(),
    );

    // For sqm-based items, display price as unitPrice / coveragePerBox (price per sqm)
    final displayPrice = isSqmBased
        ? (initialPrice / coveragePerBox)
        : initialPrice;
    priceCtr = TextEditingController(text: displayPrice.toStringAsFixed(0));
  }

  double get _enteredPrice =>
      double.tryParse(priceCtr.text) ??
      (isSqmBased ? initialPrice / coveragePerBox : initialPrice);

  double get _enteredQty =>
      double.tryParse(qtyCtr.text) ??
      (isSqmBased ? initialQty * coveragePerBox : initialQty.toDouble());

  /// Resolved pricing — single source for subtotal, the row total and saving.
  InvoiceLine resolvedLine() => SalesService.resolveLine(
        isSqmBased: isSqmBased,
        coveragePerBox: coveragePerBox,
        enteredPrice: _enteredPrice,
        enteredQty: _enteredQty,
      );

  void dispose() {
    nameCtr.dispose();
    qtyCtr.dispose();
    priceCtr.dispose();
  }
}
