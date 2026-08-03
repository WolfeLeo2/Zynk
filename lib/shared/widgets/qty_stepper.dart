import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/utils/quantity.dart';

class QtyStepper extends StatelessWidget {
  final num value;
  final ValueChanged<num> onChanged;
  final num min;
  final num max;

  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 9999,
  });

  /// Tapping the number opens a keypad so fractional quantities (0.5 of a unit)
  /// can be entered — the +/- buttons only ever step whole units.
  Future<void> _editQuantity(BuildContext context) async {
    final controller = TextEditingController(text: formatQtyInput(value));
    final entered = await showDialog<num>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            hintText: 'e.g. 0.5',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (raw) =>
              Navigator.pop(context, num.tryParse(raw.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, num.tryParse(controller.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );

    if (entered == null) return;
    onChanged(entered.clamp(min, max));
  }

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
          InkWell(
            onTap: () => _editQuantity(context),
            child: Container(
              constraints: const BoxConstraints(minWidth: 32),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                formatQty(value),
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
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
