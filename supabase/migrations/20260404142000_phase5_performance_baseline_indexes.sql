-- Phase 5: Performance Baseline - Index hardening for tenant/branch/reporting paths
-- Project: kfqionlpnjetpmuzsvfb

-- Profiles
CREATE INDEX IF NOT EXISTS idx_profiles_user_id ON public.profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_tenant_id ON public.profiles(tenant_id);

-- Sales
CREATE INDEX IF NOT EXISTS idx_sales_tenant_branch_created
  ON public.sales(tenant_id, branch_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sales_tenant_payment_status
  ON public.sales(tenant_id, payment_status);
CREATE INDEX IF NOT EXISTS idx_sales_tenant_fulfillment_status
  ON public.sales(tenant_id, fulfillment_status);

-- Sale items
CREATE INDEX IF NOT EXISTS idx_sale_items_tenant_sale
  ON public.sale_items(tenant_id, sale_id);

-- Sale payments
CREATE INDEX IF NOT EXISTS idx_sale_payments_tenant_sale_created
  ON public.sale_payments(tenant_id, sale_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_sale_payments_tenant_branch_created
  ON public.sale_payments(tenant_id, branch_id, created_at DESC);

-- Credit notes
CREATE INDEX IF NOT EXISTS idx_credit_notes_tenant_created
  ON public.credit_notes(tenant_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_credit_note_items_tenant_credit
  ON public.credit_note_items(tenant_id, credit_note_id);

-- Commissions
CREATE INDEX IF NOT EXISTS idx_commissions_tenant_salesperson_status_created
  ON public.commissions(tenant_id, salesperson_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_commissions_tenant_sale
  ON public.commissions(tenant_id, sale_id);

-- Stock
CREATE INDEX IF NOT EXISTS idx_stock_tenant_branch_product
  ON public.stock(tenant_id, branch_id, product_id);
