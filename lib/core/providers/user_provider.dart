import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/profile_provider.dart';

/// Provider to get the current user's role.
final userRoleProvider = Provider<UserRole>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);

  // Fail CLOSED: while the profile is loading or errored, assume the
  // least-privileged role. The app gates the shell on a resolved profile
  // (see AppShell), so this default is only ever read transiently.
  return profileAsync.when(
    data: (profile) => profile?.role ?? UserRole.cashier,
    loading: () => UserRole.cashier,
    error: (_, _) => UserRole.cashier,
  );
});

/// Provider to get the current user's profile (resolved, non-async).
final currentProfileProvider = Provider<Profile?>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);
  return profileAsync.whenOrNull(data: (p) => p);
});

/// Check if the current user has a specific permission.
final hasPermissionProvider = Provider.family<bool, Permission>((ref, perm) {
  final profile = ref.watch(currentProfileProvider);
  if (profile == null) return false;
  return profile.hasPermission(perm);
});
