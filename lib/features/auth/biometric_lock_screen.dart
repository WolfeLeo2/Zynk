import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shown after sign-in when the user has biometrics / PIN set up.
/// Provides two unlock paths:
///   1. Biometric (Face ID / Fingerprint) — triggered automatically on mount
///   2. 6-digit PIN fallback
///
/// On success, calls [onUnlocked].
class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final bool hasBiometrics;

  const BiometricLockScreen({
    super.key,
    required this.onUnlocked,
    this.hasBiometrics = true,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  final List<int> _pin = [];
  static const int _pinLength = 6;

  bool _showPin = false;
  bool _isAuthenticating = false;
  bool _pinError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // In a real app, this would come from secure storage
  // For demo purposes we use a fixed PIN
  static const String _correctPin = '123456';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 12).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    if (widget.hasBiometrics) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticateBio());
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _authenticateBio() async {
    if (_isAuthenticating) return;
    setState(() => _isAuthenticating = true);

    try {
      final bool canAuth =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuth) {
        setState(() {
          _isAuthenticating = false;
          _showPin = true;
        });
        return;
      }

      final bool didAuth = await _auth.authenticate(
        localizedReason: 'Authenticate to access Zynk',
        biometricOnly: false,
      );

      if (didAuth && mounted) {
        widget.onUnlocked();
      }
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      if (mounted) setState(() => _showPin = true);
    } finally {
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  void _onKeyPress(int digit) {
    if (_pin.length >= _pinLength) return;
    setState(() {
      _pin.add(digit);
      _pinError = false;
    });
    if (_pin.length == _pinLength) {
      _verifyPin();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin.removeLast();
      _pinError = false;
    });
  }

  void _verifyPin() {
    final entered = _pin.join();
    if (entered == _correctPin) {
      widget.onUnlocked();
    } else {
      _shakeController.forward(from: 0);
      setState(() {
        _pinError = true;
        _pin.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use AppTheme and AppTokens for consistent theming
    final successColor = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  // Step progress dots (4 segments, last active)
                  Row(
                    children: List.generate(4, (i) {
                      final isActive = i == 3;
                      return Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 28,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isActive
                              ? successColor
                              : Theme.of(context).colorScheme.outline,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  if (!_showPin)
                    TextButton(
                      onPressed: () => setState(() => _showPin = true),
                      style: TextButton.styleFrom(
                        foregroundColor: successColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      child: const Text(
                        'Use PIN',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // ── ICON ──
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: PhosphorIcon(
                _showPin
                    ? PhosphorIconsDuotone.lock
                    : PhosphorIconsDuotone.fingerprint,
                color: successColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),

            // ── TITLE ──
            Text(
              'Secure Your Account',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _showPin
                  ? 'Enter your 6-digit PIN'
                  : 'Use biometrics for quick access',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 40),

            // ── PIN DOTS ──
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _shakeController.isAnimating
                        ? _shakeAnimation.value *
                              ((_shakeController.value * 10).round().isEven
                                  ? 1
                                  : -1)
                        : 0,
                    0,
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (i) {
                  final filled = i < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_pinError ? theme.colorScheme.error : successColor)
                          : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? (_pinError
                                  ? theme.colorScheme.error
                                  : successColor)
                            : theme.colorScheme.outline,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),

            if (_pinError) ...[
              const SizedBox(height: 12),
              Text(
                'Incorrect PIN. Try again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],

            if (_showPin) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _showPin = false),
                style: TextButton.styleFrom(foregroundColor: successColor),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PhosphorIcon(PhosphorIconsDuotone.eyeSlash, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'SHOW PIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // ── KEYPAD ──
            if (_showPin) ...[
              _Keypad(
                onDigit: _onKeyPress,
                onDelete: _onDelete,
                onBiometric: widget.hasBiometrics ? _authenticateBio : null,
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Biometric prompt button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: OutlinedButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticateBio,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: successColor,
                    side: BorderSide(color: successColor),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isAuthenticating
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: successColor,
                            strokeWidth: 2,
                          ),
                        )
                      : PhosphorIcon(PhosphorIconsDuotone.fingerprint),
                  label: Text(
                    _isAuthenticating ? 'Authenticating…' : 'Authenticate',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ],
        ),
      ),
    );
  }
}

// ── NUMERIC KEYPAD ──
class _Keypad extends StatelessWidget {
  final void Function(int) onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;

  const _Keypad({
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          _keyRow(context, [1, 2, 3]),
          const SizedBox(height: 12),
          _keyRow(context, [4, 5, 6]),
          const SizedBox(height: 12),
          _keyRow(context, [7, 8, 9]),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Biometric or empty
              SizedBox(
                width: 72,
                height: 72,
                child: onBiometric != null
                    ? _KeyButton(
                        onTap: onBiometric!,
                        child: PhosphorIcon(
                          PhosphorIconsDuotone.fingerprint,
                          color: Theme.of(context).colorScheme.secondary,
                          size: 28,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // 0
              SizedBox(
                width: 72,
                height: 72,
                child: _KeyButton(
                  onTap: () => onDigit(0),
                  child: Text(
                    '0',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              // Delete
              SizedBox(
                width: 72,
                height: 72,
                child: _KeyButton(
                  onTap: onDelete,
                  child: PhosphorIcon(
                    PhosphorIconsDuotone.backspace,
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyRow(BuildContext context, List<int> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits
          .map(
            (d) => SizedBox(
              width: 72,
              height: 72,
              child: _KeyButton(
                onTap: () => onDigit(d),
                child: Text(
                  '$d',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _KeyButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(36),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(36),
        splashColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.2),
        child: Center(child: child),
      ),
    );
  }
}
