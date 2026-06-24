import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:zynk/shared/widgets/stock_availability_label.dart';
import 'package:zynk/features/pos/providers/cart_provider.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';
import 'package:zynk/core/services/sales_service.dart';
import 'package:zynk/core/utils/currency.dart';

class CreateInvoiceScreen extends ConsumerStatefulWidget {
  final List<PosCartItem> cartItems;
  final Customer customer;
  final String? salespersonId;
  final String? branchId;

  const CreateInvoiceScreen({
    super.key,
    required this.cartItems,
    required this.customer,
    this.salespersonId,
    this.branchId,
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

  // Editable items in memory
  List<_EditableInvoiceItem> _items = [];

  String? _salespersonId;

  @override
  void initState() {
    super.initState();
    _salespersonId = widget.salespersonId;
    _customerNameCtrl = TextEditingController(text: widget.customer.name);
    _customerPhoneCtrl = TextEditingController(
      text: widget.customer.phone ?? '',
    );

    _items = widget.cartItems.map((i) => _EditableInvoiceItem(i)).toList();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double _computeSubtotal() =>
      _items.fold(0, (sum, item) => sum + item.resolvedLine().total);

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
      final branchId = widget.branchId ?? ref.read(currentBranchIdProvider);
      final repo = ref.read(repositoryProvider);

      if (tenantId == null || branchId == null) {
        throw Exception('Missing tenant or branch context');
      }

      // Apply edits onto cartItems before submitting
      final editedItems = <PosCartItem>[];
      for (final item in _items) {
        final qty = item.resolvedLine().quantity;
        if (qty <= 0) continue;

        final price = item.enteredUnitPrice;
        final name = item.nameCtr.text.trim().isEmpty
            ? item.originalItem.effectiveName
            : item.nameCtr.text.trim();

        // Stock validation — prevent overselling
        if (!item.originalItem.product.isService) {
          final availableStock = await repo.getProductStockValue(
            item.originalItem.product.id,
            branchId,
          );
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
            product: item.originalItem.product,
            quantity: qty,
            overrideName: name != item.originalItem.product.name ? name : null,
            overridePrice: item.originalItem.isSqmBased
                ? (price != item.originalItem.product.basePrice ? price : null)
                : (price != item.originalItem.product.basePrice ? price : null),
          ),
        );
      }

      if (editedItems.isEmpty) {
        throw Exception('No valid items to submit.');
      }

      // Update customer name/phone if changed
      final newName = _customerNameCtrl.text.trim();
      final newPhone = _customerPhoneCtrl.text.trim();
      if (newName != widget.customer.name ||
          newPhone != (widget.customer.phone ?? '')) {
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

      await ref
          .read(salesServiceProvider)
          .createPendingApprovalInvoiceLocal(
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const PhosphorIcon(PhosphorIconsRegular.x),
          onPressed: () => context.pop(),
        ),
        title: const Text('Create Invoice'),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              if (widget.branchId != null) {
                final branch = ref
                    .watch(branchesProvider)
                    .value
                    ?.where((b) => b.id == widget.branchId)
                    .firstOrNull;
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        branch?.name ?? '',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                );
              }

              final branches = ref.watch(branchesProvider).value ?? const [];
              final options = branches.where((b) => b.id != 'all').toList();
              if (options.length <= 1) return const SizedBox.shrink();

              final selectedId = ref.watch(currentBranchIdProvider);
              final value = options.any((b) => b.id == selectedId)
                  ? selectedId
                  : options.first.id;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    icon: const PhosphorIcon(PhosphorIconsRegular.caretDown),
                    items: options
                        .map(
                          (b) => DropdownMenuItem<String>(
                            value: b.id,
                            child: Text(b.name),
                          ),
                        )
                        .toList(),
                    onChanged: (next) {
                      if (next == null) return;
                      ref
                          .read(branchSelectionProvider.notifier)
                          .selectBranch(next);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // ── Salesperson ──
            _SectionLabel('Salesperson (Required)'),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, child) {
                final currentBranchId =
                    widget.branchId ?? ref.watch(currentBranchIdProvider);
                final staffAsync = ref.watch(
                  humanStaffByBranchProvider(currentBranchId),
                );
                return staffAsync.when(
                  data: (staffList) {
                    if (staffList.isEmpty) return const SizedBox.shrink();
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
                        fillColor: cs.surfaceContainerHighest.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      hint: const Text('Select Salesperson (Required)'),
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
                      prefixIcon: const PhosphorIcon(PhosphorIconsRegular.user),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customerPhoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Phone (optional)',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
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

            // ── Invoice Items (Editable) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionLabel('Items'),
                Text(
                  '${_items.length} product${_items.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ..._items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return _EditableItemRow(
                index: i,
                cs: cs,
                theme: theme,
                item: item,
                branchId: widget.branchId ?? ref.watch(currentBranchIdProvider),
                onChanged: () => setState(() {}),
                onRemove: () {
                  setState(() {
                    _items[i].dispose();
                    _items.removeAt(i);
                  });
                },
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
            _SectionLabel('Notes (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
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

            // ── Submit Button ──
            FilledButton.icon(
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const PhosphorIcon(PhosphorIconsBold.fileText),
              label: Text(
                _isLoading ? 'Submitting...' : 'Submit Invoice',
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _EditableInvoiceItem {
  final PosCartItem originalItem;
  late final TextEditingController nameCtr;
  late final TextEditingController priceCtr;
  late final TextEditingController qtyCtr;

  _EditableInvoiceItem(this.originalItem) {
    nameCtr = TextEditingController(text: originalItem.effectiveName);
    priceCtr = TextEditingController(
      text:
          (originalItem.isSqmBased
                  ? originalItem.pricePerSqm
                  : originalItem.effectivePrice)
              .toStringAsFixed(0),
    );
    qtyCtr = TextEditingController(
      text: originalItem.isSqmBased
          ? originalItem.totalSqm.toStringAsFixed(2)
          : originalItem.quantity.toString(),
    );
  }

  /// The per-sqm price (sqm-based) or unit price (otherwise) currently entered.
  double get enteredUnitPrice =>
      double.tryParse(priceCtr.text) ??
      (originalItem.isSqmBased
          ? originalItem.pricePerSqm
          : originalItem.effectivePrice);

  double get _enteredQty =>
      double.tryParse(qtyCtr.text) ??
      (originalItem.isSqmBased
          ? originalItem.totalSqm
          : originalItem.quantity.toDouble());

  /// Resolved pricing for this line — the single source for subtotal, the row
  /// total and submission. Delegates to [SalesService.resolveLine].
  InvoiceLine resolvedLine() => SalesService.resolveLine(
        isSqmBased: originalItem.isSqmBased,
        coveragePerBox: originalItem.coveragePerBox,
        enteredPrice: enteredUnitPrice,
        enteredQty: _enteredQty,
      );

  void dispose() {
    nameCtr.dispose();
    priceCtr.dispose();
    qtyCtr.dispose();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _EditableItemRow extends StatelessWidget {
  final int index;
  final ColorScheme cs;
  final ThemeData theme;
  final _EditableInvoiceItem item;
  final String? branchId;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _EditableItemRow({
    required this.index,
    required this.cs,
    required this.theme,
    required this.item,
    required this.branchId,
    required this.onChanged,
    required this.onRemove,
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
          StockAvailabilityLabel(
            productId: item.originalItem.product.id,
            branchId: branchId,
          ),
          Row(
            children: [
              // Item name
              Expanded(
                child: TextFormField(
                  controller: item.nameCtr,
                  onChanged: (_) => onChanged(),
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
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: item.originalItem.isSqmBased ? 'sqm' : 'Qty',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  keyboardType: item.originalItem.isSqmBased
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  inputFormatters: [
                    if (item.originalItem.isSqmBased)
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
              // Unit price
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: item.priceCtr,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    labelText: item.originalItem.isSqmBased
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
          if (item.originalItem.isSqmBased) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final line = item.resolvedLine();
                final actualSqm = line.quantity * item.originalItem.coveragePerBox;
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
