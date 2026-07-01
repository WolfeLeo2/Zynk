import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Standard frame for bottom sheets (and the dialog they become on wide
/// screens via `showResponsiveModal`): SafeArea, consistent padding, and an
/// optional icon+title header. Pass the sheet's body as [child] — this owns
/// everything else so individual sheets stop hand-rolling drag handles,
/// close buttons, and rounded-top containers the modal frame already gives.
///
/// For content that can grow long (lists, forms with many fields), set
/// [maxHeightFactor] so [child] can scroll inside a bounded box instead of
/// overflowing a shrink-wrapped column.
class AppBottomSheet extends StatelessWidget {
  final String? title;
  final PhosphorIconData? icon;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? maxHeightFactor;

  const AppBottomSheet({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 24),
    this.maxHeightFactor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final header = title == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                if (icon case final icon?) ...[
                  PhosphorIcon(icon, color: cs.primary),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

    final content = maxHeightFactor == null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [?header, child],
          )
        : ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * maxHeightFactor!,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [?header, Flexible(child: child)],
            ),
          );

    return SafeArea(child: Padding(padding: padding, child: content));
  }
}
