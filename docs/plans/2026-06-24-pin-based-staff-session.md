# PIN-based Staff Session (Model B) — Implementation Plan

**Branch:** `feat/pin-staff-session`
**Date:** 2026-06-24
**Status:** Draft — awaiting build go-ahead

---

## 1. Goal & non-goals

**Goal:** On a shared device, let staff switch users with a short **PIN** instead of typing email+password — and *without* the slow full re-sync that happens today. Each staffer remains their **own real Supabase account**, so identity, owner ops, and attribution all work natively.

**Non-goals (this phase):**
- Removing the `salesperson` table/field (deferred; this lands the groundwork — once every action is done by a real signed-in staffer, salesperson auto-derives from `auth.uid()`).
- Offline *user-switching* (see §7 — switching requires a quick auth call; this is the one real caveat to settle).
- Biometric unlock (could layer on later via `local_auth`).

---

## 2. The model (Model B) — and why it fits

You already have **one real Supabase account per staffer**. We keep that. The PIN is just a fast, local way to sign that account in — "the PIN stands in for that staffer's email+password", exactly as you described.

The slowness today is **not** the auth call — it's that `signOut()` runs `db.disconnectAndClear()` (wipes the local DB) and the next `signIn()` re-downloads everything (`auth_service.dart:68-73`, `repository.dart:39-40`).

**Key insight:** all staff in the **same tenant** sync the **identical** data (the PowerSync `user_data` bucket is parameterized by `tenant_id`). So switching from staff A to staff B in the same tenant does **not** change the synced data. If we switch the Supabase session **without clearing the DB**, PowerSync just reconnects with the new token over the *same* buckets → **no re-download**. The switch becomes a quick token swap.

```
Enroll once per device (real email+password login) ─► cache that staffer's session, encrypted, gated by their PIN
PIN entry ─► verify PIN ─► load cached session ─► setSession(new token) ─► PowerSync reconnects (same tenant buckets, NO clear, NO re-download)
Full sign-out (or different tenant) ─► the existing disconnectAndClear() path
```

Because the signed-in user is the **real staffer**, `auth.uid()`, RLS, `created_by`, permissions and owner ops all work with **no identity-splitting refactor** — this is simpler than the Model A we first sketched.

---

## 3. Switching without the wipe (the core change)

`disconnectAndClear()` = **disconnect** (stop syncing) **+ clear** (wipe local rows). The *clear* is the painful part and is only correct on a true sign-out. So we keep it for sign-out and add a no-clear path for switching:

- **`switchUser(...)`** (new) — set the new staffer's session, then `db.disconnect()` → `db.connect(connector)`. **No clear.** The disconnect/reconnect only forces PowerSync to re-run `fetchCredentials` and pick up the new token; local data stays, same-tenant buckets → no re-download. (If `powersync ^1.17` exposes a credentials-invalidate/refresh call, prefer that for a gap-free swap — confirm the exact API in Phase 1; `disconnect`+`connect` is the reliable fallback.)
- **`signOut()`** (existing path) — keeps `disconnectAndClear()`. Used for a true sign-out / tenant change. Rare now (PIN switching replaces most logouts), so the full re-sync on next login there is acceptable.

Guard: only use the no-clear `switchUser` path when the incoming user's `tenant_id` matches the current local data's tenant. A different-tenant login falls back to clear + full sync.

> Phase 1 must **verify empirically** that reconnecting with a new same-tenant token does not trigger a full re-download (expected, given bucket parameterization — but confirm on-device before building the rest).

---

## 4. How the PIN signs the user in

The PIN must unlock a credential to authenticate. Recommended:

- **Enrollment (once per device):** staffer signs in normally (email+password). We capture their Supabase **session (refresh token)** and store it in `flutter_secure_storage`, encrypted, **gated by their PIN** (PIN-derived key, or store-then-verify-PIN). No raw passwords kept.
- **Switch:** enter PIN → verify against `profiles.pin_hash` (synced locally, works offline) → load that staffer's cached refresh token → `supabase.auth.setSession(refreshToken)` → `switchUser()` (no wipe).
- **Never enrolled on this device** → fall back to a one-time email+password login, then enroll.

Alternative considered — a `pin-login` **edge function** that mints a session server-side (no tokens cached on device): more secure, but **needs connectivity for every switch** and more backend work. The cached-session approach is the better default; revisit if token caching is unacceptable. (Decision flag, §9.)

---

## 5. Data model & PIN security

Migration (Supabase MCP) on `profiles`:

```sql
ALTER TABLE public.profiles
  ADD COLUMN pin_hash text,        -- slow-KDF hash; verifies the PIN (offline-capable, synced)
  ADD COLUMN pin_set_at timestamptz,
  ADD COLUMN pin_lookup text;      -- HMAC(server-pepper, pin): uniqueness + "which staffer owns this PIN"
CREATE UNIQUE INDEX profiles_tenant_pin_lookup_uniq
  ON public.profiles (tenant_id, pin_lookup) WHERE pin_lookup IS NOT NULL;
```

Security (all required — a 6-digit PIN is only 1,000,000 combos and `pin_hash` syncs to the device, so it's offline-attackable):
1. **≥6 digits** (enforced in the set-PIN UI).
2. **Slow KDF** — Argon2id (`cryptography`) or PBKDF2 high-iteration (`pointycastle`), per-row salt. **Plain `crypto`/SHA-256 is NOT enough.**
3. **Attempt lockout** — N fails → exponential cooldown (local; mirror server-side if feasible).
4. **Server-side pepper** for `pin_lookup`, so the synced DB alone can't enumerate PINs.
5. Lean on physical device trust (counter device).

**Where hashing happens:** at set/reset time in an edge function (`set-staff-pin`) — owns algorithm + salt + pepper. PIN **verification** at switch time is local (KDF the entered PIN, compare to synced `pin_hash`) so the lock screen works offline.

---

## 6. On-device storage (`flutter_secure_storage`)

Stores: each enrolled staffer's encrypted session/refresh token, lockout counters, and which profile is active.

- **Android/iOS:** Keystore / Keychain (strong).
- **Web (Vercel):** uses Web Crypto (`SubtleCrypto`) → requires a **secure context = HTTPS**. **Vercel is HTTPS by default → works in production**; `localhost` is also a secure context for dev. Web storage is weaker than native (wrapping key lives in browser storage) — acceptable, since the PIN + auto-lock are the real gate and the Supabase session already lives in browser storage on web anyway.

New deps: `flutter_secure_storage`, plus `cryptography` (Argon2id) **or** `pointycastle` (PBKDF2).

---

## 7. Authorization, attribution, P0-1/P0-2 — all easy under Model B

- **Per-user authz works natively** — the signed-in user *is* the staffer, so `auth.uid()`, RLS and JWT-based edge-function checks all see the real person. **No extra mechanism needed.** (This is the opposite of Model A, where a shared device token broke per-user identity.)
- **Owner ops:** owner signs in for real (your Q5) → everything works, no step-up hack. **No owner step-up UI** (per your Q5).
- **Attribution:** `created_by` / `salesperson_id` are the real `auth.uid()` automatically — lands the future salesperson-auto-derive cleanly.
- **Relation to P0-1/P0-2:** Model B does **not** complicate them at all. They remain the standard device-level fixes (verify the JWT, scope every query by `tenant_id`), and per-user identity is intact because each session is a real user. (Correction to earlier chat: the per-user-authz complication was a Model-A problem; it does not apply here.)

**Offline switching — resolved: online-first.** A switch is a real auth/token refresh, so it needs network. This is **not** a hard requirement (decided) — switching is online-only for now, which also keeps session management simpler. Document it in the UI (a clear "no connection — can't switch user" state).

---

## 8. UX pieces (plain English)

- **PIN pad / lock screen** — the screen with the number dial where a user taps their PIN. Shown when no one is "unlocked".
- **PIN verification** — just: *check the typed PIN is correct* (matches a staffer's `pin_hash`) before letting them in. Nothing fancier.
- **Drawer "Lock" / "Switch user" action** — a button in the side navigation drawer. Tapping it ends the current person's session and returns to the PIN pad so the next person can enter their PIN. ("Drawer" = the existing slide-out menu; "lock" = the button that re-shows the PIN pad.)
- **Flow (exactly as you described):** PIN pad → enter PIN → (session swap happens) → the **`AppShell` welcome/loading screen we built** shows while the profile loads → app ready.
- **Idle auto-lock** — after the idle timeout, auto-show the PIN pad. **Required** so sales don't get attributed to whoever last unlocked. **Default 120s**, owner-configurable via a Settings tile with options **1 / 2 / 5 / 10 min** (persist per device, or per tenant if synced).
- **Set PIN** — owner-scoped only (lives on the staff/user management page). **No "forgot PIN" UI on the lock screen** (per your Q4); the owner resets a staffer's PIN from the user page.

---

## 9. Decisions

**Resolved:**
- Each staffer = real Supabase account; owner ops via real owner sign-in, no step-up ✓
- PIN set/reset is owner-only; no forgot-PIN UI on the lock screen ✓
- **Offline switching not required — online-first** ✓
- **Auto-lock: 120s default, owner-configurable (1 / 2 / 5 / 10 min) via a Settings tile** ✓
- Switch path keeps local data (`disconnect`+`connect`, no clear); full sign-out keeps `disconnectAndClear` ✓

**Still open:**
1. **Credential mechanism** (§4) — cached session/refresh token (recommended) vs `pin-login` edge function. Since we're online-first, the edge-function option is now more viable and avoids caching tokens on device; weigh in Phase 1.
2. **PIN length** — 6 recommended (confirm).

---

## 10. Phasing (incremental, each shippable)

1. **Foundation & proof** — add deps; `profiles` migration; `set-staff-pin` edge fn; implement `switchUser()` (no-wipe) and **verify no re-download on same-tenant token swap**.
2. **Enrollment + PIN set** — owner sets a staffer's PIN; device captures/encrypts that staffer's session on their first login.
3. **Lock flow** — PIN pad + verification + drawer Lock/Switch action → `switchUser()` → welcome screen.
4. **Auto-lock** — idle timer.
5. **Lockout + reset** — failed-attempt lockout; owner PIN reset.
6. **Hardening + tests** (§11).

---

## 11. Testing

- PIN hash/verify round-trip; wrong PIN; lockout after N attempts; per-tenant PIN uniqueness.
- **Switch user does NOT re-download** (assert local row counts stable across a same-tenant switch).
- Attribution: after switch, `created_by`/`salesperson_id` = the new staffer.
- Auto-lock after idle; restart restores locked state.
- Web (Vercel preview) secure-storage smoke test over HTTPS.

---

## 12. Risks / watch-list

- **Offline switching needs network** (§7) — the key product decision.
- Short-PIN offline brute force → ≥6 digits + slow KDF + lockout + pepper.
- Caching session tokens on device (esp. web) — encrypted + PIN-gated; accept the web ceiling.
- The `switchUser()` no-wipe path must be tenant-guarded so a different-tenant login still clears.
- Device session refresh-token longevity — if a staffer's refresh token expires, they re-enroll (one email+password login).
- Auto-lock is mandatory for correct attribution.
