# Account Lifecycle Management Implementation Plan

## Goal
Implement a robust account status management system for workstation accounts while clarifying the distinction between "User Accounts" and the "Staff Directory".

## Proposed Changes

### Database & Models
- Added `status` column (enum: active, blocked, inactive) to `profiles`.
- Added `status` column to `staff_members` (as a mirrored flag).
- Updated PowerSync schema to include `status` in `profiles`.
- Implemented SQLite migration in `lib/core/config/powersync.dart` to fix existing local DBs.

### Security logic
- Implemented `statusEnforcerProvider` to monitor auth user status.
- Triggers `signOut()` immediately if status is not `active`.
- Developed `manage-user-status` Edge Function to handle:
    - `ban_duration`: Revoking auth sessions in Supabase Auth.
    - Status updates in `public.profiles`.

### UI Updates
- Renamed "People" -> "Staff Directory".
- Renamed "Staff" -> "User Accounts".
- Added Status badges (`Blocked`, `Inactive`) to lists.
- Integrated management actions (Ban, Block, Delete) into workstation account menu.

### Infrastructure Synchronization
- All Edge Functions synchronized to local `supabase/functions/` for auditing.

## Verification Plan
- [x] Test `ban_duration` effect on active sessions.
- [x] Verify local SQLite schema update via migration.
- [x] Audit locally saved Edge Functions for parity with Supabase.
