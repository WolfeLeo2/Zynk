import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/profile_provider.dart';
import 'package:zynk/shared/widgets/app_bottom_sheet.dart';

class CustomerForm extends ConsumerStatefulWidget {
  final Customer? existing;

  const CustomerForm({super.key, this.existing});

  @override
  ConsumerState<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<CustomerForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _loyaltyPointsCtrl;
  late final TextEditingController _creditLimitCtrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.existing?.email ?? '');
    _loyaltyPointsCtrl = TextEditingController(
      text: widget.existing?.loyaltyPoints.toString() ?? '0',
    );
    _creditLimitCtrl = TextEditingController(
      text: widget.existing?.creditLimit.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _loyaltyPointsCtrl.dispose();
    _creditLimitCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final profile = ref.read(currentUserProfileProvider).value;
      if (profile == null) throw Exception('No profile found');

      final customer = Customer(
        id: widget.existing?.id ?? const Uuid().v4(),
        tenantId: profile.tenantId,
        branchId: widget.existing?.branchId ?? profile.branchId,
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        loyaltyPoints: int.tryParse(_loyaltyPointsCtrl.text) ?? 0,
        creditLimit: double.tryParse(_creditLimitCtrl.text) ?? 0,
      );

      final repo = ref.read(repositoryProvider);
      if (widget.existing == null) {
        await repo.createCustomer(customer);
      } else {
        await repo.updateCustomer(customer);
      }

      if (mounted) Navigator.pop(context);
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
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppBottomSheet(
        title: isEdit ? 'Edit Customer' : 'New Customer',
        icon: PhosphorIconsDuotone.userCirclePlus,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const PhosphorIcon(PhosphorIconsRegular.user),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const PhosphorIcon(PhosphorIconsRegular.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const PhosphorIcon(PhosphorIconsRegular.envelope),
                ),
              ),
              const SizedBox(height: 16),
              /*Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _loyaltyPointsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Loyalty Points',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const PhosphorIcon(PhosphorIconsRegular.star),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _creditLimitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Credit Limit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const PhosphorIcon(PhosphorIconsRegular.money),
                      ),
                    ),
                  ),
                ],
              ),*/
              const SizedBox(height: 32),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          isEdit ? 'Save Changes' : 'Add Customer',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
