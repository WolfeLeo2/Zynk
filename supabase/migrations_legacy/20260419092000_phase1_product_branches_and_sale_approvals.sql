-- Phase 1: Shared catalog branch availability + multi-approver primitive.

BEGIN;

CREATE TABLE IF NOT EXISTS public.product_branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(product_id, branch_id)
);

CREATE INDEX IF NOT EXISTS idx_product_branches_tenant_branch
  ON public.product_branches(tenant_id, branch_id);

CREATE INDEX IF NOT EXISTS idx_product_branches_tenant_product
  ON public.product_branches(tenant_id, product_id);

ALTER TABLE public.product_branches ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS product_branches_tenant_isolation ON public.product_branches;
CREATE POLICY product_branches_tenant_isolation
  ON public.product_branches
  FOR ALL
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

CREATE TABLE IF NOT EXISTS public.sale_approvals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  approver_user_id UUID NOT NULL,
  decision TEXT NOT NULL CHECK (decision IN ('approved', 'rejected')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (sale_id, approver_user_id)
);

CREATE INDEX IF NOT EXISTS idx_sale_approvals_tenant_sale_created
  ON public.sale_approvals(tenant_id, sale_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_sale_approvals_tenant_approver
  ON public.sale_approvals(tenant_id, approver_user_id);

ALTER TABLE public.sale_approvals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sale_approvals_tenant_isolation ON public.sale_approvals;
CREATE POLICY sale_approvals_tenant_isolation
  ON public.sale_approvals
  FOR ALL
  USING (tenant_id = public.current_tenant_id())
  WITH CHECK (tenant_id = public.current_tenant_id());

ALTER TABLE public.sales
  ADD COLUMN IF NOT EXISTS required_approvals INT NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS approval_count INT NOT NULL DEFAULT 0;

ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_approval_count_valid;
ALTER TABLE public.sales
  ADD CONSTRAINT sales_approval_count_valid
  CHECK (
    required_approvals >= 1
    AND approval_count >= 0
    AND approval_count <= required_approvals
  )
  NOT VALID;

COMMIT;
