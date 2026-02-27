import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/auth_service.dart';

import '../../core/theme/app_tokens.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentStep = 0;

  static const int _totalSteps = 2;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    } else {
      context.go('/login');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);
    final auth = ref.read(authServiceProvider);

    try {
      await auth.signUpOwner(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        shopName: _shopNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Shop created! Check your email to confirm',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.go('/biometric-setup');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: $e'),
            backgroundColor: AppTokens.brandAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Back button
                  _NavButton(
                    icon: PhosphorIconsDuotone.arrowLeft,
                    onTap: _prevStep,
                  ),
                  const Spacer(),
                  // Step indicator
                  Text(
                    'Step ${_currentStep + 1} of $_totalSteps',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Skip placeholder (same width as back button for centering)
                  const SizedBox(width: 40),
                ],
              ),
            ),

            // ── PROGRESS BAR ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _StepProgressBar(
                currentStep: _currentStep,
                totalSteps: _totalSteps,
              ),
            ),

            // ── PAGES ──
            Expanded(
              child: Form(
                key: _formKey,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepOne(
                      shopNameController: _shopNameController,
                      ownerNameController: _ownerNameController,
                    ),
                    _StepTwo(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      obscurePassword: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ],
                ),
              ),
            ),

            // ── BOTTOM CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _nextStep,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentStep < _totalSteps - 1
                                      ? 'Continue'
                                      : 'Create My Shop',
                                ),
                                const SizedBox(width: 8),
                                PhosphorIcon(
                                  PhosphorIconsDuotone.arrowRight,
                                  size: 18,
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: theme.textTheme.bodyMedium,
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          'Sign in',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── STEP 1: Shop & Owner Info ──
class _StepOne extends StatelessWidget {
  final TextEditingController shopNameController;
  final TextEditingController ownerNameController;

  const _StepOne({
    required this.shopNameController,
    required this.ownerNameController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: PhosphorIcon(
              PhosphorIconsDuotone.storefront,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Let's set up\nyour shop",
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your business.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 36),

          _FieldLabel('Shop / Business Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: shopNameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Mama Njeri General Store',
              prefixIcon: PhosphorIcon(
                PhosphorIconsDuotone.storefront,
                size: 20,
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 20),

          _FieldLabel('Your Full Name'),
          const SizedBox(height: 8),
          TextFormField(
            controller: ownerNameController,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Jane Wanjiku',
              prefixIcon: PhosphorIcon(PhosphorIconsDuotone.user, size: 20),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}

// ── STEP 2: Account Credentials ──
class _StepTwo extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;

  const _StepTwo({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: PhosphorIcon(
              PhosphorIconsDuotone.lock,
              color: theme.colorScheme.secondary,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Create your\naccount',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your login credentials for Zynk.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 36),

          _FieldLabel('Email Address'),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'you@store.com',
              prefixIcon: PhosphorIcon(PhosphorIconsDuotone.envelope, size: 20),
            ),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 20),

          _FieldLabel('Password'),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Min 6 characters',
              prefixIcon: PhosphorIcon(PhosphorIconsDuotone.lock, size: 20),
              suffixIcon: IconButton(
                icon: PhosphorIcon(
                  obscurePassword
                      ? PhosphorIconsDuotone.eye
                      : PhosphorIconsDuotone.eyeSlash,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 16),

          // Terms note
          Text(
            'By creating an account you agree to our Terms of Service and Privacy Policy.',
            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── STEP PROGRESS BAR ──
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepProgressBar({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (i) {
        final isActive = i <= currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ── NAV BUTTON ──
class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: PhosphorIcon(icon, size: 18),
      ),
    );
  }
}

// ── FIELD LABEL ──
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
    );
  }
}
