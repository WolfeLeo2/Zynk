import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';

/// A modal bottom sheet that lets the user select a specific variant
/// combination for a product before adding it to the cart.
///
/// Returns a Map<String, String> of attribute → selected value when the user
/// taps "Add to Ticket", or null if dismissed.
Future<Map<String, String>?> showVariantSelectionSheet(
  BuildContext context,
  Product product,
) {
  // Flatten variant options into typed map
  final options = <String, List<String>>{};
  product.variantOptions?.forEach((key, value) {
    if (value is List) {
      options[key] = value.map((v) => v.toString()).toList();
    }
  });

  if (options.isEmpty) return Future.value(null);

  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VariantSelectionSheet(product: product, options: options),
  );
}

class _VariantSelectionSheet extends StatefulWidget {
  final Product product;
  final Map<String, List<String>> options;

  const _VariantSelectionSheet({required this.product, required this.options});

  @override
  State<_VariantSelectionSheet> createState() => _VariantSelectionSheetState();
}

class _VariantSelectionSheetState extends State<_VariantSelectionSheet> {
  late final Map<String, String?> _selections;

  @override
  void initState() {
    super.initState();
    _selections = {for (final key in widget.options.keys) key: null};
  }

  bool get _allSelected => _selections.values.every((v) => v != null);

  String get _variantLabel => _selections.entries
      .where((e) => e.value != null)
      .map((e) => '${e.key}: ${e.value}')
      .join(', ');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: Text(
                  widget.product.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const PhosphorIcon(PhosphorIconsBold.x),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),

          if (_variantLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _variantLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
            ),
          ],

          const SizedBox(height: 20),

          ...widget.options.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: entry.value.map((val) {
                      final isSelected = _selections[entry.key] == val;
                      return GestureDetector(
                        onTap: () => setState(() => _selections[entry.key] = val),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? cs.primary : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? cs.primary : cs.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            val,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isSelected ? cs.onPrimary : cs.onSurface,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _allSelected
                  ? () => Navigator.pop(
                        context,
                        Map<String, String>.from(
                          _selections.map((k, v) => MapEntry(k, v!)),
                        ),
                      )
                  : null,
              icon: const PhosphorIcon(PhosphorIconsBold.shoppingCart, size: 18),
              label: const Text('Add to Ticket'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
