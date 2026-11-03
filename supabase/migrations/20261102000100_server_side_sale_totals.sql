-- Sale totals are computed by the server, not trusted from the client.
-- complete_sale_v2 and create-invoice used to store whatever subtotal /
-- grand_total the device sent, so a modified or buggy client could record (and
-- for POS, take payment for) a total that doesn't match its own line items.
--
-- Rules (identical for POS sales and invoices):
--   line total  = round(quantity * unit_price - discount + tax_amount, 2)
--   subtotal    = sum(line totals)
--   grand total = subtotal + order tax_amount - order discount_amount
-- Per-line rounding matches storage: sale_items.total and sale_payments.amount
-- are numeric(10,2), so live already rounded each line on insert while
-- grand_total kept the client's unrounded sum, and the lines didn't add up to
-- the total. Now lines, total and payment agree.
-- The client's grand_total is only a cross-check. The app sums unrounded
-- doubles, so it can differ by up to half a cent per line; anything beyond that
-- (+0.01) is TOTAL_MISMATCH, so a cashier never takes payment for a materially
-- different figure than the one on screen. Unit prices still come from the
-- client (price overrides are a product feature); quantities must be positive.
--
-- Also: both functions check the branch belongs to the tenant, and invoice
-- creation becomes one transaction (it was sale insert, then items, then a
-- manual delete on failure).

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
  IF abs(grand_total - COALESCE(p_client_grand_total, 0)) > 0.01 + 0.005 * jsonb_array_length(p_items) THEN
    RAISE EXCEPTION 'TOTAL_MISMATCH: client total % does not match server total %',
      p_client_grand_total, grand_total;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.sale_line_total(p_item jsonb)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT round(
    COALESCE((p_item->>'quantity')::numeric, 0) * COALESCE((p_item->>'unit_price')::numeric, 0)
    - COALESCE((p_item->>'discount')::numeric, 0)
    + COALESCE((p_item->>'tax_amount')::numeric, 0), 2);
$$;

-- ── POS sale: live body, with server totals + branch check ────────────────────
-- Signature unchanged so the deployed complete-sale function keeps working;
-- p_subtotal is now ignored.
CREATE OR REPLACE FUNCTION public.complete_sale_v2(
  p_sale_id uuid, p_tenant_id uuid, p_branch_id uuid, p_customer_id uuid,
  p_created_by uuid, p_salesperson_id uuid, p_items jsonb, p_payment_method text,
  p_payment_reference text, p_notes text, p_subtotal numeric, p_tax_amount numeric,
  p_discount_amount numeric, p_grand_total numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing public.sales%ROWTYPE;
  v_seq int; v_invoice text;
  v_now timestamptz := now();
  v_year int := extract(year from now())::int;
  v_item jsonb;
  v_totals record;
BEGIN
  SELECT * INTO v_existing FROM public.sales WHERE id = p_sale_id;
  IF FOUND THEN
    RETURN jsonb_build_object('idempotent', true, 'sale_id', v_existing.id,
      'invoice_number', v_existing.invoice_number, 'status', v_existing.status);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.branches WHERE id = p_branch_id AND tenant_id = p_tenant_id) THEN
    RAISE EXCEPTION 'Branch % does not belong to tenant %', p_branch_id, p_tenant_id;
  END IF;

  v_totals := public.compute_sale_totals(p_items, p_tax_amount, p_discount_amount, p_grand_total);

  v_seq := public.next_invoice_number(p_tenant_id, 'RCT', v_year);
  v_invoice := 'RCT-' || v_year || '-' || lpad(v_seq::text, 5, '0');

  INSERT INTO public.sales(
    id, tenant_id, branch_id, customer_id, invoice_number, sale_type, created_by,
    salesperson_id, subtotal, tax_amount, discount_amount, grand_total, amount_paid,
    payment_method, status, fulfillment_status, payment_status, notes,
    completed_at, created_at, updated_at)
  VALUES (
    p_sale_id, p_tenant_id, p_branch_id, p_customer_id, v_invoice, 'pos_sale', p_created_by,
    p_salesperson_id, v_totals.subtotal, COALESCE(p_tax_amount,0), COALESCE(p_discount_amount,0),
    v_totals.grand_total, v_totals.grand_total,
    p_payment_method, 'completed', 'fulfilled', 'paid', p_notes, v_now, v_now, v_now);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.sale_items(
      id, sale_id, tenant_id, product_id, quantity, unit_price, cost_price,
      tax_amount, discount, total, product_name, created_at, updated_at)
    VALUES (
      gen_random_uuid(), p_sale_id, p_tenant_id, (v_item->>'product_id')::uuid,
      (v_item->>'quantity')::numeric, COALESCE((v_item->>'unit_price')::numeric,0),
      COALESCE((v_item->>'cost_price')::numeric,0), COALESCE((v_item->>'tax_amount')::numeric,0),
      COALESCE((v_item->>'discount')::numeric,0), public.sale_line_total(v_item),
      v_item->>'product_name', v_now, v_now);
    PERFORM public.decrement_stock((v_item->>'product_id')::uuid, p_branch_id, (v_item->>'quantity')::numeric);
  END LOOP;

  INSERT INTO public.sale_payments(
    id, sale_id, tenant_id, branch_id, amount, payment_method, reference_number, notes,
    recorded_by, created_at, updated_at)
  VALUES (
    gen_random_uuid(), p_sale_id, p_tenant_id, p_branch_id, v_totals.grand_total,
    p_payment_method, p_payment_reference, 'POS Sale initial payment', p_created_by, v_now, v_now);

  PERFORM public.recalculate_sale_commissions(p_sale_id);

  RETURN jsonb_build_object('idempotent', false, 'sale_id', p_sale_id,
    'invoice_number', v_invoice, 'status', 'completed');
END;
$$;

-- ── Invoice (pending approval, no payment, no stock movement) ─────────────────
-- Same columns the create-invoice Edge Function used to insert, plus
-- product_name on items (it was dropped before). Idempotent on p_sale_id.
CREATE OR REPLACE FUNCTION public.create_invoice_v2(
  p_sale_id uuid, p_tenant_id uuid, p_branch_id uuid, p_customer_id uuid,
  p_created_by uuid, p_salesperson_id uuid, p_items jsonb, p_notes text,
  p_due_date timestamptz, p_tax_amount numeric, p_discount_amount numeric,
  p_grand_total numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing public.sales%ROWTYPE;
  v_seq int; v_invoice text;
  v_now timestamptz := now();
  v_year int := extract(year from now())::int;
  v_item jsonb;
  v_totals record;
BEGIN
  SELECT * INTO v_existing FROM public.sales WHERE id = p_sale_id;
  IF FOUND THEN
    RETURN jsonb_build_object('idempotent', true, 'sale_id', v_existing.id,
      'invoice_number', v_existing.invoice_number, 'status', v_existing.status);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.branches WHERE id = p_branch_id AND tenant_id = p_tenant_id) THEN
    RAISE EXCEPTION 'Branch % does not belong to tenant %', p_branch_id, p_tenant_id;
  END IF;

  v_totals := public.compute_sale_totals(p_items, p_tax_amount, p_discount_amount, p_grand_total);

  v_seq := public.next_invoice_number(p_tenant_id, 'INV', v_year);
  v_invoice := 'INV-' || v_year || '-' || lpad(v_seq::text, 5, '0');

  INSERT INTO public.sales(
    id, tenant_id, branch_id, customer_id, invoice_number, sale_type, created_by,
    salesperson_id, subtotal, tax_amount, discount_amount, grand_total, amount_paid,
    status, notes, due_date, created_at, updated_at)
  VALUES (
    p_sale_id, p_tenant_id, p_branch_id, p_customer_id, v_invoice, 'invoice', p_created_by,
    p_salesperson_id, v_totals.subtotal, COALESCE(p_tax_amount,0), COALESCE(p_discount_amount,0),
    v_totals.grand_total, 0, 'pending_approval', p_notes, p_due_date, v_now, v_now);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    INSERT INTO public.sale_items(
      id, sale_id, tenant_id, product_id, quantity, unit_price, cost_price,
      tax_amount, discount, total, product_name, created_at, updated_at)
    VALUES (
      gen_random_uuid(), p_sale_id, p_tenant_id, (v_item->>'product_id')::uuid,
      (v_item->>'quantity')::numeric, COALESCE((v_item->>'unit_price')::numeric,0),
      COALESCE((v_item->>'cost_price')::numeric,0), COALESCE((v_item->>'tax_amount')::numeric,0),
      COALESCE((v_item->>'discount')::numeric,0), public.sale_line_total(v_item),
      v_item->>'product_name', v_now, v_now);
  END LOOP;

  RETURN jsonb_build_object('idempotent', false, 'sale_id', p_sale_id,
    'invoice_number', v_invoice, 'status', 'pending_approval');
END;
$$;

REVOKE ALL ON FUNCTION public.create_invoice_v2(uuid, uuid, uuid, uuid, uuid, uuid, jsonb, text, timestamptz, numeric, numeric, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_invoice_v2(uuid, uuid, uuid, uuid, uuid, uuid, jsonb, text, timestamptz, numeric, numeric, numeric) TO service_role;
