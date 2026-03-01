import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/services/app_logger.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';
import 'package:zynk/features/sales/providers/sales_providers.dart';

final _log = AppLogger('Checkout');

/// Full-screen checkout sheet inspired by Square POS / Shopify POS.
/// Shows order summary → payment method selection → processing → success.
class CheckoutSheet extends ConsumerStatefulWidget {
  final List<PosCartItem> items;
  final double total;
  final Customer? customer;
  final String? salespersonName;
  final VoidCallback onComplete;

  const CheckoutSheet({
    super.key,
    required this.items,
    required this.total,
    this.customer,
    this.salespersonName,
    required this.onComplete,
  });

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

enum _CheckoutStep { review, payment, processing, success }

class _CheckoutSheetState extends ConsumerState<CheckoutSheet>
    with SingleTickerProviderStateMixin {
  _CheckoutStep _step = _CheckoutStep.review;
  String _selectedPayment = 'cash';
  String? _invoiceNumber;
  String? _errorMessage;
  late AnimationController _successController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _step = _CheckoutStep.processing;
      _errorMessage = null;
    });

    try {
      // ── Wait for branch to finish loading (handles race condition) ──
      var branchState = ref.read(branchSelectionProvider);
      if (branchState.isLoading || branchState.selectedBranchId == null) {
        _log.d('Branch still loading, waiting...');
        for (int i = 0; i < 15; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          branchState = ref.read(branchSelectionProvider);
          if (!branchState.isLoading && branchState.selectedBranchId != null) {
            break;
          }
        }
      }

      final tenantId = ref.read(tenantIdProvider);
      var branchId = branchState.selectedBranchId;

      // Last-resort fallback: grab first branch from stream
      if (branchId == null) {
        final branches = ref.read(branchesProvider).value ?? [];
        if (branches.isNotEmpty) {
          branchId = branches.first.id;
          _log.i('Fallback: using first branch ${branches.first.name}');
          ref.read(branchSelectionProvider.notifier).selectBranch(branchId);
        }
      }

      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      _log.d('──── CHECKOUT DEBUG ────');
      _log.d('tenantId: $tenantId');
      _log.d('branchId: $branchId');
      _log.d('session exists: ${session != null}');
      _log.d('user.id: ${user?.id}');
      _log.d('────────────────────────');

      if (tenantId == null || branchId == null) {
        final missing = <String>[];
        if (tenantId == null) missing.add('tenant');
        if (branchId == null) missing.add('branch');
        _log.e('Missing: ${missing.join(", ")}');
        throw Exception(
          '${missing.join(" and ")} not selected. '
          'Please go to Settings and select a branch.',
        );
      }

      if (branchId == 'all') {
        throw Exception('Please select a specific branch to complete a sale.');
      }

      final salesService = ref.read(salesServiceProvider);

      final result = await salesService.completePOSSale(
        tenantId: tenantId,
        branchId: branchId,
        customerId: widget.customer?.id,
        salespersonName: widget.salespersonName,
        cartItems: widget.items,
        paymentMethod: _selectedPayment,
      );

      _invoiceNumber = result['invoice_number'] as String?;
      _log.i('Sale completed: $_invoiceNumber');

      setState(() => _step = _CheckoutStep.success);
      _successController.forward();

      // Auto-close after 2 seconds
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        widget.onComplete();
        Navigator.of(context).pop();
      }
    } catch (e, stack) {
      _log.e('Payment failed: $e');
      _log.e('Stack trace: $stack');
      setState(() {
        _step = _CheckoutStep.payment;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: switch (_step) {
            _CheckoutStep.review => _buildReview(theme, cs),
            _CheckoutStep.payment => _buildPayment(theme, cs),
            _CheckoutStep.processing => _buildProcessing(theme, cs),
            _CheckoutStep.success => _buildSuccess(theme, cs),
          },
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 1: ORDER REVIEW
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildReview(ThemeData theme, ColorScheme cs) {
    return Column(
      key: const ValueKey('review'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle bar
        _dragHandle(cs),
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const PhosphorIcon(PhosphorIconsRegular.x, size: 22),
              ),
              const SizedBox(width: 8),
              Text(
                'Review Order',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${widget.items.length} items',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Items list (scrollable, max height)
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.35,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: widget.items.length,
            itemBuilder: (_, i) {
              final item = widget.items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    // Qty badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${item.quantity}x',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name
                    Expanded(
                      child: Text(
                        item.product.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    // Price
                    Text(
                      'Ksh ${item.total.toStringAsFixed(0)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Total bar
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: cs.outline.withValues(alpha: 0.2)),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Ksh ${widget.total.toStringAsFixed(0)}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () =>
                      setState(() => _step = _CheckoutStep.payment),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Continue to Payment',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 2: PAYMENT METHOD SELECTION
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildPayment(ThemeData theme, ColorScheme cs) {
    return Column(
      key: const ValueKey('payment'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _dragHandle(cs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _step = _CheckoutStep.review),
                icon: const PhosphorIcon(
                  PhosphorIconsRegular.caretLeft,
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Payment Method',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Error message
        if (_errorMessage != null)
          Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                PhosphorIcon(
                  PhosphorIconsRegular.warning,
                  size: 20,
                  color: cs.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Payment options
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _paymentOption(
                theme,
                cs,
                icon: PhosphorIconsDuotone.money,
                label: 'Cash',
                subtitle: 'Pay with cash',
                value: 'cash',
                color: cs.secondary,
              ),
              const SizedBox(height: 12),
              _paymentOption(
                theme,
                cs,
                icon: PhosphorIconsDuotone.cellSignalFull,
                label: 'M-Pesa',
                subtitle: 'Send via STK Push',
                value: 'mpesa',
                color: const Color(0xFF4CAF50),
              ),
              const SizedBox(height: 12),
              _paymentOption(
                theme,
                cs,
                icon: PhosphorIconsDuotone.creditCard,
                label: 'Card',
                subtitle: 'Visa / Mastercard',
                value: 'card',
                color: const Color(0xFF7C4DFF),
              ),
            ],
          ),
        ),

        // Charge button
        Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _processPayment,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Charge Ksh ${widget.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentOption(
    ThemeData theme,
    ColorScheme cs, {
    required IconData icon,
    required String label,
    required String subtitle,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedPayment == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPayment = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.10)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: PhosphorIcon(icon, color: color, size: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(
                  color: isSelected ? color : cs.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 3: PROCESSING
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildProcessing(ThemeData theme, ColorScheme cs) {
    return SizedBox(
      key: const ValueKey('processing'),
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Processing payment...',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ksh ${widget.total.toStringAsFixed(0)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // STEP 4: SUCCESS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildSuccess(ThemeData theme, ColorScheme cs) {
    return SizedBox(
      key: const ValueKey('success'),
      height: 340,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 44,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Payment Successful!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ksh ${widget.total.toStringAsFixed(0)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_invoiceNumber != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _invoiceNumber!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dragHandle(ColorScheme cs) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
