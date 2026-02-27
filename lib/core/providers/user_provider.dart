import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/providers/profile_provider.dart';

/// Provider to get the current user's role.
final userRoleProvider = Provider<UserRole>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);

  return profileAsync.when(
    data: (profile) => profile?.role ?? UserRole.owner,
    loading: () => UserRole.owner,
    error: (_, _) => UserRole.owner,
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
