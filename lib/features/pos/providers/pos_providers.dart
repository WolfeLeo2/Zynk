import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/providers/app_providers.dart';
import 'package:zynk/core/models/schema_models.dart';

class PosBranchNotifier extends Notifier<String?> {
  static const _prefsKey = 'pos_selected_branch_id';

  @override
  String? build() {
    // We do NOT watch currentBranchIdProvider here to prevent resets.
    // We only use it as a fallback if nothing is saved.
    final prefs = ref.watch(sharedPreferencesProvider);
    final savedId = prefs.getString(_prefsKey);

    if (savedId != null) {
      // Verify it still exists in available branches
      final branches = ref.watch(branchesProvider).value ?? [];
      if (branches.any((b) => b.id == savedId)) {
        return savedId;
      }
    }

    // Fallback: Use global branch if specific, else first physical branch
    final globalBranchId = ref.read(currentBranchIdProvider);
    final branches = ref.watch(branchesProvider).value ?? [];
    final physicalBranches = branches.where((b) => b.id != 'all').toList();

    if (globalBranchId != null && globalBranchId != 'all') {
      return globalBranchId;
    }

    if (physicalBranches.isNotEmpty) {
      return physicalBranches.first.id;
    }

    return null;
  }

  Future<void> setBranch(String branchId) async {
    if (branchId == 'all') return; // POS cannot sell from 'all'
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_prefsKey, branchId);
    state = branchId;
  }
}

final posBranchProvider = NotifierProvider<PosBranchNotifier, String?>(
  PosBranchNotifier.new,
);

final selectedPosBranchProvider = Provider<Branch?>((ref) {
  final id = ref.watch(posBranchProvider);
  final branches = ref.watch(branchesProvider).value ?? [];
  try {
    return branches.firstWhere((b) => b.id == id);
  } catch (_) {
    return null;
  }
});
