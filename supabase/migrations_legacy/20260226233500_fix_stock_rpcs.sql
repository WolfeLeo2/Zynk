-- Drop old RPCs targeting 'inventory'
DROP FUNCTION IF EXISTS public.decrement_stock;
DROP FUNCTION IF EXISTS public.increment_stock;

-- Recreate targeting 'stock'
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
  UPDATE public.stock
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
  UPDATE public.stock
  SET quantity = quantity + p_quantity,
      updated_at = NOW()
  WHERE product_id = p_product_id
    AND branch_id = p_branch_id;
END;
$$;
