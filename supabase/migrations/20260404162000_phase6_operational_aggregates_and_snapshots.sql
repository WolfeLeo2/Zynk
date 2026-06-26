-- Phase 6: Operational aggregates + scheduled daily KPI snapshots
-- Project: kfqionlpnjetpmuzsvfb

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE TABLE IF NOT EXISTS public.daily_kpi_snapshots (
  snapshot_date date NOT NULL,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  orders_count integer NOT NULL DEFAULT 0,
  gross_sales numeric NOT NULL DEFAULT 0,
  payments_collected numeric NOT NULL DEFAULT 0,
  pending_approval_count integer NOT NULL DEFAULT 0,
  low_stock_count integer NOT NULL DEFAULT 0,
  inventory_value numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT daily_kpi_snapshots_pkey PRIMARY KEY (snapshot_date, tenant_id, branch_id)
);

CREATE TABLE IF NOT EXISTS public.daily_payment_method_snapshots (
  snapshot_date date NOT NULL,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  payment_method text NOT NULL,
  txn_count integer NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT daily_payment_method_snapshots_pkey PRIMARY KEY (snapshot_date, tenant_id, branch_id, payment_method)
);

CREATE TABLE IF NOT EXISTS public.daily_product_sales_snapshots (
  snapshot_date date NOT NULL,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  quantity_sold bigint NOT NULL DEFAULT 0,
  revenue_total numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT daily_product_sales_snapshots_pkey PRIMARY KEY (snapshot_date, tenant_id, branch_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_daily_kpi_snapshots_tenant_date
  ON public.daily_kpi_snapshots(tenant_id, snapshot_date, branch_id);
CREATE INDEX IF NOT EXISTS idx_daily_payment_method_snapshots_tenant_date
  ON public.daily_payment_method_snapshots(tenant_id, snapshot_date, branch_id);
CREATE INDEX IF NOT EXISTS idx_daily_product_sales_snapshots_tenant_date
  ON public.daily_product_sales_snapshots(tenant_id, snapshot_date, branch_id);

ALTER TABLE public.daily_kpi_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_payment_method_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_product_sales_snapshots ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS daily_kpi_snapshots_select_tenant ON public.daily_kpi_snapshots;
CREATE POLICY daily_kpi_snapshots_select_tenant
  ON public.daily_kpi_snapshots
  FOR SELECT
  USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS daily_kpi_snapshots_service_all ON public.daily_kpi_snapshots;
CREATE POLICY daily_kpi_snapshots_service_all
  ON public.daily_kpi_snapshots
  FOR ALL
  USING ((SELECT auth.role()) = 'service_role')
  WITH CHECK ((SELECT auth.role()) = 'service_role');

DROP POLICY IF EXISTS daily_payment_method_snapshots_select_tenant ON public.daily_payment_method_snapshots;
CREATE POLICY daily_payment_method_snapshots_select_tenant
  ON public.daily_payment_method_snapshots
  FOR SELECT
  USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS daily_payment_method_snapshots_service_all ON public.daily_payment_method_snapshots;
CREATE POLICY daily_payment_method_snapshots_service_all
  ON public.daily_payment_method_snapshots
  FOR ALL
  USING ((SELECT auth.role()) = 'service_role')
  WITH CHECK ((SELECT auth.role()) = 'service_role');

DROP POLICY IF EXISTS daily_product_sales_snapshots_select_tenant ON public.daily_product_sales_snapshots;
CREATE POLICY daily_product_sales_snapshots_select_tenant
  ON public.daily_product_sales_snapshots
  FOR SELECT
  USING (tenant_id = public.current_tenant_id());

DROP POLICY IF EXISTS daily_product_sales_snapshots_service_all ON public.daily_product_sales_snapshots;
CREATE POLICY daily_product_sales_snapshots_service_all
  ON public.daily_product_sales_snapshots
  FOR ALL
  USING ((SELECT auth.role()) = 'service_role')
  WITH CHECK ((SELECT auth.role()) = 'service_role');

CREATE OR REPLACE FUNCTION public.refresh_daily_operational_aggregates(
  p_snapshot_date date DEFAULT (((now() AT TIME ZONE 'utc')::date) - 1)
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM public.daily_kpi_snapshots
  WHERE snapshot_date = p_snapshot_date;

  INSERT INTO public.daily_kpi_snapshots (
    snapshot_date,
    tenant_id,
    branch_id,
    orders_count,
    gross_sales,
    payments_collected,
    pending_approval_count,
    low_stock_count,
    inventory_value,
    created_at,
    updated_at
  )
  WITH branch_scope AS (
    SELECT b.tenant_id, b.id AS branch_id
    FROM public.branches b
  ),
  sales_agg AS (
    SELECT
      s.tenant_id,
      s.branch_id,
      COUNT(*) FILTER (
        WHERE s.status NOT IN ('draft', 'voided', 'rejected', 'pending_approval')
      )::integer AS orders_count,
      COALESCE(
        SUM(
          CASE
            WHEN s.status NOT IN ('draft', 'voided', 'rejected')
            THEN s.grand_total
            ELSE 0
          END
        ),
        0
      )::numeric AS gross_sales,
      COUNT(*) FILTER (WHERE s.status = 'pending_approval')::integer AS pending_approval_count
    FROM public.sales s
    WHERE (s.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
    GROUP BY s.tenant_id, s.branch_id
  ),
  payments_agg AS (
    SELECT
      sp.tenant_id,
      sp.branch_id,
      COALESCE(SUM(sp.amount), 0)::numeric AS payments_collected
    FROM public.sale_payments sp
    WHERE (sp.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
    GROUP BY sp.tenant_id, sp.branch_id
  ),
  stock_agg AS (
    SELECT
      st.tenant_id,
      st.branch_id,
      COUNT(*) FILTER (
        WHERE st.quantity <= st.reorder_level AND st.quantity >= 0
      )::integer AS low_stock_count,
      COALESCE(
        SUM(
          CASE
            WHEN st.quantity > 0 THEN st.quantity * COALESCE(p.cost_price, 0)
            ELSE 0
          END
        ),
        0
      )::numeric AS inventory_value
    FROM public.stock st
    LEFT JOIN public.products p ON p.id = st.product_id
    GROUP BY st.tenant_id, st.branch_id
  )
  SELECT
    p_snapshot_date,
    bs.tenant_id,
    bs.branch_id,
    COALESCE(sa.orders_count, 0),
    COALESCE(sa.gross_sales, 0),
    COALESCE(pa.payments_collected, 0),
    COALESCE(sa.pending_approval_count, 0),
    COALESCE(sta.low_stock_count, 0),
    COALESCE(sta.inventory_value, 0),
    now(),
    now()
  FROM branch_scope bs
  LEFT JOIN sales_agg sa
    ON sa.tenant_id = bs.tenant_id AND sa.branch_id = bs.branch_id
  LEFT JOIN payments_agg pa
    ON pa.tenant_id = bs.tenant_id AND pa.branch_id = bs.branch_id
  LEFT JOIN stock_agg sta
    ON sta.tenant_id = bs.tenant_id AND sta.branch_id = bs.branch_id;

  DELETE FROM public.daily_payment_method_snapshots
  WHERE snapshot_date = p_snapshot_date;

  INSERT INTO public.daily_payment_method_snapshots (
    snapshot_date,
    tenant_id,
    branch_id,
    payment_method,
    txn_count,
    total_amount,
    created_at,
    updated_at
  )
  SELECT
    p_snapshot_date,
    sp.tenant_id,
    sp.branch_id,
    COALESCE(NULLIF(sp.payment_method, ''), 'unknown') AS payment_method,
    COUNT(*)::integer,
    COALESCE(SUM(sp.amount), 0)::numeric,
    now(),
    now()
  FROM public.sale_payments sp
  WHERE (sp.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
  GROUP BY sp.tenant_id, sp.branch_id, COALESCE(NULLIF(sp.payment_method, ''), 'unknown');

  DELETE FROM public.daily_product_sales_snapshots
  WHERE snapshot_date = p_snapshot_date;

  INSERT INTO public.daily_product_sales_snapshots (
    snapshot_date,
    tenant_id,
    branch_id,
    product_id,
    quantity_sold,
    revenue_total,
    created_at,
    updated_at
  )
  SELECT
    p_snapshot_date,
    s.tenant_id,
    s.branch_id,
    si.product_id,
    COALESCE(SUM(si.quantity), 0)::bigint,
    COALESCE(SUM(si.total), 0)::numeric,
    now(),
    now()
  FROM public.sale_items si
  INNER JOIN public.sales s ON s.id = si.sale_id
  WHERE (s.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
    AND s.status NOT IN ('draft', 'voided', 'rejected')
  GROUP BY s.tenant_id, s.branch_id, si.product_id;
END;
$$;

-- Ensure idempotent job setup
DO $$
DECLARE
  existing_job_id bigint;
BEGIN
  SELECT jobid INTO existing_job_id FROM cron.job WHERE jobname = 'daily-operational-aggregates-finalize';
  IF existing_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_job_id);
  END IF;

  SELECT jobid INTO existing_job_id FROM cron.job WHERE jobname = 'hourly-operational-aggregates-refresh';
  IF existing_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(existing_job_id);
  END IF;
END $$;

SELECT cron.schedule(
  'daily-operational-aggregates-finalize',
  '15 0 * * *',
  $$SELECT public.refresh_daily_operational_aggregates(((now() AT TIME ZONE 'utc')::date - 1));$$
);

SELECT cron.schedule(
  'hourly-operational-aggregates-refresh',
  '10 * * * *',
  $$SELECT public.refresh_daily_operational_aggregates((now() AT TIME ZONE 'utc')::date);$$
);

-- Backfill recent history and refresh today once
DO $$
DECLARE
  d date;
BEGIN
  FOR d IN
    SELECT gs::date
    FROM generate_series(
      ((now() AT TIME ZONE 'utc')::date - INTERVAL '30 days'),
      ((now() AT TIME ZONE 'utc')::date),
      INTERVAL '1 day'
    ) AS gs
  LOOP
    PERFORM public.refresh_daily_operational_aggregates(d);
  END LOOP;
END $$;
