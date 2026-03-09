import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/powersync.dart'; // Import global 'db'
import '../../data/local/repository.dart';
import '../../core/models/schema_models.dart';
import '../services/auth_service.dart';
import '../services/app_logger.dart';

final _log = AppLogger('AppProviders');

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

  /// True when the user has chosen the aggregated "All Branches" view.
  /// Create/write actions should be blocked when this is true.
  bool get isAllBranchesSelected => selectedBranchId == 'all';
}

/// Branch selection notifier using Riverpod 3.x Notifier class
/// Auto-selects a branch on startup:
/// 1. From SharedPreferences (previously selected)
/// 2. From user metadata (branch_id assigned on login)
/// 3. Falls back to first available branch
class BranchSelectionNotifier extends Notifier<BranchSelectionState> {
  static const _prefsKey = 'selected_branch_id';
  // Dummy branch representing "All Branches"
  static final allBranchesOption = Branch(
    id: 'all',
    tenantId: 'all',
    name: 'All Branches',
    address: 'All',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  @override
  BranchSelectionState build() {
    // Schedule async initialization after the first frame
    Future.microtask(() => _initBranch());
    return const BranchSelectionState(isLoading: true);
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  Future<void> _initBranch() async {
    try {
      // Step 1: Try loading from SharedPreferences
      final savedBranchId = _prefs.getString(_prefsKey);
      _log.d('Saved branch from prefs: $savedBranchId');

      if (savedBranchId != null) {
        state = state.copyWith(
          selectedBranchId: savedBranchId,
          isLoading: false,
        );
        return;
      }

      // Step 2: Check user metadata for a default branch
      final user = Supabase.instance.client.auth.currentUser;
      final metaBranchId =
          user?.appMetadata['branch_id'] as String? ??
          user?.userMetadata?['branch_id'] as String?;
      _log.d('Branch from user metadata: $metaBranchId');

      if (metaBranchId != null) {
        await _prefs.setString(_prefsKey, metaBranchId);
        state = state.copyWith(
          selectedBranchId: metaBranchId,
          isLoading: false,
        );
        return;
      }

      // Step 3: Auto-select first available branch
      final branches = ref.read(branchesProvider).value ?? [];
      _log.d('Available branches for auto-select: ${branches.length}');

      if (branches.isNotEmpty) {
        final firstId = branches.first.id;
        _log.i(
          'Auto-selecting first branch: $firstId (${branches.first.name})',
        );
        await _prefs.setString(_prefsKey, firstId);
        state = state.copyWith(
          selectedBranchId: firstId,
          availableBranches: branches,
          isLoading: false,
        );
        return;
      }

      // No branch available yet — will auto-select when branchesProvider delivers
      _log.d('No branches available yet, waiting for stream...');
      state = state.copyWith(isLoading: false);
    } catch (e) {
      _log.e('Branch init failed: $e');
      state = state.copyWith(
        error: 'Failed to load saved branch: $e',
        isLoading: false,
      );
    }
  }

  Future<void> selectBranch(String branchId) async {
    try {
      _log.i('Branch selected: $branchId');
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

    // If no branch selected yet and branches are available, auto-select
    if (state.selectedBranchId == null && branches.isNotEmpty) {
      _log.i(
        'Auto-selecting first branch: ${branches.first.id} (${branches.first.name})',
      );
      selectBranch(branches.first.id);
      return;
    }

    // Verify current selection is still valid
    if (state.selectedBranchId != null) {
      final stillValid = branches.any((b) => b.id == state.selectedBranchId);
      if (!stillValid && branches.isNotEmpty) {
        _log.d(
          'Previously selected branch no longer valid, switching to first',
        );
        selectBranch(branches.first.id);
      } else if (!stillValid) {
        clearSelection();
      }
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

/// Side-effect provider: reacts to branchesProvider stream updates and
/// propagates them to BranchSelectionNotifier safely.
/// Uses ref.watch (NOT ref.listen) so it never fires synchronously during build.
/// addPostFrameCallback guarantees state mutation happens strictly after build.
/// Must be watched by an always-alive widget (e.g. AppShell).
final branchSyncProvider = Provider<void>((ref) {
  final branchesAsync = ref.watch(branchesProvider);
  branchesAsync.whenData((branches) {
    final isOwner = ref.read(isOwnerProvider);
    final branchesWithAll = [
      if (isOwner) BranchSelectionNotifier.allBranchesOption,
      ...branches,
    ];
    // addPostFrameCallback guarantees this runs AFTER the current frame
    // completes — far safer than Future.microtask which can still fire
    // during a build phase in some Flutter internals.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(branchSelectionProvider.notifier)
          .setAvailableBranches(branchesWithAll);
    });
  });
});

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
