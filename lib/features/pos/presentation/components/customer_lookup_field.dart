import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/features/customers/providers/customer_providers.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

class CustomerLookupField extends ConsumerStatefulWidget {
  final Customer? selectedCustomer;
  final ValueChanged<Customer> onSelected;
  final VoidCallback onClear;
  final Future<void> Function(String name, String phone, String email)
  onCreateNew;

  const CustomerLookupField({
    super.key,
    this.selectedCustomer,
    required this.onSelected,
    required this.onClear,
    required this.onCreateNew,
  });

  @override
  ConsumerState<CustomerLookupField> createState() =>
      _CustomerLookupFieldState();
}

class _CustomerLookupFieldState extends ConsumerState<CustomerLookupField> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedCustomer != null) {
      _searchCtrl.text = widget.selectedCustomer!.name;
    }
    _focusNode.addListener(() {
      setState(() {
        _showSuggestions = _focusNode.hasFocus;
      });
    });
  }

  @override
  void didUpdateWidget(covariant CustomerLookupField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedCustomer?.id != oldWidget.selectedCustomer?.id) {
      if (widget.selectedCustomer != null) {
        _searchCtrl.text = widget.selectedCustomer!.name;
      } else {
        _searchCtrl.clear();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return customers;
    return customers.where((c) {
      return c.name.toLowerCase().contains(q) ||
          (c.phone?.contains(q) ?? false) ||
          (c.email?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  void _showAddCustomerDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _AddCustomerDialog(onCreateNew: widget.onCreateNew);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final customersAsync = ref.watch(allCustomersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  labelText: 'Customer',
                  prefixIcon: PhosphorIcon(
                    PhosphorIconsRegular.addressBook,
                    color: widget.selectedCustomer != null
                        ? cs.primary
                        : cs.onSurfaceVariant,
                  ),
                  suffixIcon: widget.selectedCustomer != null
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () {
                            widget.onClear();
                            _searchCtrl.clear();
                            _focusNode.requestFocus();
                          },
                        )
                      : null,
                  // Border is inherited from app_theme.dart inputDecorationTheme
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (val) {
                  if (widget.selectedCustomer != null) {
                    widget.onClear();
                  }
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _showAddCustomerDialog,
                icon: PhosphorIcon(
                  PhosphorIconsBold.plus,
                  color: cs.onPrimaryContainer,
                ),
                tooltip: 'Add Customer',
              ),
            ),
          ],
        ),
        if (_showSuggestions && customersAsync.hasValue) ...[
          const SizedBox(height: 4),
          Card(
            margin: EdgeInsets.zero,
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: Material(
                color: Colors.transparent,
                child: Builder(
                  builder: (context) {
                    final filtered = _filterCustomers(
                      customersAsync.value ?? [],
                    );
                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No customers found',
                          style: theme.textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final c = filtered[index];
                        return ListTile(
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: c.phone != null ? Text(c.phone!) : null,
                          onTap: () {
                            _searchCtrl.text = c.name;
                            _focusNode.unfocus();
                            widget.onSelected(c);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddCustomerDialog extends StatefulWidget {
  final Future<void> Function(String name, String phone, String email)
  onCreateNew;

  const _AddCustomerDialog({required this.onCreateNew});

  @override
  State<_AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<_AddCustomerDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isPhoneValid = false;
  String _completePhone = '';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || !_isPhoneValid) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.onCreateNew(name, _completePhone, _emailCtrl.text.trim());
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding customer: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Customer'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            IntlPhoneField(
              controller: _phoneCtrl,
              initialCountryCode: 'KE',
              decoration: const InputDecoration(
                labelText: 'Phone *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (phone) {
                _completePhone = phone.completeNumber;
                setState(() {
                  _isPhoneValid = phone.isValidNumber();
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              (_nameCtrl.text.trim().isNotEmpty &&
                  _isPhoneValid &&
                  !_isSubmitting)
              ? _submit
              : null,
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Customer'),
        ),
      ],
    );
  }
}
