import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/adjustment_reason.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/widgets/inventory_adjustment_shimmers.dart';
import 'package:zynk/shared/widgets/app_bottom_sheet.dart';

/// Add / delete the tenant's stock-adjustment reasons. Live-watches the
/// reasons list so edits reflect immediately.
class ManageReasonsSheet extends ConsumerStatefulWidget {
  final String tenantId;

  const ManageReasonsSheet({super.key, required this.tenantId});

  @override
  ConsumerState<ManageReasonsSheet> createState() => _ManageReasonsSheetState();
}

class _ManageReasonsSheetState extends ConsumerState<ManageReasonsSheet> {
  final _addController = TextEditingController();
  bool _isAdding = false;

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _addReason() async {
    final label = _addController.text.trim();
    if (label.isEmpty) return;
    setState(() => _isAdding = true);
    try {
      final repo = ref.read(repositoryProvider);
      final reason = AdjustmentReason(
        id: const Uuid().v4(),
        tenantId: widget.tenantId,
        label: label,
        createdAt: DateTime.now().toUtc(),
      );
      await repo.createAdjustmentReason(reason);
      _addController.clear();
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteReason(String id) async {
    final repo = ref.read(repositoryProvider);
    await repo.deleteAdjustmentReason(id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final liveReasons = ref.watch(adjustmentReasonsProvider);

    return AppBottomSheet(
      title: 'Manage Adjustment Reasons',
      icon: PhosphorIconsDuotone.tagSimple,
      maxHeightFactor: 0.7,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    decoration: InputDecoration(
                      hintText: 'New reason label...',
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _addReason(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _isAdding ? null : _addReason,
                  child: _isAdding
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Flexible(
              child: liveReasons.when(
                data: (reasons) => reasons.isEmpty
                    ? Center(
                        child: Text(
                          'No reasons yet. Add one above.',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: reasons.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 56),
                        itemBuilder: (_, i) {
                          final r = reasons[i];
                          return ListTile(
                            leading: const PhosphorIcon(
                              PhosphorIconsRegular.tagSimple,
                            ),
                            title: Text(r.label),
                            trailing: IconButton(
                              icon: PhosphorIcon(
                                PhosphorIconsRegular.trash,
                                color: colorScheme.error,
                              ),
                              onPressed: () => _deleteReason(r.id),
                              tooltip: 'Delete',
                            ),
                          );
                        },
                      ),
                loading: () => const ReasonsListShimmer(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
