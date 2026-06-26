-- Phase 3: Security and Policy Hardening
-- Project: kfqionlpnjetpmuzsvfb

-- 1) Helper: canonical tenant resolver through profiles.user_id = auth.uid()
CREATE OR REPLACE FUNCTION public.current_tenant_id()
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT p.tenant_id
  FROM public.profiles p
  WHERE p.user_id = (SELECT auth.uid())
  LIMIT 1;
$$;

-- 2) Ensure RLS is enabled on scope tables
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sale_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.credit_note_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tenant_invoice_counters ENABLE ROW LEVEL SECURITY;

-- 3) Replace/normalize tenant isolation policies

-- Tenants
DROP POLICY IF EXISTS "tenants_select_own" ON public.tenants;
CREATE POLICY "tenants_select_own"
ON public.tenants
FOR SELECT
USING (id = public.current_tenant_id());

-- Sales
DROP POLICY IF EXISTS "Enable all for users based on tenant" ON public.sales;
DROP POLICY IF EXISTS "sales_tenant_isolation" ON public.sales;
CREATE POLICY "sales_tenant_isolation"
ON public.sales
FOR ALL
USING (tenant_id = public.current_tenant_id())
WITH CHECK (tenant_id = public.current_tenant_id());

-- Sale items
DROP POLICY IF EXISTS "Enable all for users based on tenant" ON public.sale_items;
DROP POLICY IF EXISTS "sale_items_tenant_isolation" ON public.sale_items;
CREATE POLICY "sale_items_tenant_isolation"
ON public.sale_items
FOR ALL
USING (tenant_id = public.current_tenant_id())
WITH CHECK (tenant_id = public.current_tenant_id());

-- Sale payments
DROP POLICY IF EXISTS "Users can view payments for their tenant" ON public.sale_payments;
DROP POLICY IF EXISTS "Users can insert payments for their tenant" ON public.sale_payments;
DROP POLICY IF EXISTS "Users can update payments for their tenant" ON public.sale_payments;
DROP POLICY IF EXISTS "Users can delete payments for their tenant" ON public.sale_payments;
DROP POLICY IF EXISTS "sale_payments_tenant_isolation" ON public.sale_payments;
CREATE POLICY "sale_payments_tenant_isolation"
ON public.sale_payments
FOR ALL
USING (tenant_id = public.current_tenant_id())
WITH CHECK (tenant_id = public.current_tenant_id());

-- Stock
DROP POLICY IF EXISTS "Enable all for users based on tenant" ON public.stock;
DROP POLICY IF EXISTS "stock_tenant_isolation" ON public.stock;
CREATE POLICY "stock_tenant_isolation"
ON public.stock
FOR ALL
USING (tenant_id = public.current_tenant_id())
WITH CHECK (tenant_id = public.current_tenant_id());

-- Credit notes
DROP POLICY IF EXISTS "Credit notes: tenant isolation" ON public.credit_notes;
DROP POLICY IF EXISTS "credit_notes_tenant_isolation" ON public.credit_notes;
CREATE POLICY "credit_notes_tenant_isolation"
ON public.credit_notes
FOR ALL
USING (tenant_id = public.current_tenant_id())
WITH CHECK (tenant_id = public.current_tenant_id());

-- Credit note items
DROP POLICY IF EXISTS "tenant_iso_credit_note_items" ON public.credit_note_items;
DROP POLICY IF EXISTS "credit_note_items_tenant_isolation" ON public.credit_note_items;
CREATE POLICY "credit_note_items_tenant_isolation"
ON public.credit_note_items
FOR ALL
USING (tenant_id = public.current_tenant_id())
WITH CHECK (tenant_id = public.current_tenant_id());

-- Commissions (tighten from auth.role() = authenticated)
DROP POLICY IF EXISTS "Enable read for authenticated users" ON public.commissions;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON public.commissions;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.commissions;
DROP POLICY IF EXISTS "commissions_tenant_isolation" ON public.commissions;
CREATE POLICY "commissions_tenant_isolation"
ON public.commissions
FOR ALL
USING (tenant_id = public.current_tenant_id())
WITH CHECK (tenant_id = public.current_tenant_id());

-- Tenant invoice counters (avoid permissive true/true policy)
DROP POLICY IF EXISTS "Service role full access on invoice counters" ON public.tenant_invoice_counters;
DROP POLICY IF EXISTS "service_role_access_invoice_counters" ON public.tenant_invoice_counters;
CREATE POLICY "service_role_access_invoice_counters"
ON public.tenant_invoice_counters
FOR ALL
USING ((SELECT auth.role()) = 'service_role')
WITH CHECK ((SELECT auth.role()) = 'service_role');

-- 4) Function hardening: set immutable search_path
ALTER FUNCTION public.decrement_stock(uuid, uuid, integer) SET search_path = public;
ALTER FUNCTION public.increment_stock(uuid, uuid, integer) SET search_path = public;
ALTER FUNCTION public.next_invoice_number(uuid, text, integer) SET search_path = public;
ALTER FUNCTION public.handle_new_user() SET search_path = public;
ALTER FUNCTION public.calculate_commission_on_sale() SET search_path = public;
ALTER FUNCTION public.set_sale_item_tenant_id() SET search_path = public;
ALTER FUNCTION public.update_updated_at_column() SET search_path = public;
