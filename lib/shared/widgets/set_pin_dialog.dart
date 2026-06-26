import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/services/auth_service.dart';

/// Owner-only dialog to set/reset a login PIN for [member] (which may be the
/// owner's own profile). Used from the User Accounts screen and Settings.
class SetPinDialog extends ConsumerStatefulWidget {
  final Profile member;

  const SetPinDialog({super.key, required this.member});

  @override
  ConsumerState<SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends ConsumerState<SetPinDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authServiceProvider).setStaffPin(
            targetProfileId: widget.member.id,
            pin: _pinController.text,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login PIN set for ${widget.member.displayName ?? 'this account'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Surface the server message (e.g. "That PIN is already in use").
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validatePin(String? v) {
    if (v == null || v.isEmpty) return 'Please enter a PIN';
    if (!RegExp(r'^\d{6,}$').hasMatch(v)) return 'PIN must be at least 6 digits';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Login PIN'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set a login PIN for ${widget.member.displayName ?? 'this account'}. '
              'It is used to sign in quickly on a shared device.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pinController,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'PIN (6+ digits)',
                border: const OutlineInputBorder(),
                prefixIcon: const PhosphorIcon(PhosphorIconsRegular.password),
                suffixIcon: IconButton(
                  icon: PhosphorIcon(
                    _obscure
                        ? PhosphorIconsRegular.eyeClosed
                        : PhosphorIconsRegular.eye,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: _validatePin,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscure,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
                prefixIcon: PhosphorIcon(PhosphorIconsRegular.password),
              ),
              validator: (v) =>
                  v != _pinController.text ? 'PINs do not match' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Set PIN'),
        ),
      ],
    );
  }
}
