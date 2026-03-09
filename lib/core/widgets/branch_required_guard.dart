import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';

/// Wraps any create/write screen and blocks access when "All Branches" is
/// selected. Shows a contextual prompt to pick a specific branch first.
///
/// Usage:
/// ```dart
/// return BranchRequiredGuard(child: PosScreen());
/// ```
class BranchRequiredGuard extends ConsumerWidget {
  final Widget child;
  final String? actionLabel;

  const BranchRequiredGuard({required this.child, this.actionLabel, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAll = ref.watch(
      branchSelectionProvider.select((s) => s.isAllBranchesSelected),
    );

    if (!isAll) return child;

    return _NoBranchSelected(actionLabel: actionLabel);
  }
}

class _NoBranchSelected extends StatelessWidget {
  final String? actionLabel;
  const _NoBranchSelected({this.actionLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = actionLabel ?? 'this action';

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsDuotone.storefront,
                  size: 40,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select a Branch First',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'You\'re currently viewing All Branches. '
                'Please select a specific branch from the top bar to use $label.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
