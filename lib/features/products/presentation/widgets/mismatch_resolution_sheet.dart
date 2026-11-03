import 'package:button_group_m3e/button_group_m3e.dart';
import 'package:button_m3e/button_m3e.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/utils/responsive_modal.dart';
import 'package:zynk/shared/widgets/app_bottom_sheet.dart';

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
    return showResponsiveModal<Map<String, bool>>(
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
  State<MismatchResolutionSheet> createState() =>
      _MismatchResolutionSheetState();
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

    return AppBottomSheet(
      title: 'Resolve Group Conflicts',
      icon: PhosphorIconsRegular.warning,
      maxHeightFactor: 0.9,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Some items have prices or settings that differ from the group defaults. Choose whether to normalize them to the group or preserve their custom overrides.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
          const Divider(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: widget.mismatchedProducts.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final p = widget.mismatchedProducts[index];
                final normalize = _decisions[p.id] ?? true;

                final discrepancies = <String>[];
                if (p.pricingUnit != widget.targetGroup.defaultPricingUnit) {
                  discrepancies.add(
                    'Unit: ${p.pricingUnit ?? "piece"} \u2192 ${widget.targetGroup.defaultPricingUnit}',
                  );
                }
                if (p.coveragePerBox !=
                    widget.targetGroup.defaultCoveragePerBox) {
                  discrepancies.add(
                    'Coverage: ${p.coveragePerBox ?? "-"} \u2192 ${widget.targetGroup.defaultCoveragePerBox ?? "-"}',
                  );
                }
                if (p.basePrice != widget.targetGroup.defaultSellingPrice) {
                  discrepancies.add(
                    'Selling: KES ${p.basePrice ?? "-"} \u2192 KES ${widget.targetGroup.defaultSellingPrice ?? "-"}',
                  );
                }
                if (p.costPrice != widget.targetGroup.defaultBuyingPrice) {
                  discrepancies.add(
                    'Buying: KES ${p.costPrice ?? "-"} \u2192 KES ${widget.targetGroup.defaultBuyingPrice ?? "-"}',
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...discrepancies.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              const PhosphorIcon(
                                PhosphorIconsRegular.arrowRight,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(d, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ButtonGroupM3E(
                        selection: true,
                        overflow: ButtonGroupM3EOverflow.none,
                        type: ButtonGroupM3EType.connected,
                        style: ButtonM3EStyle.filled,
                        expanded: true,
                        size: ButtonGroupM3ESize.md,
                        selectedIndex: normalize ? 1 : 0,
                        actions: [
                          ButtonGroupM3EAction(
                            label: const Text('Preserve'),
                            style: !normalize ? ButtonM3EStyle.tonal : null,
                            onPressed: () {
                              setState(() {
                                _decisions[p.id] = false;
                              });
                            },
                          ),
                          ButtonGroupM3EAction(
                            label: const Text('Normalize'),
                            style: normalize ? ButtonM3EStyle.tonal : null,
                            onPressed: () {
                              setState(() {
                                _decisions[p.id] = true;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context, _decisions);
              },
              child: const Text('Confirm & Apply'),
            ),
          ),
        ],
      ),
    );
  }
}
