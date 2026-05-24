import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/powersync.dart'; // Import global 'db'
import '../../data/local/repository.dart';
import '../../core/models/schema_models.dart';
import '../models/staff_model.dart';

import '../services/auth_service.dart';
import '../services/app_logger.dart';
import '../models/user_role.dart';
import 'user_provider.dart';

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
  final branchId = ref.watch(currentBranchIdProvider);
  if (tenantId == null) return const Stream.empty();
  return repository.watchStaff(tenantId, branchId: branchId);
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

/// Stream of all branches in the current tenant
final branchesProvider = StreamProvider<List<Branch>>((ref) {
  final repository = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  final user = ref.watch(authStateProvider).value;
  final isOwner = ref.watch(isOwnerProvider);

  if (tenantId == null) return const Stream.empty();
  if (user == null) return const Stream.empty();

  return repository.watchAccessibleBranches(
    tenantId: tenantId,
    userId: user.id,
    isOwner: isOwner,
  );
});

/// Stream of branches assigned to a specific profile
final profileBranchesProvider =
    StreamProvider.family<List<String>, String>((ref, profileId) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchProfileBranchIds(profileId);
});

/// Stream of ALL branches in the current tenant (unfiltered by access rules)
/// Useful for system-wide displays like the product stock matrix.
final allTenantBranchesProvider = StreamProvider<List<Branch>>((ref) {
  final repository = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);

  if (tenantId == null) return const Stream.empty();

  return repository.watchBranches(tenantId);
});

/// Provider to check if current user is owner
final isOwnerProvider = Provider<bool>((ref) {
  final UserRole role = ref.watch(userRoleProvider);
  return role.isOwner;
});

final isMultiBranchUserProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  final branchIds = user?.appMetadata['branch_ids'];
  return branchIds is List && branchIds.length > 1;
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
  final bool isLocked;

  const BranchSelectionState({
    this.selectedBranchId,
    this.availableBranches = const [],
    this.isLoading = false,
    this.error,
    this.isLocked = false,
  });

  BranchSelectionState copyWith({
    String? selectedBranchId,
    List<Branch>? availableBranches,
    bool? isLoading,
    String? error,
    bool? isLocked,
  }) {
    return BranchSelectionState(
      selectedBranchId: selectedBranchId ?? this.selectedBranchId,
      availableBranches: availableBranches ?? this.availableBranches,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isLocked: isLocked ?? this.isLocked,
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
    final state = _getInitialState();

    // If we picked a default that needs persisting, do it after the build
    if (state.selectedBranchId != null) {
      final savedBranchId = _prefs.getString(_prefsKey);
      if (savedBranchId == null) {
        Future.microtask(
          () => _prefs.setString(_prefsKey, state.selectedBranchId!),
        );
      }
    }

    return state;
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  BranchSelectionState _getInitialState() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final profile = ref.read(currentProfileProvider);
      final isOwner = ref.read(isOwnerProvider);

      final forcedBranchId =
          user?.appMetadata['branch_id'] as String? ??
          user?.userMetadata?['branch_id'] as String? ??
          profile?.branchId;

      // Check for multi-branch assignment in metadata
      final isMultiBranch = ref.read(isMultiBranchUserProvider);

      // 1. Lock if forced and not owner AND not multi-branch
      if (forcedBranchId != null && !isOwner && !isMultiBranch) {
        return BranchSelectionState(
          selectedBranchId: forcedBranchId,
          isLocked: true,
        );
      }

      // 2. Load saved preference
      final savedBranchId = _prefs.getString(_prefsKey);
      if (savedBranchId != null) {
        return BranchSelectionState(selectedBranchId: savedBranchId);
      }

      // 3. Default for owner OR multi-branch
      if (isOwner || isMultiBranch) {
        return const BranchSelectionState(selectedBranchId: 'all');
      }

      // 4. Fallback to forced branch if any
      if (forcedBranchId != null) {
        return BranchSelectionState(selectedBranchId: forcedBranchId);
      }

      // 5. Fallback to first available from cache if possible
      final branches = ref.read(branchesProvider).value ?? [];
      if (branches.isNotEmpty) {
        return BranchSelectionState(
          selectedBranchId: branches.first.id,
          availableBranches: branches,
        );
      }

      return const BranchSelectionState();
    } catch (e) {
      _log.e('Branch synchronous init failed: $e');
      return BranchSelectionState(error: e.toString());
    }
  }

  Future<void> selectBranch(String branchId) async {
    if (state.isLocked) {
      _log.w('Attempted to switch branch while locked to ${state.selectedBranchId}');
      return;
    }
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
    // Always update the available list so the UI can show branch names.
    state = state.copyWith(availableBranches: branches);

    // If the branch is locked (set from auth metadata), never clear or switch it.
    // The locked branch ID is the canonical truth — even if it's not yet in the
    // locally-synced branches list (e.g. PowerSync hasn't finished syncing).
    if (state.isLocked) return;

    // If no branch selected yet and branches are available, auto-select the first.
    if (state.selectedBranchId == null && branches.isNotEmpty) {
      _log.i(
        'Auto-selecting first branch: ${branches.first.id} (${branches.first.name})',
      );
      selectBranch(branches.first.id);
      return;
    }

    // Verify current selection is still valid.
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

final canSwitchBranchProvider = Provider<bool>((ref) {
  final branches = ref.watch(branchSelectionProvider).availableBranches;
  final realBranches = branches.where((b) => b.id != 'all').length;
  return realBranches > 1;
});

/// Side-effect provider: reacts to branchesProvider stream updates and
/// propagates them to BranchSelectionNotifier safely.
/// Uses ref.watch (NOT ref.listen) so it never fires synchronously during build.
/// addPostFrameCallback guarantees state mutation happens strictly after build.
/// Must be watched by an always-alive widget (e.g. AppShell).
final branchSyncProvider = Provider<void>((ref) {
  bool isDisposed = false;
  ref.onDispose(() => isDisposed = true);

  final branchesAsync = ref.watch(branchesProvider);
  branchesAsync.whenData((branches) {
    final isOwner = ref.read(isOwnerProvider);
    final isMultiBranch = ref.read(isMultiBranchUserProvider);
    final branchesWithAll = [
      if (isOwner || isMultiBranch) BranchSelectionNotifier.allBranchesOption,
      ...branches,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isDisposed) return;
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

// ============================================
// Measurement System Preference
// ============================================

enum MeasurementSystem { metric, imperial }

class MeasurementSystemNotifier extends Notifier<MeasurementSystem> {
  static const _prefsKey = 'measurement_system';

  @override
  MeasurementSystem build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_prefsKey);
    return saved == 'imperial'
        ? MeasurementSystem.imperial
        : MeasurementSystem.metric;
  }

  Future<void> setSystem(MeasurementSystem system) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(
      _prefsKey,
      system == MeasurementSystem.imperial ? 'imperial' : 'metric',
    );
    state = system;
  }
}

final measurementSystemProvider =
    NotifierProvider<MeasurementSystemNotifier, MeasurementSystem>(
      MeasurementSystemNotifier.new,
    );

// ============================================
// Theme Mode Preference
// ============================================

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _prefsKey = 'theme_mode';

  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(_prefsKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_prefsKey, mode.name);
    state = mode;
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

final itemsGroupsStreamProvider = StreamProvider<List<ItemGroup>>((ref) {
  final repo = ref.watch(repositoryProvider);
  return repo.watchItemGroups();
});

// -----------------------------------------------------------------------------
// Human Staff Provider
// -----------------------------------------------------------------------------

final humanStaffProvider = StreamProvider<List<StaffMember>>((ref) {
  final repository = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  final branchId = ref.watch(currentBranchIdProvider);
  if (tenantId == null) return const Stream.empty();
  return repository.watchStaffMembers(tenantId, branchId: branchId);
});

/// Returns staff for a specific branch. Includes staff explicitly assigned to that branch
/// OR staff with NO branch assigned (shared staff).
final humanStaffByBranchProvider =
    StreamProvider.family<List<StaffMember>, String?>((ref, branchId) {
  final repository = ref.watch(repositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId == null) return const Stream.empty();
  return repository.watchStaffMembers(tenantId, branchId: branchId);
});
