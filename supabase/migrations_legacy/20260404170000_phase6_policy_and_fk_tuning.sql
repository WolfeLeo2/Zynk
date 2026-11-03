-- Phase 6 follow-up: remove multiple permissive policy warnings
-- and add remaining FK-covering indexes for snapshot tables.

-- FK-covering indexes flagged by advisor
CREATE INDEX IF NOT EXISTS idx_daily_kpi_snapshots_branch_id
  ON public.daily_kpi_snapshots(branch_id);
CREATE INDEX IF NOT EXISTS idx_daily_payment_method_snapshots_branch_id
  ON public.daily_payment_method_snapshots(branch_id);
CREATE INDEX IF NOT EXISTS idx_daily_product_sales_snapshots_branch_id
  ON public.daily_product_sales_snapshots(branch_id);
CREATE INDEX IF NOT EXISTS idx_daily_product_sales_snapshots_product_id
  ON public.daily_product_sales_snapshots(product_id);

-- Remove service-all policies that overlap SELECT and trigger
-- multiple_permissive_policies warnings.
DROP POLICY IF EXISTS daily_kpi_snapshots_service_all ON public.daily_kpi_snapshots;
DROP POLICY IF EXISTS daily_payment_method_snapshots_service_all ON public.daily_payment_method_snapshots;
DROP POLICY IF EXISTS daily_product_sales_snapshots_service_all ON public.daily_product_sales_snapshots;

-- Service-role write policies only (SELECT remains tenant-isolated policy)
CREATE POLICY daily_kpi_snapshots_service_insert
  ON public.daily_kpi_snapshots
  FOR INSERT
  WITH CHECK ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_kpi_snapshots_service_update
  ON public.daily_kpi_snapshots
  FOR UPDATE
  USING ((SELECT auth.role()) = 'service_role')
  WITH CHECK ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_kpi_snapshots_service_delete
  ON public.daily_kpi_snapshots
  FOR DELETE
  USING ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_payment_method_snapshots_service_insert
  ON public.daily_payment_method_snapshots
  FOR INSERT
  WITH CHECK ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_payment_method_snapshots_service_update
  ON public.daily_payment_method_snapshots
  FOR UPDATE
  USING ((SELECT auth.role()) = 'service_role')
  WITH CHECK ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_payment_method_snapshots_service_delete
  ON public.daily_payment_method_snapshots
  FOR DELETE
  USING ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_product_sales_snapshots_service_insert
  ON public.daily_product_sales_snapshots
  FOR INSERT
  WITH CHECK ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_product_sales_snapshots_service_update
  ON public.daily_product_sales_snapshots
  FOR UPDATE
  USING ((SELECT auth.role()) = 'service_role')
  WITH CHECK ((SELECT auth.role()) = 'service_role');

CREATE POLICY daily_product_sales_snapshots_service_delete
  ON public.daily_product_sales_snapshots
  FOR DELETE
  USING ((SELECT auth.role()) = 'service_role');
