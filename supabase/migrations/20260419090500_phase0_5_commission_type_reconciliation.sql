-- Phase 0.5: Reconcile commission type vocabulary to canonical values.

BEGIN;

-- Normalize existing values where present.
UPDATE public.item_groups
SET default_commission_type = 'percentage'
WHERE LOWER(COALESCE(default_commission_type, '')) IN ('percent', 'percentage');

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'products'
      AND column_name = 'commission_type'
  ) THEN
    EXECUTE $sql$
      UPDATE public.products
      SET commission_type = 'percentage'
      WHERE LOWER(COALESCE(commission_type, '')) IN ('percent', 'percentage')
    $sql$;
  END IF;
END $$;

-- Keep lookup seeds aligned.
INSERT INTO public.commission_calculation_types (code, label, sort_order, is_legacy) VALUES
  ('none', 'None', 0, false),
  ('fixed', 'Fixed Amount', 10, false),
  ('percentage', 'Percentage', 20, false),
  ('percent', 'Percent (Legacy Alias)', 99, true)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

-- Trigger logic now accepts canonical values and aliases.
CREATE OR REPLACE FUNCTION public.calculate_commission_on_sale()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_item_group_id UUID;
    v_salesperson_id TEXT;
    v_commission_type TEXT;
    v_commission_value DECIMAL;
    v_calculated_amount DECIMAL := 0;
    v_tenant_id UUID;
BEGIN
    SELECT item_group_id, tenant_id INTO v_item_group_id, v_tenant_id
    FROM public.products
    WHERE id = NEW.product_id;

    SELECT salesperson_id INTO v_salesperson_id
    FROM public.sales
    WHERE id = NEW.sale_id;

    IF v_item_group_id IS NOT NULL THEN
        SELECT LOWER(COALESCE(default_commission_type, 'none')), default_commission_value
        INTO v_commission_type, v_commission_value
        FROM public.item_groups
        WHERE id = v_item_group_id;

        IF v_commission_type IN ('percent') THEN
            v_commission_type := 'percentage';
        END IF;

        IF v_commission_type IS NOT NULL
           AND v_commission_type <> 'none'
           AND v_commission_value IS NOT NULL
           AND v_salesperson_id IS NOT NULL THEN

            IF v_commission_type = 'fixed' THEN
                v_calculated_amount := v_commission_value * COALESCE(NEW.quantity, 0);
            ELSIF v_commission_type = 'percentage' THEN
                v_calculated_amount := (COALESCE(NEW.total, 0) * v_commission_value) / 100.0;
            END IF;

            IF v_calculated_amount > 0 AND v_salesperson_id ~* '^[0-9a-fA-F-]{36}$' THEN
                INSERT INTO public.commissions (tenant_id, salesperson_id, sale_id, amount, status)
                VALUES (v_tenant_id, v_salesperson_id::UUID, NEW.sale_id, v_calculated_amount, 'pending');
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_calculate_commission_on_sale ON public.sale_items;
CREATE TRIGGER trg_calculate_commission_on_sale
AFTER INSERT ON public.sale_items
FOR EACH ROW
EXECUTE FUNCTION public.calculate_commission_on_sale();

COMMIT;
