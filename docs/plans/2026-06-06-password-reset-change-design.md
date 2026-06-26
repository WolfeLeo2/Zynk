# Password Reset & Change — Design Document

## Summary

Add two password-related flows to the Zynk/PH app:

1. **Forgot Password** — unauthenticated, from the Sign In screen.  
   User enters email → receives 6-digit OTP → enters OTP → sets new password.
2. **Change Password** — authenticated, from the Settings screen.  
   User navigates to a dedicated screen and sets a new password directly.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Reset method | OTP (not magic link) | Keeps user in-app, no deep-link complexity on web |
| Change password placement | Dedicated screen `/settings/change-password` | Cleaner UX than modal or inline fields |
| Current password required? | No — Supabase session is sufficient proof | Supabase `updateUser` only requires a valid session |

## Auth Flow — Forgot Password (3 steps)

```
/login  ──tap "Forgot password?"──▶  /forgot-password
                                         │ enter email, tap Send Code
                                         ▼
                                     /forgot-password/verify
                                         │ enter 6-digit OTP, tap Verify
                                         ▼
                                     /forgot-password/reset
                                         │ enter + confirm new password, tap Save
                                         ▼
                                     /login  (with success snackbar)
```

**Supabase calls:**
- Step 1 → `supabase.auth.signInWithOtp(email: email, shouldCreateUser: false)`
- Step 2 → `supabase.auth.verifyOTP(email: email, token: otp, type: OtpType.email)`
- Step 3 → `supabase.auth.updateUser(UserAttributes(password: newPassword))`

## Auth Flow — Change Password (1 screen, logged-in only)

```
/settings  ──tap "Change Password"──▶  /settings/change-password
                                           │ enter new + confirm password, tap Save
                                           ▼
                                       /settings  (with success snackbar)
```

**Supabase call:** `supabase.auth.updateUser(UserAttributes(password: newPassword))`

## New Files

| File | Role |
|---|---|
| `lib/features/auth/forgot_password_screen.dart` | Step 1: email entry |
| `lib/features/auth/verify_otp_screen.dart` | Step 2: OTP entry |
| `lib/features/auth/reset_password_screen.dart` | Step 3: new password |
| `lib/features/settings/presentation/change_password_screen.dart` | Authenticated change |

## Modified Files

| File | Change |
|---|---|
| `lib/core/services/auth_service.dart` | Add `sendPasswordResetOtp`, `verifyPasswordResetOtp`, `updatePassword` |
| `lib/core/routes.dart` | Add 4 new routes |
| `lib/features/auth/sign_in_screen.dart` | Wire "Forgot password?" button to `/forgot-password` |
| `lib/features/settings/presentation/settings_screen.dart` | Add "Change Password" tile |
