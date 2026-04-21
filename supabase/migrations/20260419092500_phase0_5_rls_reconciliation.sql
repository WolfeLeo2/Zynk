-- Phase 0.5: RLS reconciliation to avoid permissive policy drift.

BEGIN;

-- Ensure canonical tenant-isolation tables are RLS-enabled.
DO $$
DECLARE
  t TEXT;
  tenant_tables TEXT[] := ARRAY[
    'products',
    'product_branches',
    'categories',
    'item_groups',
    'composite_item_components',
    'units_of_measurement',
    'stock',
    'stock_adjustments',
    'stock_adjustment_reasons',
    'customers',
    'sales',
    'sale_items',
    'sale_payments',
    'credit_notes',
    'credit_note_items',
    'commissions',
    'profile_branches',
    'sale_approvals',
    'locations',
    'branches',
    'staff_members'
  ];
BEGIN
  FOREACH t IN ARRAY tenant_tables LOOP
    IF to_regclass(format('public.%I', t)) IS NOT NULL THEN
      EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    END IF;
  END LOOP;
END $$;

-- Remove historically permissive auth-role-only policies if still present.
DROP POLICY IF EXISTS "Enable read for authenticated users" ON public.commissions;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.commissions;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.commissions;
DROP POLICY IF EXISTS "Enable read for authenticated users" ON public.profile_branches;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.profile_branches;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.profile_branches;
DROP POLICY IF EXISTS "Enable delete for authenticated users" ON public.profile_branches;

-- Reassert canonical tenant policies for new tables.
DROP POLICY IF EXISTS product_branches_tenant_isolation ON public.product_branches;
CREATE POLICY product_branches_tenant_isolation
  ON public.product_branches
  FOR ALL
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS sale_approvals_tenant_isolation ON public.sale_approvals;
CREATE POLICY sale_approvals_tenant_isolation
  ON public.sale_approvals
  FOR ALL
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

COMMIT;
