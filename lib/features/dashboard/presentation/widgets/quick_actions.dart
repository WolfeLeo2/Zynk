import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:phosphor_flutter/phosphor_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS ROW (MOBILE)
// ─────────────────────────────────────────────────────────────────────────────

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _MobileQuickAction(
                icon: PhosphorIconsDuotone.package,
                label: 'Products',
                color: colorScheme.primary,
                onTap: () => context.push('/products'),
              ),
              const SizedBox(width: 12),
              _MobileQuickAction(
                icon: PhosphorIconsBold.plus,
                label: 'Add',
                color: colorScheme.secondary,
                onTap: () => context.push('/products/add'),
              ),
              const SizedBox(width: 12),
              _MobileQuickAction(
                icon: PhosphorIconsBold.cashRegister,
                label: 'POS',
                color: colorScheme.tertiary,
                onTap: () => context.push('/pos'),
              ),
              const SizedBox(width: 12),
              _MobileQuickAction(
                icon: PhosphorIconsBold.users,
                label: 'Staff',
                color: colorScheme.primary,
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileQuickAction extends StatelessWidget {
  final PhosphorIconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MobileQuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            PhosphorIcon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS DESKTOP
// ─────────────────────────────────────────────────────────────────────────────

class QuickActionsDesktop extends StatelessWidget {
  const QuickActionsDesktop({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final actions = [
      _ActionData(
        'Open POS',
        PhosphorIconsBold.cashRegister,
        () => context.push('/pos'),
      ),
      _ActionData(
        'Products',
        PhosphorIconsDuotone.package,
        () => context.push('/products'),
      ),
      _ActionData(
        'Add Item',
        PhosphorIconsBold.plus,
        () => context.push('/products/add'),
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...actions.asMap().entries.map((entry) {
              final action = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActionButton(
                  label: action.label,
                  icon: action.icon,
                  onTap: action.onTap,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final PhosphorIconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            PhosphorIcon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            PhosphorIcon(
              PhosphorIconsRegular.caretRight,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionData {
  final String label;
  final PhosphorIconData icon;
  final VoidCallback onTap;

  _ActionData(this.label, this.icon, this.onTap);
}
