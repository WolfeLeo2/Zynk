import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/providers/app_providers.dart';

/// Plain branch picker dropdown — switches the active branch on selection.
/// When the user can't switch (single branch), it renders the current branch
/// name as static text. Used by the drawer header and Settings.
class BranchDropdown extends ConsumerWidget {
  /// Fill the available width (drawer) vs. size to content (settings trailing).
  final bool isExpanded;

  const BranchDropdown({super.key, this.isExpanded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final branches = ref.watch(branchSelectionProvider).availableBranches;
    final selectedId = ref.watch(currentBranchIdProvider);
    final canSwitch = ref.watch(canSwitchBranchProvider);

    final currentName =
        branches.where((b) => b.id == selectedId).firstOrNull?.name ??
        (selectedId == 'all' ? 'All Branches' : null);

    final labelStyle = theme.textTheme.titleMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    if (!canSwitch || branches.isEmpty) {
      if (currentName == null) return const SizedBox.shrink();
      return Text(
        currentName,
        style: labelStyle,
        overflow: TextOverflow.ellipsis,
      );
    }

    final value = branches.any((b) => b.id == selectedId) ? selectedId : null;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: isExpanded,
        value: value,
        dropdownColor: theme.colorScheme.surfaceContainerHigh,
        style: labelStyle,
        items: [
          for (final b in branches)
            DropdownMenuItem(
              value: b.id,
              child: Text(b.name, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (id) {
          if (id != null) {
            ref.read(branchSelectionProvider.notifier).selectBranch(id);
          }
        },
      ),
    );
  }
}
