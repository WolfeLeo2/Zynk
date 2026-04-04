import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/pos/providers/customer_providers.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';

class EditInvoiceScreen extends ConsumerStatefulWidget {
  final String saleId;

  const EditInvoiceScreen({super.key, required this.saleId});

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

  void _initialize(Sale sale, List<SaleItem> items, Customer? customer) {
    if (_initialized) return;
    _initialized = true;
    _sale = sale;
    _customer = customer;
    _salespersonId = sale.salespersonId;
    _customerNameCtrl.text = customer?.name ?? '';
    _customerPhoneCtrl.text = customer?.phone ?? '';
    _notesCtrl.text = sale.notes ?? '';
    _dueDate = sale.dueDate;
    _items = items
        .map(
          (item) => _EditableSaleItem(
            id: item.id,
            productId: item.productId,
            costPrice: item.costPrice,
            taxAmount: item.taxAmount,
            initialName: item.productName ?? item.productId,
            initialQty: item.quantity,
            initialPrice: item.unitPrice,
          ),
        )
        .toList();
  }

  double _computeSubtotal() {
    double total = 0;
    for (final item in _items) {
      final price = double.tryParse(item.priceCtr.text) ?? 0;
      final qty = int.tryParse(item.qtyCtr.text) ?? 0;
      total += price * qty;
    }
    return total;
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
      final branchId = ref.read(currentBranchIdProvider);

      if (tenantId == null || branchId == null) {
        throw Exception('Missing tenant or branch context');
      }

      // Build updated SaleItem list
      final updatedItems = <SaleItem>[];
      for (final item in _items) {
        final qty = int.tryParse(item.qtyCtr.text) ?? 0;
        if (qty <= 0) continue;

        final price = double.tryParse(item.priceCtr.text) ?? item.initialPrice;
        final name = item.nameCtr.text.trim().isEmpty ? item.initialName : item.nameCtr.text.trim();

        // Stock validation — skip when no stock row exists (e.g. services)
        final stockRow = await repo.db.getOptional(
          'SELECT quantity FROM stock WHERE product_id = ? AND branch_id = ?',
          [item.productId, branchId],
        );
        if (stockRow != null) {
          final available = (stockRow['quantity'] as num?)?.toInt() ?? 0;
          if (qty > available) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Not enough stock for "$name". Available: $available'),
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
            total: price * qty,
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

      await ref.read(salesServiceProvider).updateDraftInvoice(
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
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

    return saleAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (sale) {
        if (sale == null) {
          return const Scaffold(body: Center(child: Text('Invoice not found')));
        }

        return itemsAsync.when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
          data: (saleItems) {
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
            _initialize(sale, saleItems, customer);

            return Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const PhosphorIcon(PhosphorIconsRegular.x),
                  onPressed: () => context.pop(),
                ),
                title: Text('Edit ${sale.invoiceNumber ?? 'Invoice'}'),
                centerTitle: true,
              ),
              body: Form(
                key: _formKey,
                onChanged: () => setState(() {}),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // ── Customer ──
                    Text(
                      'Billed To',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _customerNameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Customer Name',
                              prefixIcon: const Icon(PhosphorIconsRegular.user),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            textCapitalization: TextCapitalization.words,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _customerPhoneCtrl,
                            decoration: InputDecoration(
                              labelText: 'Phone (optional)',
                              prefixIcon: const Icon(PhosphorIconsRegular.phone),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now().subtract(const Duration(days: 365)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _dueDate = picked);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            PhosphorIcon(PhosphorIconsRegular.calendar, color: cs.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Text(
                              _dueDate != null
                                  ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                  : 'Select due date',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: _dueDate != null ? cs.onSurface : cs.onSurfaceVariant,
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
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final staffAsync = ref.watch(humanStaffProvider);
                        return staffAsync.when(
                          data: (staffList) {
                            if (staffList.isEmpty) return const SizedBox.shrink();
                            return DropdownButtonFormField<String>(
                              initialValue: _salespersonId,
                              decoration: InputDecoration(
                                prefixIcon: const PhosphorIcon(PhosphorIconsRegular.user),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                                filled: true,
                                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                              ),
                              hint: const Text('Select Salesperson (Required)'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: null,
                                  child: Text('None'),
                                ),
                                ...staffList.map((s) => DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text(s.name),
                                )),
                              ],
                              onChanged: (v) => setState(() => _salespersonId = v),
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
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),

                    ..._items.map((item) => _buildItemRow(item, cs, theme)),
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
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Ksh ${_computeSubtotal().toStringAsFixed(0)}',
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
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g., Net 30 payment terms',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const PhosphorIcon(PhosphorIconsBold.floppyDisk),
                      label: Text(
                        _isLoading ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  }

  Widget _buildItemRow(_EditableSaleItem item, ColorScheme cs, ThemeData theme) {
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
          TextFormField(
            controller: item.nameCtr,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Product Name',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            textCapitalization: TextCapitalization.words,
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
                    labelText: 'Qty',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final qty = int.tryParse(v ?? '');
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
                    labelText: 'Unit Price (Ksh)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
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
                  Text('Total', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    'Ksh ${((double.tryParse(item.priceCtr.text) ?? 0) * (int.tryParse(item.qtyCtr.text) ?? 0)).toStringAsFixed(0)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
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
  final int initialQty;
  final double initialPrice;

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
  }) {
    nameCtr = TextEditingController(text: initialName);
    qtyCtr = TextEditingController(text: initialQty.toString());
    priceCtr = TextEditingController(text: initialPrice.toStringAsFixed(0));
  }

  void dispose() {
    nameCtr.dispose();
    qtyCtr.dispose();
    priceCtr.dispose();
  }
}
