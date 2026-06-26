-- Phase 0.5: Normalize credit note item storage.
-- Source of truth should be credit_note_items; credit_notes.items is kept in sync for compatibility.

BEGIN;

-- Backfill credit_note_items from historical credit_notes.items JSON where item rows are absent.
DO $$
BEGIN
  IF to_regclass('public.credit_notes') IS NOT NULL
     AND to_regclass('public.credit_note_items') IS NOT NULL THEN

    INSERT INTO public.credit_note_items (
      id,
      credit_note_id,
      product_id,
      product_name,
      quantity,
      unit_price,
      tax_amount,
      total,
      tenant_id,
      created_at
    )
    SELECT
      gen_random_uuid(),
      cn.id,
      (j.item->>'product_id')::UUID,
      NULLIF(j.item->>'product_name', ''),
      COALESCE((j.item->>'quantity')::INT, 0),
      COALESCE((j.item->>'unit_price')::NUMERIC, 0),
      COALESCE((j.item->>'tax_amount')::NUMERIC, 0),
      COALESCE((j.item->>'total')::NUMERIC, 0),
      cn.tenant_id,
      COALESCE(cn.created_at, NOW())
    FROM public.credit_notes cn
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE
        WHEN jsonb_typeof(cn.items) = 'array' THEN cn.items
        ELSE '[]'::JSONB
      END
    ) AS j(item)
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.credit_note_items ci
      WHERE ci.credit_note_id = cn.id
    )
      AND (j.item->>'product_id') IS NOT NULL
    ON CONFLICT DO NOTHING;
  END IF;
END $$;

-- Keep compatibility JSON synchronized from normalized rows.
CREATE OR REPLACE FUNCTION public.sync_credit_note_items_json()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_credit_note_id UUID;
BEGIN
  v_credit_note_id := COALESCE(NEW.credit_note_id, OLD.credit_note_id);

  UPDATE public.credit_notes cn
  SET
    items = COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'product_id', ci.product_id,
            'product_name', ci.product_name,
            'quantity', ci.quantity,
            'unit_price', ci.unit_price,
            'tax_amount', ci.tax_amount,
            'total', ci.total
          )
          ORDER BY ci.created_at, ci.id
        )
        FROM public.credit_note_items ci
        WHERE ci.credit_note_id = v_credit_note_id
      ),
      '[]'::JSONB
    ),
    updated_at = NOW()
  WHERE cn.id = v_credit_note_id;

  RETURN NULL;
END;
$$;

DO $$
BEGIN
  IF to_regclass('public.credit_note_items') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'credit_notes'
         AND column_name = 'items'
     ) THEN
    DROP TRIGGER IF EXISTS trg_sync_credit_note_items_json ON public.credit_note_items;
    CREATE TRIGGER trg_sync_credit_note_items_json
    AFTER INSERT OR UPDATE OR DELETE ON public.credit_note_items
    FOR EACH ROW
    EXECUTE FUNCTION public.sync_credit_note_items_json();
  END IF;
END $$;

COMMIT;
