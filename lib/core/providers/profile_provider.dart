import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zynk/core/providers/app_providers.dart'; // for repositoryProvider
import 'package:zynk/core/models/schema_models.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/services/app_logger.dart';

// Provider to get the current user's profile from local DB
// synchronized with the current authenticated user.
final currentUserProfileProvider = StreamProvider<Profile?>((ref) {
  // We don't want to use .when() tightly because an auth error (network drop)
  // shouldn't wipe the local profile data off the screen.
  // Instead, we just read the current user ID and watch the local database.

  final user = Supabase.instance.client.auth.currentUser;

  if (user == null) {
    return Stream.value(null);
  }

  final repo = ref.watch(repositoryProvider);
  return repo.watchProfile(user.id);
});

final _log = AppLogger('ProfileProvider');

/// Side-effect provider: bridges the profile stream to branch selection.
/// Catches legacy accounts where branch_id was not written into Supabase auth
/// metadata at provisioning time. Once the profile stream resolves, it sets
/// the branch if no branch is selected yet and the state is not locked.
/// Must be watched by an always-alive widget (e.g. AppShell).
final profileBranchSyncProvider = Provider<void>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);
  profileAsync.whenData((profile) {
    final branchId = profile?.branchId;
    if (branchId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(branchSelectionProvider.notifier);
      final currentState = ref.read(branchSelectionProvider);
      // Only act when:
      //  a) no branch is selected yet (nothing from auth metadata or prefs), AND
      //  b) not already locked (locked = auth metadata set it synchronously).
      if (!currentState.isLocked && currentState.selectedBranchId == null) {
        _log.i('profileBranchSyncProvider: setting branch from profile: $branchId');
        notifier.selectBranch(branchId);
      }
    });
  });
});

/// Provider that enforces account status by signing out if blocked or deleted.
final statusEnforcerProvider = Provider<void>((ref) {
  ref.listen(currentUserProfileProvider, (previous, next) {
    next.whenData((profile) {
      if (profile != null &&
          (profile.status == ProfileStatus.inactive ||
              profile.status == ProfileStatus.deleted ||
              profile.status == ProfileStatus.blocked)) {
        Supabase.instance.client.auth.signOut();
      }
    });
  });
});
