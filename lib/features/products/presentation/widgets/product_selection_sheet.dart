import 'package:flutter/material.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/utils/responsive_modal.dart';


class ProductSelectionSheet extends StatefulWidget {
  final List<Product> availableProducts;
  final Set<String> initiallySelectedIds;

  const ProductSelectionSheet({
    super.key,
    required this.availableProducts,
    required this.initiallySelectedIds,
  });

  static Future<Set<String>?> show(
    BuildContext context, {
    required List<Product> availableProducts,
    required Set<String> initiallySelectedIds,
  }) {
    return showResponsiveModal<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ProductSelectionSheet(
        availableProducts: availableProducts,
        initiallySelectedIds: initiallySelectedIds,
      ),
    );
  }

  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initiallySelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Assign Items',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _selectedIds),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: widget.availableProducts.isEmpty
                  ? const Center(child: Text('No items available.'))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: widget.availableProducts.length,
                      itemBuilder: (context, index) {
                        final p = widget.availableProducts[index];
                        final isSelected = _selectedIds.contains(p.id);
                        return CheckboxListTile(
                          value: isSelected,
                          title: Text(p.name),
                          subtitle: Text('SKU: ${p.sku ?? "None"}'),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(p.id);
                              } else {
                                _selectedIds.remove(p.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
