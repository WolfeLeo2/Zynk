import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:zynk/core/providers/app_providers.dart'; // for repositoryProvider
import 'package:zynk/core/models/schema_models.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

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
