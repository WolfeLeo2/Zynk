import 'package:button_group_m3e/button_group_m3e.dart';
import 'package:button_m3e/button_m3e.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/providers/user_provider.dart';
import 'package:zynk/core/utils/responsive_modal.dart';
import 'package:zynk/features/products/presentation/providers/product_providers.dart';
import 'package:zynk/features/products/presentation/widgets/inventory_adjustment_shimmers.dart';
import 'package:zynk/features/products/presentation/widgets/manage_reasons_sheet.dart';

/// Compact settings card for a batch stock adjustment: which branches, the
/// mode (add / subtract / set), the reason, and an optional reference. Kept as
/// one bounded card so it stays out of the basket's way and can sit persistently
/// at the top of the screen on both form factors.
class AdjustmentConfigBar extends ConsumerWidget {
  final Set<String> selectedBranchIds;
  final String mode;
  final String? reasonId;
  final TextEditingController referenceController;
  final void Function(String branchId, bool selected) onBranchToggle;
  final ValueChanged<String> onModeChanged;
  final ValueChanged<String?> onReasonChanged;

  const AdjustmentConfigBar({
    super.key,
    required this.selectedBranchIds,
    required this.mode,
    required this.reasonId,
    required this.referenceController,
    required this.onBranchToggle,
    required this.onModeChanged,
    required this.onReasonChanged,
  });

  static const _modes = [
    ('add', 'Add', PhosphorIconsRegular.plus),
    ('subtract', 'Subtract', PhosphorIconsRegular.minus),
    ('set', 'Set to', PhosphorIconsRegular.equals),
  ];

  void _showManageReasons(BuildContext context, String tenantId) {
    showResponsiveModal(
      context: context,
      builder: (_) => ManageReasonsSheet(tenantId: tenantId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ButtonGroupM3E(
              selection: true,
              overflow: ButtonGroupM3EOverflow.none,
              type: ButtonGroupM3EType.connected,
              style: ButtonM3EStyle.filled,
              size: ButtonGroupM3ESize.sm,
              shape: ButtonGroupM3EShape.round,
              selectedIndex: _modes.indexWhere((m) => m.$1 == mode),
              actions: [
                for (final (value, label, icon) in _modes)
                  ButtonGroupM3EAction(
                    label: Text(label),
                    icon: PhosphorIcon(icon, size: 18),
                    style: mode == value ? ButtonM3EStyle.tonal : null,
                    onPressed: () => onModeChanged(value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _BranchChips(
            selectedBranchIds: selectedBranchIds,
            onBranchToggle: onBranchToggle,
          ),
          const SizedBox(height: 12),
          _ReasonRow(
            reasonId: reasonId,
            onReasonChanged: onReasonChanged,
            onManage: (tenantId) => _showManageReasons(context, tenantId),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: referenceController,
            decoration: InputDecoration(
              labelText: 'Reference (optional)',
              hintText: 'e.g. PO-2023-001 or delivery note',
              prefixIcon: const PhosphorIcon(PhosphorIconsRegular.receipt),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchChips extends ConsumerWidget {
  final Set<String> selectedBranchIds;
  final void Function(String branchId, bool selected) onBranchToggle;

  const _BranchChips({
    required this.selectedBranchIds,
    required this.onBranchToggle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final branchesAsync = ref.watch(branchesProvider);
    final isLocked = ref.watch(branchSelectionProvider).isLocked;

    return branchesAsync.when(
      data: (branches) {
        final list = branches.where((b) => b.id != 'all').toList();
        if (list.length <= 1) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apply to branches',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in list)
                  FilterChip(
                    label: Text(b.name),
                    selected: selectedBranchIds.contains(b.id),
                    avatar: const PhosphorIcon(
                      PhosphorIconsRegular.storefront,
                      size: 14,
                    ),
                    // Locked users can't fan out; keep at least one selected.
                    onSelected: isLocked
                        ? null
                        : (selected) => onBranchToggle(b.id, selected),
                  ),
              ],
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _ReasonRow extends ConsumerWidget {
  final String? reasonId;
  final ValueChanged<String?> onReasonChanged;
  final void Function(String tenantId) onManage;

  const _ReasonRow({
    required this.reasonId,
    required this.onReasonChanged,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider) ?? '';
    final profile = ref.watch(currentProfileProvider);
    final canManage =
        profile != null &&
        (profile.role.isOwner ||
            profile.role.isManager ||
            profile.permissions.contains(Permission.manageBusiness) ||
            profile.permissions.contains(Permission.manageStock));
    final reasonsAsync = ref.watch(adjustmentReasonsProvider);

    return reasonsAsync.when(
      data: (reasons) => Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: reasonId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Reason *',
                prefixIcon: const PhosphorIcon(PhosphorIconsRegular.question),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              hint: const Text('Select a reason'),
              items: [
                for (final r in reasons)
                  DropdownMenuItem(value: r.id, child: Text(r.label)),
              ],
              onChanged: onReasonChanged,
            ),
          ),
          if (canManage) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Manage reasons',
              onPressed: () => onManage(tenantId),
              icon: const PhosphorIcon(PhosphorIconsRegular.pencilSimple),
            ),
          ],
        ],
      ),
      loading: () => const FormFieldShimmer(),
      error: (e, _) => Text('Could not load reasons: $e'),
    );
  }
}
