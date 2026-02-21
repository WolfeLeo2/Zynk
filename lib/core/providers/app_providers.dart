import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/powersync.dart'; // Import global 'db'
import '../../data/local/repository.dart';
import '../../core/models/schema_models.dart';
import '../services/auth_service.dart';

// ============================================
// Shared Preferences Provider
// ============================================

/// Provider for SharedPreferences instance
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize in ProviderScope overrides');
});

// ============================================
// Database & Repository Providers
// ============================================

/// Provider for the PowerSync Repository
final repositoryProvider = Provider<PowerSyncRepository>((ref) {
  return PowerSyncRepository(db); // Use global 'db' from config
});

// ============================================
// Tenant & Auth Providers
// ============================================

/// Provider for the current tenant ID extracted from user metadata
final tenantIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  return user?.appMetadata['tenant_id'] as String? ??
      user?.userMetadata?['tenant_id'] as String?;
});

/// Stream of the current Tenant record
final currentTenantProvider = StreamProvider<Tenant?>((ref) {
  final repository = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId == null) return const Stream.empty();
  return repository.watchTenant(tenantId);
});

/// Stream of all staff members (profiles) in the current tenant
final staffProvider = StreamProvider<List<Profile>>((ref) {
  final repository = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId == null) return const Stream.empty();
  return repository.watchStaff(tenantId);
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

/// Provider for current user role
final userRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final role =
      user?.appMetadata['role'] as String? ??
      user?.userMetadata?['role'] as String?;

  if (role != null) {
    if (role.toLowerCase() == 'owner') return 'Owner';
    if (role.toLowerCase() == 'manager') return 'Manager';
    if (role.toLowerCase() == 'admin') return 'Admin';
  }
  return 'Cashier';
});

/// Stream of all branches in the current tenant
final branchesProvider = StreamProvider<List<Branch>>((ref) {
  final repository = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId == null) return const Stream.empty();
  return repository.watchBranches(tenantId);
});

/// Provider to check if current user is owner
final isOwnerProvider = Provider<bool>((ref) {
  final role = ref.watch(userRoleProvider);
  return role == 'Owner' || role == 'Admin';
});

// ============================================
// Branch Selection Providers (Riverpod 3.x Notifier syntax)
// ============================================

/// State for branch selection
class BranchSelectionState {
  final String? selectedBranchId;
  final List<Branch> availableBranches;
  final bool isLoading;
  final String? error;

  const BranchSelectionState({
    this.selectedBranchId,
    this.availableBranches = const [],
    this.isLoading = false,
    this.error,
  });

  BranchSelectionState copyWith({
    String? selectedBranchId,
    List<Branch>? availableBranches,
    bool? isLoading,
    String? error,
  }) {
    return BranchSelectionState(
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      availableBranches: availableBranches ?? this.availableBranches,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  Branch? get selectedBranch {
    if (selectedBranchId == null) return null;
    try {
      return availableBranches.firstWhere((b) => b.id == selectedBranchId);
    } catch (_) {
      return null;
    }
  }
}

/// Branch selection notifier using Riverpod 3.x Notifier class
class BranchSelectionNotifier extends Notifier<BranchSelectionState> {
  static const _prefsKey = 'selected_branch_id';

  @override
  BranchSelectionState build() {
    Future.microtask(() => _loadSavedBranch());
    return const BranchSelectionState(isLoading: true);
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> _loadSavedBranch() async {
    try {
      final savedBranchId = _prefs.getString(_prefsKey);
      state = state.copyWith(selectedBranchId: savedBranchId, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load saved branch: $e',
        isLoading: false,
      );
    }
  }

  Future<void> selectBranch(String branchId) async {
    try {
      await _prefs.setString(_prefsKey, branchId);
      state = state.copyWith(selectedBranchId: branchId);
    } catch (e) {
      state = state.copyWith(error: 'Failed to save branch selection: $e');
    }
  }

  Future<void> clearSelection() async {
    await _prefs.remove(_prefsKey);
    state = state.copyWith(selectedBranchId: null);
  }

  void setAvailableBranches(List<Branch> branches) {
    state = state.copyWith(availableBranches: branches);
    if (state.selectedBranchId != null) {
      final stillValid = branches.any((b) => b.id == state.selectedBranchId);
      if (!stillValid) {
        clearSelection();
      }
    }
  }

  Future<void> refreshBranches() async {
    final tenantId = ref.read(tenantIdProvider);
    if (tenantId == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final repo = ref.read(repositoryProvider);
      final branches = await repo.getBranches(tenantId);

      setAvailableBranches(branches);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to load branches: $e',
        isLoading: false,
      );
    }
  }
}

final branchSelectionProvider =
    NotifierProvider<BranchSelectionNotifier, BranchSelectionState>(
      BranchSelectionNotifier.new,
    );

final currentBranchIdProvider = Provider<String?>((ref) {
  return ref.watch(branchSelectionProvider).selectedBranchId;
});

final currentBranchProvider = Provider<Branch?>((ref) {
  return ref.watch(branchSelectionProvider).selectedBranch;
});

// ============================================
// UI State Providers
// ============================================

class LoadingNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void setLoading(String key, bool isLoading) {
    state = {...state, key: isLoading};
  }

  bool isLoading(String key) => state[key] ?? false;
}

final loadingProvider = NotifierProvider<LoadingNotifier, Map<String, bool>>(
  LoadingNotifier.new,
);

class ErrorNotifier extends Notifier<Map<String, String?>> {
  @override
  Map<String, String?> build() => {};

  void setError(String key, String? error) {
    state = {...state, key: error};
  }

  String? getError(String key) => state[key];

  void clearError(String key) {
    state = {...state, key: null};
  }
}

final itemsGroupsStreamProvider = StreamProvider<List<ItemGroup>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchItemGroups();
});
