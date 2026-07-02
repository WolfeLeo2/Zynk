import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/theme/app_tokens.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/shared/widgets/app_bottom_sheet.dart';

class BatchGroupActionSheet extends ConsumerStatefulWidget {
  final ItemGroup group;
  final String title;
  final String actionLabel;
  final Widget? infoBox;
  final Widget Function(BuildContext context, StateSetter setState)
  configBuilder;
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

    return AppBottomSheet(
      maxHeightFactor: 0.7,
      icon: PhosphorIconsDuotone.bookmarkSimple,
      title: widget.title,
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

          final filtered = items.where((p) {
            if (_searchQuery.isEmpty) return true;
            return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (p.sku?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                    false);
          }).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
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
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) =>
                                setState(() => _searchQuery = val),
                            decoration: const InputDecoration(
                              hintText: 'Search items...',
                              prefixIcon: PhosphorIcon(
                                PhosphorIconsRegular.magnifyingGlass,
                                size: 18,
                              ),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedIds.length == items.length) {
                                _selectedIds.clear();
                              } else {
                                _selectedIds.addAll(items.map((e) => e.id));
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
                    // 4. Items List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 8, bottom: 24),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = _selectedIds.contains(item.id);

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
                          shape: isSelected
                              ? RoundedRectangleBorder(
                                  borderRadius: AppTokens.roundedCard,
                                  side: BorderSide(
                                    color: cs.primary,
                                    width: 1.5,
                                  ),
                                )
                              : null,
                          tileColor: cs.surfaceContainerLow,
                          selectedTileColor: cs.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          title: Text(
                            item.name,
                            style: theme.textTheme.titleSmall?.copyWith(
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
                              color: isSelected
                                  ? cs.primary.withValues(alpha: 0.1)
                                  : cs.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: PhosphorIcon(
                              PhosphorIconsRegular.package,
                              size: 20,
                              color: isSelected
                                  ? cs.primary
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),
              const SizedBox(height: 16),

              // Footer Action
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: (_selectedIds.isEmpty || _isLoading)
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
                  child: _isLoading
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
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
