import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_tokens.dart';
import 'providers/biometric_provider.dart';
import 'widgets/auth_nav_button.dart';
import 'widgets/auth_progress_bar.dart';
import 'widgets/auth_pin_pad.dart';

enum _SetupState { biometricPrompt, createPin, confirmPin }

class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen>
    with SingleTickerProviderStateMixin {
  _SetupState _currentState = _SetupState.biometricPrompt;
  final List<int> _pin1 = [];
  final List<int> _pin2 = [];
  static const int _pinLength = 6;

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
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onBack() {
    if (_currentState == _SetupState.confirmPin) {
      setState(() {
        _currentState = _SetupState.createPin;
        _pin2.clear();
        _pinError = false;
      });
    } else if (_currentState == _SetupState.createPin) {
      setState(() {
        _currentState = _SetupState.biometricPrompt;
        _pin1.clear();
        _pinError = false;
      });
    } else {
      context.go('/verify-email');
    }
  }

  void _onNumberTap(int number) {
    if (_currentState == _SetupState.createPin) {
      if (_pin1.length < _pinLength) {
        setState(() => _pin1.add(number));
        if (_pin1.length == _pinLength) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() => _currentState = _SetupState.confirmPin);
            }
          });
        }
      }
    } else if (_currentState == _SetupState.confirmPin) {
      if (_pin2.length < _pinLength) {
        setState(() {
          _pin2.add(number);
          _pinError = false;
        });
        if (_pin2.length == _pinLength) {
          _verifyPin();
        }
      }
    }
  }

  void _onDeleteTap() {
    if (_currentState == _SetupState.createPin && _pin1.isNotEmpty) {
      setState(() => _pin1.removeLast());
    } else if (_currentState == _SetupState.confirmPin && _pin2.isNotEmpty) {
      setState(() {
        _pin2.removeLast();
        _pinError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final p1 = _pin1.join();
    final p2 = _pin2.join();

    if (p1 == p2) {
      await ref.read(pinProvider.notifier).setPin(p1);
      if (mounted) {
        // Mark as checked so we don't immediately lock the user after setup
        ref.read(biometricCheckedProvider.notifier).markChecked();
        context.go('/');
      }
    } else {
      _shakeController.forward(from: 0);
      setState(() {
        _pinError = true;
        _pin2.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isBioSupported = ref.watch(biometricSupportedProvider).value ?? false;

    // Skip biometric prompt entirely if not supported
    if (_currentState == _SetupState.biometricPrompt && !isBioSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentState = _SetupState.createPin);
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  AuthNavButton(
                    icon: PhosphorIconsDuotone.arrowLeft,
                    onTap: _onBack,
                  ),
                  const Spacer(),
                  Text(
                    'Step 4 of 4',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── PROGRESS BAR ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: const AuthProgressBar(currentStep: 3, totalSteps: 4),
            ),

            // ── CONTENT ──
            Expanded(
              child: _currentState == _SetupState.biometricPrompt
                  ? _buildBiometricPrompt(theme)
                  : _buildPinSetup(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricPrompt(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTokens.brandPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              PhosphorIconsDuotone.fingerprint,
              size: 40,
              color: AppTokens.brandPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Enable Biometrics',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Fast and secure access using your fingerprint or Face ID.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () async {
                await ref
                    .read(biometricEnabledProvider.notifier)
                    .setEnabled(true);
                if (mounted)
                  setState(() => _currentState = _SetupState.createPin);
              },
              icon: const Icon(PhosphorIconsBold.scan),
              label: const Text('Enable Biometrics'),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () {
                setState(() => _currentState = _SetupState.createPin);
              },
              child: const Text('Skip & Use PIN'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinSetup(ThemeData theme) {
    final isCreating = _currentState == _SetupState.createPin;
    final activePin = isCreating ? _pin1 : _pin2;
    final successColor = theme.colorScheme.secondary;

    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: successColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: PhosphorIcon(
            PhosphorIconsDuotone.password,
            color: successColor,
            size: 40,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          isCreating ? 'Create a PIN' : 'Confirm PIN',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isCreating
              ? 'Enter a 6-digit PIN for backup access'
              : 'Re-enter your PIN to confirm',
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
              final filled = i < activePin.length;
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
                        ? (_pinError ? theme.colorScheme.error : successColor)
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
            'PINs do not match. Try again.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        const Spacer(),
        // ── NUMPAD ──
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: AuthPinPad(
            onNumberTap: _onNumberTap,
            onDeleteTap: _onDeleteTap,
            onBiometricTap: () {}, // Not used here
            showBiometricIcon: false,
          ),
        ),
      ],
    );
  }
}
