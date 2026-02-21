import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zynk/core/models/user_role.dart';
import 'package:zynk/core/providers/profile_provider.dart';

// Provider to get the current user role based on their profile
final userRoleProvider = Provider<UserRole>((ref) {
  final profileAsync = ref.watch(currentUserProfileProvider);

  return profileAsync.when(
    data: (profile) => profile?.role ?? UserRole.owner,
    loading: () => UserRole.owner, // Default safety
    error: (_, __) => UserRole.owner,
  );
});
