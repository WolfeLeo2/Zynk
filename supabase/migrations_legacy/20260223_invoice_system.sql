-- Migration: Add tenant_invoice_counters table and next_invoice_number RPC
-- Also adds permissions column to profiles

-- ─── Invoice Counter Table ───
CREATE TABLE IF NOT EXISTS public.tenant_invoice_counters (
  tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  prefix TEXT NOT NULL DEFAULT 'INV',
  year INT NOT NULL,
  last_seq INT NOT NULL DEFAULT 0,
  PRIMARY KEY (tenant_id, prefix, year)
);

-- Enable RLS
ALTER TABLE public.tenant_invoice_counters ENABLE ROW LEVEL SECURITY;

-- RLS policy: only service role can access (edge functions use service role)
CREATE POLICY "Service role full access on invoice counters"
  ON public.tenant_invoice_counters
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ─── Atomic invoice number generator ───
CREATE OR REPLACE FUNCTION public.next_invoice_number(
  p_tenant_id UUID,
  p_prefix TEXT DEFAULT 'INV',
  p_year INT DEFAULT EXTRACT(YEAR FROM NOW())::INT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_seq INT;
BEGIN
  INSERT INTO public.tenant_invoice_counters (tenant_id, prefix, year, last_seq)
  VALUES (p_tenant_id, p_prefix, p_year, 1)
  ON CONFLICT (tenant_id, prefix, year)
  DO UPDATE SET last_seq = public.tenant_invoice_counters.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN v_seq;
END;
$$;

-- ─── Stock helper RPCs ───
CREATE OR REPLACE FUNCTION public.decrement_stock(
  p_product_id UUID,
  p_branch_id UUID,
  p_quantity INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.inventory
  SET quantity = quantity - p_quantity,
      updated_at = NOW()
  WHERE product_id = p_product_id
    AND branch_id = p_branch_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.increment_stock(
  p_product_id UUID,
  p_branch_id UUID,
  p_quantity INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.inventory
  SET quantity = quantity + p_quantity,
      updated_at = NOW()
  WHERE product_id = p_product_id
    AND branch_id = p_branch_id;
END;
$$;

-- ─── Add permissions column to profiles ───
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS permissions JSONB DEFAULT '[]'::JSONB;
