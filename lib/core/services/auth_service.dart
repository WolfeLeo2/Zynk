import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zynk/data/local/repository.dart';
import 'package:zynk/core/config/powersync.dart';

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
    final response = await _supabase.auth.signUp(
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
    // Reconnect PowerSync after successful auth since sign out disconnects it
    db.connect(connector: SupabaseConnector(_supabase));
    return response;
  }

  // 2. Sign In (Staff or Owner)
  Future<void> signIn({required String email, required String password}) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
    // Reconnect PowerSync after successful auth since sign out disconnects it
    db.connect(connector: SupabaseConnector(_supabase));
    await _ensureLocalProfile();
  }

  // 2b. PIN login (Model B) — sign in as the real staffer whose PIN this is,
  // then switch PowerSync to their session WITHOUT clearing local data.
  // Requires connectivity (online-first). `pin-login` verifies the PIN
  // server-side and mints a session we complete with verifyOTP.
  Future<void> loginWithPin({
    required String tenantId,
    required String pin,
  }) async {
    final res = await _supabase.functions.invoke(
      'pin-login',
      body: {'tenant_id': tenantId, 'pin': pin},
    );
    if (res.status != 200) {
      final data = res.data;
      final msg = data is Map
          ? (data['error'] ?? 'Invalid PIN')
          : 'Invalid PIN';
      throw Exception(msg.toString());
    }
    final tokenHash = (res.data as Map)['token_hash'] as String;
    await _supabase.auth.verifyOTP(
      type: OtpType.magiclink,
      tokenHash: tokenHash,
    );
    await switchUser();
    await _ensureLocalProfile();
  }

  /// Reconnect PowerSync to the current Supabase session WITHOUT clearing the
  /// local DB. Used when switching between staff of the **same tenant**: the
  /// buckets are identical, so a fresh connector just swaps the token and sync
  /// resumes — no re-download. (Contrast `signOut`, which clears for a true
  /// logout / tenant change.)
  Future<void> switchUser() async {
    await db.disconnect();
    // A fresh connector has no cached credentials, so connect() re-runs
    // fetchCredentials() and picks up the new user's token immediately.
    db.connect(connector: SupabaseConnector(_supabase));
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

  /// Owner-only: set/reset a staffer's login PIN. The PIN is hashed + checked
  /// for per-tenant uniqueness server-side by the `set-staff-pin` function.
  Future<void> setStaffPin({
    required String targetProfileId,
    required String pin,
  }) async {
    final res = await _supabase.functions.invoke(
      'set-staff-pin',
      body: {'target_profile_id': targetProfileId, 'pin': pin},
    );
    if (res.status != 200) {
      final data = res.data;
      final msg = data is Map ? (data['error'] ?? 'Failed to set PIN') : 'Failed to set PIN';
      throw Exception(msg.toString());
    }
  }

  /// Send a 6-digit OTP to the given email for password reset.
  Future<void> sendPasswordResetOtp({required String email}) async {
    await _supabase.auth.signInWithOtp(email: email, shouldCreateUser: false);
  }

  /// Verify the OTP. On success Supabase establishes a temporary session.
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String otp,
  }) async {
    await _supabase.auth.verifyOTP(
      email: email,
      token: otp,
      type: OtpType
          .email, // Correct: OTP was sent via signInWithOtp (magic-link), not resetPasswordForEmail.
    );
  }

  /// Update the current user's password (works for both reset and change flows).
  /// Caller must ensure a valid session exists (i.e. [verifyPasswordResetOtp] completed successfully).
  Future<void> updatePassword({required String newPassword}) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
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
