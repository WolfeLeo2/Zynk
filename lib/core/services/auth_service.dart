import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zynk/data/local/repository.dart';

import '../../core/providers/app_providers.dart';

part 'auth_service.g.dart';

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  final repo = ref.watch(repositoryProvider);
  return AuthService(Supabase.instance.client, repo);
}

@Riverpod(keepAlive: true)
Stream<User?> authState(Ref ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
}

/// Service for handling authentication operations
class AuthService {
  final SupabaseClient _supabase;
  final PowerSyncRepository _repo;

  AuthService(this._supabase, this._repo);

  User? get currentUser => _supabase.auth.currentUser;

  /// Owner Sign Up - Creates a new tenant
  Future<AuthResponse> signUpOwner({
    required String email,
    required String password,
    required String shopName,
    required String ownerName,
    String? businessAddress,
    String? businessPhone,
    String? logoUrl,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'is_owner': true,
        'shop_name': shopName,
        'display_name': ownerName,
        'business_address': businessAddress,
        'business_phone': businessPhone,
        'logo_url': logoUrl,
      },
    );
  }

  // 2. Sign In (Staff or Owner)
  Future<void> signIn({required String email, required String password}) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
    await _ensureLocalProfile();
  }

  // 3. Sign Out
  Future<void> signOut() async {
    // Clear local db first to avoid flashing data from previous user
    try {
      await _repo.clearDatabase();
    } catch (_) {}
    await _supabase.auth.signOut();
  }

  // 4. Create Staff (Owner Only)
  Future<void> createStaff({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String address,
    List<String>? branchIds,
    String role = 'Cashier',
    List<String>? permissions,
  }) async {
    await _supabase.functions.invoke(
      'create-staff-user',
      body: {
        'email': email,
        'password': password,
        'name': name,
        'phone': phone,
        'address': address,
        'branch_ids': branchIds,
        'role': role,
        'permissions': permissions,
      },
    );
  }

  // 5. Reset Staff Password (Owner Only)
  Future<void> resetStaffPassword({
    required String userId,
    required String newPassword,
  }) async {
    await _supabase.functions.invoke(
      'reset-staff-password',
      body: {'user_id_to_reset': userId, 'new_password': newPassword},
    );
  }

  // Helper: Ensure a local profile exists for the current user
  Future<void> _ensureLocalProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Check metadata for role info
    // Check metadata for role info
    // final metadata = user.userMetadata;

    // With PowerSync, we rely on the server-side trigger to create the profile
    // and PowerSync to sync it down.
    // If we need to verify existence, we should check the local repo.
  }

  // Check if profile exists using Repository
  // This is a direct check before the stream updates, might need a direct `getProfile` in repo
  // For now, we will assume if it syncs, it will exist.
  // PowerSync handles the download. We just need to make sure we CREATE it if we are the one signing up?
  // ACTUALLY: In PowerSync architecture, the profile should be created on the server side (Edge Function)
  // or via the initial sync if it already exists.
  // BUT for offline-first, we might want to insert purely local first?
  // Supabase Auth trigger handles profile creation usually.
  // Let's rely on sync for fetching, but if we need to force an update we can use the repo.

  // NOTE: In the previous implementation we did a local insert/update.
  // With PowerSync, we can write to local DB and it syncs up.

  // We can use a simple one-shot query to check existence
  // But since `watchProfile` is a stream, let's just do a direct check in Repo if we add `getProfile`.
  // For now, let's skip the existence check logic here because PowerSync + Supabase Triggers should handle this.
  // If we rely on triggers, we don't need to manually insert into `profiles` locally on sign in.
  // We only need to potentially UPDATE it if local info is fresher?

  // REVISIT: For now, I'll comment out the manual profile sync logic
  // because PowerSync will pull the profile down from Supabase
  // (which should have been created by a Trigger on auth.users insert).

  /*
    final exists = await _repo.getProfile(user.id); 
    if (exists == null) { ... }
    */
}
