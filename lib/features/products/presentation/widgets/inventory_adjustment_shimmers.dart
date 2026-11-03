import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholders for the inventory adjustment screen. Split out of
/// `inventory_adjustment_screen.dart` to keep that screen focused on layout.

class InventoryItemsShimmer extends StatelessWidget {
  const InventoryItemsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      highlightColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.7,
      ),
      child: ListView.builder(
        itemCount: 8,
        itemBuilder: (_, _) => ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          title: Container(height: 12, color: colorScheme.surface),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(height: 10, color: colorScheme.surface),
          ),
        ),
      ),
    );
  }
}

class FormFieldShimmer extends StatelessWidget {
  const FormFieldShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      highlightColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.7,
      ),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class ReasonsListShimmer extends StatelessWidget {
  const ReasonsListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
      highlightColor: colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.7,
      ),
      child: ListView.builder(
        itemCount: 6,
        itemBuilder: (_, _) => const ListTile(
          leading: CircleAvatar(radius: 12),
          title: SizedBox(height: 12),
        ),
      ),
    );
  }
}
