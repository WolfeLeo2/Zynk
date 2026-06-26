import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24), // Pill shape
        border: Border.all(color: cs.outline, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: value > min ? () => onChanged(value - 1) : null,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: PhosphorIcon(
                PhosphorIconsRegular.minus,
                size: 16,
                color: value > min
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          InkWell(
            onTap: value < max ? () => onChanged(value + 1) : null,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: PhosphorIcon(
                PhosphorIconsRegular.plus,
                size: 16,
                color: value < max
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
