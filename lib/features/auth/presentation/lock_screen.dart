import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/features/auth/providers/lock_provider.dart';

/// PIN entry shown when the app is locked. The active device session stays
/// alive (sync keeps running); a correct PIN signs in the matching staffer via
/// `loginWithPin` and unlocks. Online-only (a switch is a real auth call).
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  static const _minPinLength = 6;
  String _pin = '';
  bool _loading = false;
  String? _error;

  void _onDigit(String d) {
    if (_loading || _pin.length >= 12) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_loading || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    final tenantId = ref.read(tenantIdProvider);
    if (tenantId == null) {
      setState(() => _error = 'Session expired — please sign in again.');
      return;
    }
    if (_pin.length < _minPinLength) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).loginWithPin(
            tenantId: tenantId,
            pin: _pin,
          );
      if (!mounted) return;
      // Unlock — the new staffer's profile loads behind the welcome screen.
      ref.read(lockProvider.notifier).unlock();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _pin = '';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tenantName = ref.watch(currentTenantProvider).value?.name;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: PhosphorIcon(
                      PhosphorIconsDuotone.lockKey,
                      size: 28,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tenantName ?? 'Locked',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your PIN to continue',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PinDots(length: _pin.length, error: _error != null),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 20,
                    child: _error != null
                        ? Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.error,
                            ),
                            textAlign: TextAlign.center,
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _Keypad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    onSubmit: _submit,
                    canSubmit: _pin.length >= _minPinLength && !_loading,
                    loading: _loading,
                  ),
                  const SizedBox(height: 8),
                  // Escape hatch: switch the device account / recover a forgotten
                  // PIN by signing in with a password again.
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => ref.read(authServiceProvider).signOut(),
                    child: const Text('Sign out & use password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;
  final bool error;
  const _PinDots({required this.length, required this.error});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Show a filled dot per entered digit, with a minimum of 6 placeholders.
    final count = length < 6 ? 6 : length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < length
                  ? (error ? cs.error : cs.primary)
                  : cs.surfaceContainerHighest,
            ),
          ),
      ],
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;
  final bool canSubmit;
  final bool loading;

  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
    required this.canSubmit,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    Widget digit(String d) => _KeyButton(
          onPressed: () => onDigit(d),
          child: Text(d, style: Theme.of(context).textTheme.headlineSmall),
        );

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) digit(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _KeyButton(
              onPressed: onBackspace,
              child: const PhosphorIcon(PhosphorIconsRegular.backspace),
            ),
            digit('0'),
            _KeyButton(
              onPressed: canSubmit ? onSubmit : null,
              filled: true,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const PhosphorIcon(PhosphorIconsBold.arrowRight),
            ),
          ],
        ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool filled;
  const _KeyButton({required this.child, this.onPressed, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Material(
          color: filled
              ? (onPressed == null ? cs.surfaceContainerHighest : cs.primary)
              : cs.surfaceContainerHigh,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: IconTheme(
                data: IconThemeData(
                  color: filled ? cs.onPrimary : cs.onSurface,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
