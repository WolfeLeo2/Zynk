# Skill: Drift & Supabase Schema Synchronization
**Goal:** Ensure the local Drift database and the remote Supabase database stay perfectly in sync.

**Instructions:**
1.  **Dual Schema Updates:** ANY change made to `lib/data/local/db.dart` (Drift schema) MUST be immediately mirrored in a Supabase migration file and applied using my Supabase MCP.
2.  **Migration Files:** Create new SQL files in `supabase/migrations/` for every schema change. Use a timestamp prefix (e.g., `YYYYMMDDHHMMSS_description.sql`).
3.  **Field Parity:** Ensure field names, types, and constraints match exactly.
    *   Drift `TextColumn` -> Supabase `text`
    *   Drift `IntColumn` -> Supabase `integer` or `bigint`
    *   Drift `RealColumn` -> Supabase `float` or `numeric`
    *   Drift `BoolColumn` -> Supabase `boolean`
    *   Drift `DateTimeColumn` -> Supabase `timestamp with time zone` (timestamptz)
4.  **Documentation:** Update `docs/SCHEMA.md` to reflect the latest schema state.
5.  **Verification:** Always run `flutter packages pub run build_runner build` after Drift changes to ensure code generation is successful.
