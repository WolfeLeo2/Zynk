-- Invoice edits (manage-sale → update_draft) use the server totals rules from
-- 20261102000100 and run in one transaction. The Edge Function used to sum the
-- client's line totals, and update the sale, delete its items and re-insert
-- them as three separate calls (a failure in between left an invoice with no
-- items); its "pending and unpaid" check also ran without a lock, so a payment
-- recorded at the same moment could land on an invoice being rewritten.

-- The edit screen doesn't send a grand total, so a NULL client total now means
-- "nothing to cross-check". complete-sale / create-invoice always pass one.
CREATE OR REPLACE FUNCTION public.compute_sale_totals(
  p_items jsonb,
  p_tax_amount numeric,
  p_discount_amount numeric,
  p_client_grand_total numeric,
  OUT subtotal numeric,
  OUT grand_total numeric
)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_item jsonb;
BEGIN
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Sale has no items';
  END IF;

  subtotal := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF COALESCE((v_item->>'quantity')::numeric, 0) <= 0 THEN
      RAISE EXCEPTION 'Item quantity must be positive';
    END IF;
    IF COALESCE((v_item->>'unit_price')::numeric, 0) < 0 THEN
      RAISE EXCEPTION 'Item unit_price must be non-negative';
    END IF;
    subtotal := subtotal + public.sale_line_total(v_item);
  END LOOP;

  grand_total := subtotal + COALESCE(p_tax_amount, 0) - COALESCE(p_discount_amount, 0);
  IF grand_total < 0 THEN
    RAISE EXCEPTION 'grand_total must be non-negative';
  END IF;
  IF p_client_grand_total IS NOT NULL
     AND abs(grand_total - p_client_grand_total) > 0.01 + 0.005 * jsonb_array_length(p_items) THEN
    RAISE EXCEPTION 'TOTAL_MISMATCH: client total % does not match server total %',
      p_client_grand_total, grand_total;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.update_invoice_draft_v2(
  p_sale_id uuid, p_tenant_id uuid, p_customer_id uuid, p_salesperson_id uuid,
  p_items jsonb, p_notes text, p_due_date timestamptz
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale public.sales%ROWTYPE;
  v_totals record;
  v_item jsonb;
  v_now timestamptz := now();
BEGIN
  -- The row lock makes the checks below hold until commit: record_sale_payment_v2
  -- locks the same row, so a payment waits for (or is waited on by) this edit.
  SELECT * INTO v_sale FROM public.sales
    WHERE id = p_sale_id AND tenant_id = p_tenant_id
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sale not found';
  END IF;
  IF v_sale.status IS DISTINCT FROM 'pending_approval' THEN
    RAISE EXCEPTION 'Only pending approval invoices can be edited';
  END IF;
  IF COALESCE(v_sale.amount_paid, 0) > 0 THEN
    RAISE EXCEPTION 'Cannot edit an invoice with recorded payments';
  END IF;

  -- Lines set to quantity 0 in the editor are removals, as before.
  SELECT COALESCE(jsonb_agg(i), '[]'::jsonb) INTO p_items
    FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb)) i
    WHERE COALESCE((i->>'quantity')::numeric, 0) > 0;
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Invoice must have at least one item';
  END IF;

  -- Order-level tax/discount are the invoice's own, not editable here.
  v_totals := public.compute_sale_totals(p_items, v_sale.tax_amount, v_sale.discount_amount, NULL);

  UPDATE public.sales SET
    customer_id = p_customer_id,
    salesperson_id = p_salesperson_id,
    subtotal = v_totals.subtotal,
    total_amount = v_totals.grand_total,
    grand_total = v_totals.grand_total,
    notes = p_notes,
    due_date = p_due_date,
    updated_at = v_now
  WHERE id = p_sale_id;

  DELETE FROM public.sale_items WHERE sale_id = p_sale_id;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.sale_items(
      id, sale_id, tenant_id, product_id, quantity, unit_price, cost_price,
      tax_amount, discount, total, product_name, created_at, updated_at)
    VALUES (
      COALESCE((v_item->>'id')::uuid, gen_random_uuid()), p_sale_id, p_tenant_id,
      (v_item->>'product_id')::uuid, (v_item->>'quantity')::numeric,
      COALESCE((v_item->>'unit_price')::numeric,0), COALESCE((v_item->>'cost_price')::numeric,0),
      COALESCE((v_item->>'tax_amount')::numeric,0), COALESCE((v_item->>'discount')::numeric,0),
      public.sale_line_total(v_item), v_item->>'product_name', v_now, v_now);
  END LOOP;

  RETURN jsonb_build_object('sale_id', p_sale_id, 'status', v_sale.status,
    'subtotal', v_totals.subtotal, 'grand_total', v_totals.grand_total);
END;
$$;

REVOKE ALL ON FUNCTION public.update_invoice_draft_v2(uuid, uuid, uuid, uuid, jsonb, text, timestamptz) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_invoice_draft_v2(uuid, uuid, uuid, uuid, jsonb, text, timestamptz) TO service_role;
