import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_tokens.dart';
import 'widgets/auth_nav_button.dart';
import 'widgets/auth_progress_bar.dart';
import 'widgets/auth_pin_pad.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String? email;

  const VerifyEmailScreen({super.key, required this.email});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  final List<int> _pin = [];
  static const int _pinLength = 6;
  bool _isLoading = false;
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

  void _onNumberTap(int number) {
    if (_isLoading) return;

    if (_pin.length < _pinLength) {
      setState(() {
        _pin.add(number);
        _pinError = false;
      });

      if (_pin.length == _pinLength) {
        _verifyCode();
      }
    }
  }

  void _onDeleteTap() {
    if (_isLoading) return;

    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
        _pinError = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (widget.email == null || widget.email!.isEmpty) {
      _showError('No email found. Please restart signup.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = _pin.join();
      final res = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email!,
        token: token,
      );

      // Successfully verified
      if (mounted && res.session != null) {
        // Router handles redirection based on auth state changes
      }
    } on AuthException catch (e) {
      if (mounted) {
        _shakeController.forward(from: 0);
        setState(() {
          _pinError = true;
          _isLoading = false;
          _pin.clear();
        });
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _pin.clear();
        });
        _showError(e.toString());
      }
    }
  }

  Future<void> _resendCode() async {
    if (widget.email == null) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email!,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('New code sent!'),
            backgroundColor: AppTokens.brandPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to resend code: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTokens.brandAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final successColor = colorScheme.secondary;

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
                    onTap: () => context.go('/login'),
                  ),
                  const Spacer(),
                  Text(
                    'Step 3 of 4',
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
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: AuthProgressBar(currentStep: 2, totalSteps: 4),
            ),

            const Spacer(),

            // ── CONTENT ──
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: successColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                PhosphorIconsDuotone.envelopeOpen,
                size: 40,
                color: successColor,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Enter verification code',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sent to \${widget.email ?? "your email"}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),

            // ── PIN DOTS ──
            if (_isLoading)
              const SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
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
                child: SizedBox(
                  height: 48,
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
                              ? (_pinError ? colorScheme.error : successColor)
                              : Colors.transparent,
                          border: Border.all(
                            color: filled
                                ? (_pinError ? colorScheme.error : successColor)
                                : colorScheme.outline,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

            if (_pinError) ...[
              const SizedBox(height: 12),
              Text(
                'Incorrect code. Try again.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            // ── RESEND BUTTON ──
            const SizedBox(height: 12),
            TextButton(
              onPressed: _isLoading ? null : _resendCode,
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.secondary,
              ),
              child: const Text(
                'Resend Code',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            const Spacer(),

            // ── KEYPAD ──
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: AuthPinPad(
                showBiometricIcon: false,
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
