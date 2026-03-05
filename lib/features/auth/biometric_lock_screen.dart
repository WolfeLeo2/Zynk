import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'providers/biometric_provider.dart';
import 'widgets/auth_pin_pad.dart';

/// Shown after sign-in when the user has biometrics / PIN set up.
/// Provides two unlock paths:
///   1. Biometric (Face ID / Fingerprint) — triggered automatically on mount
///   2. 6-digit PIN fallback
///
/// On success, calls [onUnlocked].
class BiometricLockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  final bool hasBiometrics;

  const BiometricLockScreen({
    super.key,
    required this.onUnlocked,
    this.hasBiometrics = true,
  });

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen>
    with SingleTickerProviderStateMixin {
  final LocalAuthentication _auth = LocalAuthentication();
  final List<int> _pin = [];
  static const int _pinLength = 6;

  bool _showPin = false;
  bool _isAuthenticating = false;
  bool _pinError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

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
    setState(() {
      _isAuthenticating = true;
      _pinError = false;
    });

    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Please authenticate to unlock Zynk',
        biometricOnly: true,
      );

      if (authenticated && mounted) {
        widget.onUnlocked();
      }
    } on PlatformException catch (_) {
      // Ignored for fallback
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  void _onNumberTap(int number) {
    if (_pin.length < _pinLength) {
      setState(() {
        _pin.add(number);
        _pinError = false;
      });

      if (_pin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onDeleteTap() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
        _pinError = false;
      });
    }
  }

  void _verifyPin() {
    final correctPin = ref.read(pinProvider);
    final enteredPin = _pin.join();

    if (correctPin != null && enteredPin == correctPin) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          widget.onUnlocked();
        }
      });
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
                  const Spacer(),
                  if (!_showPin)
                    TextButton(
                      onPressed: () => setState(() => _showPin = true),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
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
              'Unlock Zynk',
              style: theme.textTheme.headlineMedium?.copyWith(
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
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const Spacer(),

            // ── KEYPAD ──
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: AuthPinPad(
                showBiometricIcon: widget.hasBiometrics,
                onBiometricTap: _authenticateBio,
                onNumberTap: _onNumberTap,
                onDeleteTap: _onDeleteTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
