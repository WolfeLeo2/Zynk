import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/core/theme/app_theme.dart';

class ProductTypeBottomSheet extends ConsumerWidget {
  const ProductTypeBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What are you adding?',
            style: AppTokens.heading2.copyWith(color: AppTokens.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose the type of item you want to create',
            style: AppTokens.bodyMedium.copyWith(color: AppTokens.textSecondary),
          ),
          const SizedBox(height: 32),
          _TypeOption(
            icon: PhosphorIcons.package(),
            title: 'Single Product',
            description: 'A standard item with its own SKU and price',
            color: AppTokens.electricBlue,
            onTap: () {
              context.pop();
              context.push('/products/add?type=single');
            },
          ),
          const SizedBox(height: 16),
          _TypeOption(
            icon: PhosphorIcons.stack(),
            title: 'Item Group',
            description: 'Group products together (e.g., Small, Large)',
            color: AppTokens.neonLime,
            onTap: () {
              context.pop();
              context.push('/products/add?type=group');
            },
          ),
          const SizedBox(height: 16),
          _TypeOption(
            icon: PhosphorIcons.intersect(),
            title: 'Composite Item',
            description: 'An item made up of other items and components',
            color: Colors.purpleAccent,
            onTap: () {
              context.pop();
              context.push('/products/add?type=composite');
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _TypeOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTokens.labelLarge.copyWith(
                      color: AppTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: AppTokens.bodySmall.copyWith(
                      color: AppTokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIcons.caretRight(),
              color: AppTokens.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
