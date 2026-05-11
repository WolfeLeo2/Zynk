import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3e_card_list/m3e_card_list.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';

class BatchGroupActionSheet extends ConsumerStatefulWidget {
  final ItemGroup group;
  final String title;
  final String actionLabel;
  final Widget? infoBox;
  final Widget Function(BuildContext context, StateSetter setState) configBuilder;
  final Widget Function(BuildContext context, Product product, bool isSelected)
  itemTrailingBuilder;
  final Future<void> Function(Set<String> selectedIds) onConfirm;
  final List<Product>? initialItems;

  const BatchGroupActionSheet({
    super.key,
    required this.group,
    required this.title,
    required this.actionLabel,
    this.infoBox,
    required this.configBuilder,
    required this.itemTrailingBuilder,
    required this.onConfirm,
    this.initialItems,
  });

  @override
  ConsumerState<BatchGroupActionSheet> createState() =>
      _BatchGroupActionSheetState();
}

class _BatchGroupActionSheetState extends ConsumerState<BatchGroupActionSheet> {
  final Set<String> _selectedIds = {};
  bool _isLoading = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Pre-select all if we have items
    if (widget.initialItems != null) {
      _selectedIds.addAll(widget.initialItems!.map((p) => p.id));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final productsAsync = ref.watch(productsByGroupProvider(widget.group.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(PhosphorIconsRegular.x),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: productsAsync.when(
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No items in this group',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    final filtered =
                        items.where((p) {
                          if (_searchQuery.isEmpty) return true;
                          return p.name.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ||
                              (p.sku?.toLowerCase().contains(
                                    _searchQuery.toLowerCase(),
                                  ) ??
                                  false);
                        }).toList();

                    return Column(
                      children: [
                        Expanded(
                          child: ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            children: [
                              // 1. Config Area (Injected)
                              widget.configBuilder(context, setState),

                              const SizedBox(height: 24),

                              // 2. Info Box (Optional)
                              if (widget.infoBox != null) ...[
                                widget.infoBox!,
                                const SizedBox(height: 24),
                              ],

                              // 3. Selection Header & Search
                              Row(
                                children: [
                                  Expanded(
                                    child: SearchBar(
                                      controller: _searchController,
                                      hintText: 'Search items...',
                                      onChanged:
                                          (val) =>
                                              setState(() => _searchQuery = val),
                                      elevation: const WidgetStatePropertyAll(0),
                                      backgroundColor: WidgetStatePropertyAll(
                                        cs.surfaceContainerHighest.withAlpha(
                                          100,
                                        ),
                                      ),
                                      leading: const Icon(
                                        PhosphorIconsRegular.magnifyingGlass,
                                        size: 18,
                                      ),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(horizontal: 16),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        if (_selectedIds.length ==
                                            items.length) {
                                          _selectedIds.clear();
                                        } else {
                                          _selectedIds.addAll(
                                            items.map((e) => e.id),
                                          );
                                        }
                                      });
                                    },
                                    child: Text(
                                      _selectedIds.length == items.length
                                          ? 'Deselect All'
                                          : 'Select All',
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              Text(
                                'Select Items (${_selectedIds.length}/${items.length})',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),

                              const SizedBox(height: 8),

                              // 4. Items List
                              M3ECardList(
                                color: cs.surface,
                                elevation: 0.5,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final item = filtered[index];
                                  final isSelected =
                                      _selectedIds.contains(item.id);

                                  return CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedIds.add(item.id);
                                        } else {
                                          _selectedIds.remove(item.id);
                                        }
                                      });
                                    },
                                    title: Text(
                                      item.name,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    subtitle: widget.itemTrailingBuilder(
                                      context,
                                      item,
                                      isSelected,
                                    ),
                                    secondary: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        PhosphorIconsRegular.package,
                                        size: 20,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 100), // Spacing for button
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),

              // Footer Action
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: cs.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed:
                        (_selectedIds.isEmpty || _isLoading)
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                try {
                                  await widget.onConfirm(_selectedIds);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child:
                        _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                '${widget.actionLabel} (${_selectedIds.length} Items)',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
