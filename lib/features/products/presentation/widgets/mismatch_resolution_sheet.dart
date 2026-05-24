import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';

class MismatchResolutionSheet extends StatefulWidget {
  final ItemGroup targetGroup;
  final List<Product> mismatchedProducts;

  const MismatchResolutionSheet({
    super.key,
    required this.targetGroup,
    required this.mismatchedProducts,
  });

  static Future<Map<String, bool>?> show(
    BuildContext context, {
    required ItemGroup targetGroup,
    required List<Product> mismatchedProducts,
  }) {
    return showModalBottomSheet<Map<String, bool>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => MismatchResolutionSheet(
        targetGroup: targetGroup,
        mismatchedProducts: mismatchedProducts,
      ),
    );
  }

  @override
  State<MismatchResolutionSheet> createState() => _MismatchResolutionSheetState();
}

class _MismatchResolutionSheetState extends State<MismatchResolutionSheet> {
  // Map of productId to bool (true = normalize, false = preserve)
  final Map<String, bool> _decisions = {};

  @override
  void initState() {
    super.initState();
    // Default to normalize for all
    for (final p in widget.mismatchedProducts) {
      _decisions[p.id] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const PhosphorIcon(PhosphorIconsRegular.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resolve Group Conflicts',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Some items have prices or settings that differ from the group defaults. Choose whether to normalize them to the group or preserve their custom overrides.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 32),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: widget.mismatchedProducts.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final p = widget.mismatchedProducts[index];
                  final normalize = _decisions[p.id] ?? true;

                  final discrepancies = <String>[];
                  if (p.pricingUnit != widget.targetGroup.defaultPricingUnit) {
                    discrepancies.add('Unit: ${p.pricingUnit ?? "piece"} \u2192 ${widget.targetGroup.defaultPricingUnit}');
                  }
                  if (p.coveragePerBox != widget.targetGroup.defaultCoveragePerBox) {
                    discrepancies.add('Coverage: ${p.coveragePerBox ?? "-"} \u2192 ${widget.targetGroup.defaultCoveragePerBox ?? "-"}');
                  }
                  if (p.basePrice != widget.targetGroup.defaultSellingPrice) {
                    discrepancies.add('Selling: KES ${p.basePrice ?? "-"} \u2192 KES ${widget.targetGroup.defaultSellingPrice ?? "-"}');
                  }
                  if (p.costPrice != widget.targetGroup.defaultBuyingPrice) {
                    discrepancies.add('Buying: KES ${p.costPrice ?? "-"} \u2192 KES ${widget.targetGroup.defaultBuyingPrice ?? "-"}');
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...discrepancies.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              const PhosphorIcon(PhosphorIconsRegular.arrowRight, size: 16),
                              const SizedBox(width: 4),
                              Text(d, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        )),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    label: Text('Preserve'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    label: Text('Normalize'),
                                  ),
                                ],
                                selected: {normalize},
                                onSelectionChanged: (set) {
                                  setState(() {
                                    _decisions[p.id] = set.first;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context, _decisions);
                  },
                  child: const Text('Confirm & Apply'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
