-- Phase 3 follow-up: Reduce auth_rls_initplan warnings
-- Strategy:
-- 1) Normalize tenant-scoped table policies to use current_tenant_id()
-- 2) Rewrite profiles policies to use (select auth.uid()) wrappers

-- Tenant-scoped tables that should use a canonical tenant policy.
DO $$
DECLARE
  t text;
  p record;
  tenant_tables text[] := ARRAY[
    'products',
    'locations',
    'item_groups',
    'categories',
    'branches',
    'staff_members',
    'customers',
    'units_of_measurement',
    'stock_adjustments',
    'stock_adjustment_reasons',
    'stock_item_groups',
    'composite_item_components',
    'profile_branches'
  ];
BEGIN
  FOREACH t IN ARRAY tenant_tables LOOP
    IF to_regclass(format('public.%I', t)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);

      FOR p IN
        SELECT policyname
        FROM pg_policies
        WHERE schemaname = 'public' AND tablename = t
      LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', p.policyname, t);
      END LOOP;

      EXECUTE format(
        'CREATE POLICY %I ON public.%I FOR ALL USING (tenant_id = public.current_tenant_id()) WITH CHECK (tenant_id = public.current_tenant_id())',
        t || '_tenant_isolation',
        t
      );
    END IF;
  END LOOP;
END $$;

-- Profiles: preserve user-scoped write semantics and tenant-scoped read semantics
DO $$
DECLARE
  p record;
BEGIN
  IF to_regclass('public.profiles') IS NOT NULL THEN
    ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

    FOR p IN
      SELECT policyname
      FROM pg_policies
      WHERE schemaname = 'public' AND tablename = 'profiles'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', p.policyname);
    END LOOP;

    CREATE POLICY profiles_select_own_or_tenant
      ON public.profiles
      FOR SELECT
      USING (
        user_id = (SELECT auth.uid())
        OR tenant_id = public.current_tenant_id()
      );

    CREATE POLICY profiles_insert_own
      ON public.profiles
      FOR INSERT
      WITH CHECK (user_id = (SELECT auth.uid()));

    CREATE POLICY profiles_update_own
      ON public.profiles
      FOR UPDATE
      USING (user_id = (SELECT auth.uid()))
      WITH CHECK (user_id = (SELECT auth.uid()));

    CREATE POLICY profiles_delete_own
      ON public.profiles
      FOR DELETE
      USING (user_id = (SELECT auth.uid()));
  END IF;
END $$;
