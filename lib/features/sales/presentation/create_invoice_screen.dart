import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';

/// Screen for creating a new B2B invoice (starts as draft).
/// Received pre-filled data from POS cart and allows editing before submission.
class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final List<PosCartItem> cartItems;
  final Customer customer;
  final String? salespersonId;

  const CreateInvoiceScreen({
    super.key,
    required this.cartItems,
    required this.customer,
    this.salespersonId,
  });

  @override
  ConsumerState<CreateInvoiceScreen> createState() =>
      _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends ConsumerState<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  DateTime? _dueDate;
  bool _isLoading = false;

  // Editable customer fields
  late TextEditingController _customerNameCtrl;
  late TextEditingController _customerPhoneCtrl;

  // Editable item fields (parallel lists)
  late List<TextEditingController> _itemNameCtrls;
  late List<TextEditingController> _itemPriceCtrls;
  late List<TextEditingController> _itemQtyCtrls;

  String? _salespersonId;

  @override
  void initState() {
    super.initState();
    _salespersonId = widget.salespersonId;
    _customerNameCtrl = TextEditingController(text: widget.customer.name);
    _customerPhoneCtrl = TextEditingController(text: widget.customer.phone ?? '');

    _itemNameCtrls = widget.cartItems
        .map((i) => TextEditingController(text: i.effectiveName))
        .toList();
    _itemPriceCtrls = widget.cartItems
        .map((i) => TextEditingController(text: i.effectivePrice.toStringAsFixed(0)))
        .toList();
    _itemQtyCtrls = widget.cartItems
        .map((i) => TextEditingController(text: i.quantity.toString()))
        .toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    for (final c in _itemNameCtrls) {
      c.dispose();
    }
    for (final c in _itemPriceCtrls) {
      c.dispose();
    }
    for (final c in _itemQtyCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  double _computeSubtotal() {
    double subtotal = 0;
    for (var i = 0; i < widget.cartItems.length; i++) {
      final price = double.tryParse(_itemPriceCtrls[i].text) ?? widget.cartItems[i].effectivePrice;
      final qty = int.tryParse(_itemQtyCtrls[i].text) ?? widget.cartItems[i].quantity;
      subtotal += price * qty;
    }
    return subtotal;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_salespersonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a salesperson before submitting.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tenantId = ref.read(tenantIdProvider);
      final branchId = ref.read(currentBranchIdProvider);
      final repo = ref.read(repositoryProvider);

      if (tenantId == null || branchId == null) {
        throw Exception('Missing tenant or branch context');
      }

      // Apply edits back onto cartItems before submitting
      final editedItems = <PosCartItem>[];
      for (var i = 0; i < widget.cartItems.length; i++) {
        final item = widget.cartItems[i];
        final qty = int.tryParse(_itemQtyCtrls[i].text) ?? item.quantity;
        if (qty <= 0) continue;

        final price = double.tryParse(_itemPriceCtrls[i].text) ?? item.effectivePrice;
        final name = _itemNameCtrls[i].text.trim().isEmpty
            ? item.effectiveName
            : _itemNameCtrls[i].text.trim();

        // Stock validation — prevent overselling
        if (!item.product.isService) {
          final stockResult = await repo.db.get(
            'SELECT quantity FROM stock WHERE product_id = ? AND branch_id = ?',
            [item.product.id, branchId],
          );
          final availableStock = (stockResult['quantity'] as num?)?.toInt() ?? 0;
          if (qty > availableStock) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Insufficient stock for "$name". Available: $availableStock',
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

        editedItems.add(
          PosCartItem(
            product: item.product,
            quantity: qty,
            overrideName: name != item.product.name ? name : null,
            overridePrice: price != item.product.basePrice ? price : null,
          ),
        );
      }

      if (editedItems.isEmpty) {
        throw Exception('No valid items to submit.');
      }

      // Update customer name/phone if changed
      final newName = _customerNameCtrl.text.trim();
      final newPhone = _customerPhoneCtrl.text.trim();
      if (newName != widget.customer.name || newPhone != (widget.customer.phone ?? '')) {
        final updatedCustomer = Customer(
          id: widget.customer.id,
          tenantId: widget.customer.tenantId,
          branchId: widget.customer.branchId,
          name: newName.isEmpty ? widget.customer.name : newName,
          phone: newPhone.isEmpty ? null : newPhone,
          email: widget.customer.email,
        );
        await repo.updateCustomer(updatedCustomer);
      }

      await ref.read(salesServiceProvider).createDraftInvoiceLocal(
            tenantId: tenantId,
            branchId: branchId,
            customerId: widget.customer.id,
            cartItems: editedItems,
            salespersonId: _salespersonId,
            notes: _notesController.text.isEmpty ? null : _notesController.text,
            dueDate: _dueDate?.toIso8601String(),
          );

      if (mounted) {
        ref.read(cartProvider.notifier).clear();
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice submitted for approval!')),
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.x),
          onPressed: () => context.pop(),
        ),
        title: const Text('Review & Create Invoice'),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Salesperson ──
            _SectionLabel('Salesperson (Optional)'),
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
                        prefixIcon: const Icon(PhosphorIconsRegular.user),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        filled: true,
                        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                      ),
                      hint: const Text('Select Salesperson (Optional)'),
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

            // ── Customer Details (Editable) ──
            _SectionLabel('Billed To'),
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
            _SectionLabel('Due Date (Optional)'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
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

            // ── Invoice Items (Editable) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel('Items'),
                Text(
                  '${widget.cartItems.length} product${widget.cartItems.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...List.generate(widget.cartItems.length, (i) {
              return _EditableItemRow(
                index: i,
                cs: cs,
                theme: theme,
                nameCtr: _itemNameCtrls[i],
                priceCtr: _itemPriceCtrls[i],
                qtyCtr: _itemQtyCtrls[i],
                onChanged: () => setState(() {}),
              );
            }),
            const SizedBox(height: 16),

            // ── Totals ──
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
                    'Estimate Total',
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
            _SectionLabel('Notes (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Net 30 payment terms',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: cs.surface,
              ),
            ),
            const SizedBox(height: 32),

            // ── Submit Button ──
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const PhosphorIcon(PhosphorIconsBold.fileText),
              label: Text(
                _isLoading ? 'Submitting...' : 'Submit Invoice',
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}



class _EditableItemRow extends StatelessWidget {
  final int index;
  final ColorScheme cs;
  final ThemeData theme;
  final TextEditingController nameCtr;
  final TextEditingController priceCtr;
  final TextEditingController qtyCtr;
  final VoidCallback onChanged;

  const _EditableItemRow({
    required this.index,
    required this.cs,
    required this.theme,
    required this.nameCtr,
    required this.priceCtr,
    required this.qtyCtr,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          // Item name
          TextFormField(
            controller: nameCtr,
            onChanged: (_) => onChanged(),
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
              // Quantity
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: qtyCtr,
                  onChanged: (_) => onChanged(),
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
              // Unit price
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: priceCtr,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: 'Unit Price (Ksh)',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                  validator: (v) {
                    final price = double.tryParse(v ?? '');
                    if (price == null || price < 0) return 'Invalid price';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Line total
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Total', style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    'Ksh ${((double.tryParse(priceCtr.text) ?? 0) * (int.tryParse(qtyCtr.text) ?? 0)).toStringAsFixed(0)}',
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
