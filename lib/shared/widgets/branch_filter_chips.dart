import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zynk/core/providers/app_providers.dart';

class BranchFilterChips extends ConsumerWidget {
  final String? selectedBranchId;
  final ValueChanged<String?> onSelected;

  const BranchFilterChips({
    super.key,
    required this.selectedBranchId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final branchesAsync = ref.watch(branchesProvider);
    final currentBranch = ref.watch(currentBranchIdProvider);
    final isAllBranches = currentBranch == null || currentBranch == 'all';

    // Only show the internal branch filter if the global setting is "All Branches"
    if (!isAllBranches) return const SizedBox.shrink();

    return branchesAsync.when(
      data: (branches) {
        if (branches.length <= 1) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
          child: Row(
            children: [
              PhosphorIcon(
                PhosphorIconsRegular.storefront,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _branchChip(cs, null, 'All Branches'),
                      ...branches.map(
                        (b) => _branchChip(cs, b.id, b.name),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _branchChip(ColorScheme cs, String? branchId, String label) {
    final isActive = selectedBranchId == branchId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: isActive,
        showCheckmark: false,
        label: Text(
          label,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? cs.onSecondary : cs.onSurface,
            fontSize: 12,
          ),
        ),
        selectedColor: cs.secondary,
        side: BorderSide(
          color: isActive ? cs.secondary : cs.outline.withValues(alpha: 0.2),
        ),
        onSelected: (_) => onSelected(branchId),
      ),
    );
  }
}
