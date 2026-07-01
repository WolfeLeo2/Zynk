import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:path/path.dart' as path;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/services/auth_service.dart';
import 'package:zynk/core/utils/error_messages.dart';
import 'package:zynk/features/auth/providers/lock_provider.dart';
import 'package:zynk/features/auth/widgets/auth_nav_button.dart';
import 'package:zynk/features/auth/widgets/auth_progress_bar.dart';

import '../../core/theme/app_tokens.dart';

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
  final _businessAddressController = TextEditingController();

  String _businessPhone = '';
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  XFile? _logoFile;
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _obscurePassword = true;
  int _currentStep = 0;

  static const int _totalSteps = 4;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _businessAddressController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      // Only steps 0 and 1 are in the PageView
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
      String? logoUrl;
      if (_logoFile != null) {
        final fileExt = path.extension(_logoFile!.path);
        final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
        final filePath = 'tenant_logos/$fileName';

        final bytes = await _logoFile!.readAsBytes();
        await Supabase.instance.client.storage
            .from('logos')
            .uploadBinary(filePath, bytes);

        logoUrl = Supabase.instance.client.storage
            .from('logos')
            .getPublicUrl(filePath);
      }

      await auth.signUpOwner(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        shopName: _shopNameController.text.trim(),
        ownerName: _ownerNameController.text.trim(),
        businessAddress: _businessAddressController.text.trim(),
        businessPhone: _businessPhone,
        logoUrl: logoUrl,
      );
      ref.read(lockProvider.notifier).unlock();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Shop created! Check your email to confirm.',
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
        // Proceed to Email Verification step
        context.go('/verify-email', extra: _emailController.text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e)),
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
                  AuthNavButton(
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
              child: AuthProgressBar(
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
                      addressController: _businessAddressController,
                      onPhoneChanged: (phone) {
                        _businessPhone = phone;
                      },
                      logoFile: _logoFile,
                      onPickLogo: () async {
                        final file = await _imagePicker.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          maxHeight: 512,
                        );
                        if (file != null) {
                          setState(() => _logoFile = file);
                        }
                      },
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
                                  _currentStep < 1
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
  final TextEditingController addressController;
  final Function(String) onPhoneChanged;
  final XFile? logoFile;
  final VoidCallback onPickLogo;

  const _StepOne({
    required this.shopNameController,
    required this.ownerNameController,
    required this.addressController,
    required this.onPhoneChanged,
    this.logoFile,
    required this.onPickLogo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // PhosphorIcon
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

          // Logo Upload
          Center(
            child: GestureDetector(
              onTap: onPickLogo,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      image: logoFile != null
                          ? DecorationImage(
                              image: kIsWeb
                                  ? NetworkImage(logoFile!.path)
                                  : FileImage(File(logoFile!.path))
                                        as ImageProvider,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: logoFile == null
                        ? PhosphorIcon(
                            PhosphorIconsRegular.camera,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: PhosphorIcon(
                        PhosphorIconsRegular.pencilSimple,
                        size: 14,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Business Logo',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'e.g. Jane Wanjiku',
              prefixIcon: PhosphorIcon(PhosphorIconsDuotone.user, size: 20),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 20),

          _FieldLabel('Business Address'),
          const SizedBox(height: 8),
          TextFormField(
            controller: addressController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. Kenyatta Ave, Nairobi',
              prefixIcon: PhosphorIcon(PhosphorIconsDuotone.mapPin, size: 20),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 20),

          _FieldLabel('Business Phone'),
          const SizedBox(height: 8),
          IntlPhoneField(
            decoration: const InputDecoration(
              hintText: 'e.g. 700 123 456',
              prefixIcon: PhosphorIcon(PhosphorIconsDuotone.phone, size: 20),
            ),
            initialCountryCode: 'KE',
            onChanged: (phone) {
              onPhoneChanged(phone.completeNumber);
            },
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
          // PhosphorIcon
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
