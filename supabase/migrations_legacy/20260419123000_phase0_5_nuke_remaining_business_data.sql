-- Phase 0.5 follow-up: complete fresh-start reset for remaining business data.
-- Preserve identity/admin context (profiles, tenants, staff, branches, profile_branches).

BEGIN;

CREATE SCHEMA IF NOT EXISTS backup_20260419;

DO $$
BEGIN
  IF to_regclass('backup_20260419.customers') IS NULL THEN
    CREATE TABLE backup_20260419.customers AS TABLE public.customers WITH DATA;
  END IF;
END $$;

TRUNCATE TABLE public.customers RESTART IDENTITY CASCADE;

COMMIT;
