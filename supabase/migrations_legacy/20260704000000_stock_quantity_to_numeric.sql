-- Allow fractional stock quantities (some products are tracked in fractional
-- units). Widen quantity/previous_quantity columns and the increment/decrement
-- RPCs from integer to numeric; reorder_level stays integer (a whole-unit
-- threshold set by the owner).

ALTER TABLE public.stock
  ALTER COLUMN quantity TYPE numeric USING quantity::numeric;

ALTER TABLE public.stock_adjustments
  ALTER COLUMN quantity TYPE numeric USING quantity::numeric,
  ALTER COLUMN previous_quantity TYPE numeric USING previous_quantity::numeric;

DROP FUNCTION IF EXISTS public.decrement_stock(uuid, uuid, integer);
DROP FUNCTION IF EXISTS public.increment_stock(uuid, uuid, integer);

CREATE FUNCTION public.decrement_stock(
  p_product_id UUID,
  p_branch_id UUID,
  p_quantity NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.stock
  SET quantity = quantity - p_quantity,
      last_updated = NOW()
  WHERE product_id = p_product_id
    AND branch_id = p_branch_id;
END;
$$;

CREATE FUNCTION public.increment_stock(
  p_product_id UUID,
  p_branch_id UUID,
  p_quantity NUMERIC
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.stock
  SET quantity = quantity + p_quantity,
      last_updated = NOW()
  WHERE product_id = p_product_id
    AND branch_id = p_branch_id;
END;
$$;
