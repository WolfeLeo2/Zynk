-- Phase 0.5: Conservative index hygiene.
-- Keep broad baseline indexes; add targeted partial indexes for hot filtered paths.

BEGIN;

-- Legacy product-group index cleanup (idempotent, also handled in reset migration).
DROP INDEX IF EXISTS public.idx_products_group_id;

-- Invoice approval queue queries.
CREATE INDEX IF NOT EXISTS idx_sales_pending_approval_created
  ON public.sales(tenant_id, created_at DESC)
  WHERE status = 'pending_approval';

-- Operational stock adjustment review queue.
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_pending_created
  ON public.stock_adjustments(tenant_id, created_at DESC)
  WHERE status = 'pending';

-- Common payment-method reporting path.
CREATE INDEX IF NOT EXISTS idx_sale_payments_tenant_method_created
  ON public.sale_payments(tenant_id, payment_method, created_at DESC);

COMMIT;
