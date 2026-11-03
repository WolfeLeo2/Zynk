-- Atomic, idempotent server-authoritative write paths for sales & payments.
-- Fixes: non-atomic multi-step writes (partial-failure corruption), payment
-- read-modify-write races, double-submit, and TOCTOU stock double-decrement.
-- The whole body of a plpgsql function runs in one transaction, so any RAISE
-- rolls back every write (sale + items + payment + stock + invoice counter).

-- ── Atomic POS sale completion ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_sale_v2(
  p_sale_id uuid,
  p_tenant_id uuid,
  p_branch_id uuid,
  p_customer_id uuid,
  p_created_by uuid,
  p_salesperson_id uuid,
  p_items jsonb,
  p_payment_method text,
  p_payment_reference text,
  p_notes text,
  p_subtotal numeric,
  p_tax_amount numeric,
  p_discount_amount numeric,
  p_grand_total numeric
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing public.sales%ROWTYPE;
  v_seq int;
  v_invoice text;
  v_now timestamptz := now();
  v_year int := extract(year from now())::int;
  v_item jsonb;
BEGIN
  -- Idempotency: a retry with the same client-generated sale_id is a no-op.
  SELECT * INTO v_existing FROM public.sales WHERE id = p_sale_id;
  IF FOUND THEN
    RETURN jsonb_build_object('idempotent', true, 'sale_id', v_existing.id,
      'invoice_number', v_existing.invoice_number, 'status', v_existing.status);
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Sale has no items';
  END IF;
  IF COALESCE(p_grand_total, 0) < 0 THEN
    RAISE EXCEPTION 'grand_total must be non-negative';
  END IF;

  v_seq := public.next_invoice_number(p_tenant_id, 'RCT', v_year);
  v_invoice := 'RCT-' || v_year || '-' || lpad(v_seq::text, 5, '0');

  INSERT INTO public.sales(
    id, tenant_id, branch_id, customer_id, invoice_number, sale_type, created_by,
    salesperson_id, subtotal, tax_amount, discount_amount, grand_total, amount_paid,
    payment_method, status, fulfillment_status, payment_status, notes,
    completed_at, created_at, updated_at)
  VALUES (
    p_sale_id, p_tenant_id, p_branch_id, p_customer_id, v_invoice, 'pos_sale', p_created_by,
    p_salesperson_id, COALESCE(p_subtotal,0), COALESCE(p_tax_amount,0), COALESCE(p_discount_amount,0),
    COALESCE(p_grand_total,0), COALESCE(p_grand_total,0),
    p_payment_method, 'completed', 'fulfilled', 'paid', p_notes,
    v_now, v_now, v_now);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF COALESCE((v_item->>'quantity')::int, 0) <= 0 THEN
      RAISE EXCEPTION 'Item quantity must be positive';
    END IF;
    INSERT INTO public.sale_items(
      id, sale_id, tenant_id, product_id, quantity, unit_price, cost_price,
      tax_amount, discount, total, product_name, created_at, updated_at)
    VALUES (
      gen_random_uuid(), p_sale_id, p_tenant_id, (v_item->>'product_id')::uuid,
      (v_item->>'quantity')::int, COALESCE((v_item->>'unit_price')::numeric,0),
      COALESCE((v_item->>'cost_price')::numeric,0), COALESCE((v_item->>'tax_amount')::numeric,0),
      COALESCE((v_item->>'discount')::numeric,0), COALESCE((v_item->>'total')::numeric,0),
      v_item->>'product_name', v_now, v_now);

    PERFORM public.decrement_stock(
      (v_item->>'product_id')::uuid, p_branch_id, (v_item->>'quantity')::int);
  END LOOP;

  INSERT INTO public.sale_payments(
    id, sale_id, tenant_id, branch_id, amount, payment_method, reference_number,
    notes, created_at, updated_at)
  VALUES (
    gen_random_uuid(), p_sale_id, p_tenant_id, p_branch_id, COALESCE(p_grand_total,0),
    p_payment_method, p_payment_reference, 'POS Sale initial payment', v_now, v_now);

  RETURN jsonb_build_object('idempotent', false, 'sale_id', p_sale_id,
    'invoice_number', v_invoice, 'status', 'completed');
END;
$$;

-- ── Atomic, race-safe, idempotent payment recording ───────────────────────────
CREATE OR REPLACE FUNCTION public.record_sale_payment_v2(
  p_payment_id uuid,
  p_sale_id uuid,
  p_tenant_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_reference_number text DEFAULT NULL,
  p_notes text DEFAULT NULL,
  p_allow_overpayment boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sale public.sales%ROWTYPE;
  v_new_paid numeric;
  v_pay_status text;
  v_fulfillment text;
  v_released boolean := false;
  v_now timestamptz := now();
  r record;
BEGIN
  -- Idempotency: a retry with the same payment id returns current state, no re-apply.
  IF EXISTS (SELECT 1 FROM public.sale_payments WHERE id = p_payment_id) THEN
    SELECT * INTO v_sale FROM public.sales WHERE id = p_sale_id;
    RETURN jsonb_build_object('idempotent', true, 'payment_status', v_sale.payment_status,
      'amount_paid', v_sale.amount_paid, 'fulfillment_status', v_sale.fulfillment_status,
      'status', v_sale.status, 'sale_id', p_sale_id);
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be positive';
  END IF;

  -- Row lock serializes concurrent payments → no lost-update on amount_paid,
  -- and the fulfilled-check + stock decrement below can't race (no TOCTOU).
  SELECT * INTO v_sale FROM public.sales
    WHERE id = p_sale_id AND tenant_id = p_tenant_id
    FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sale not found for tenant';
  END IF;

  IF v_sale.payment_status = 'paid' OR v_sale.status IN ('voided', 'rejected') THEN
    RAISE EXCEPTION 'Cannot record payment on a % / already-paid sale', v_sale.status;
  END IF;

  v_new_paid := COALESCE(v_sale.amount_paid, 0) + p_amount;

  -- Overpayment guard: reject unless the caller explicitly allows it (the client
  -- sets allow_overpayment=true only after the user confirms in a dialog). The
  -- default is lenient so callers that don't pass the flag are unaffected.
  IF v_new_paid > COALESCE(v_sale.grand_total, 0) + 0.01 AND NOT p_allow_overpayment THEN
    RAISE EXCEPTION 'OVERPAYMENT: payment of % exceeds outstanding balance of %',
      p_amount, GREATEST(COALESCE(v_sale.grand_total,0) - COALESCE(v_sale.amount_paid,0), 0);
  END IF;

  INSERT INTO public.sale_payments(
    id, sale_id, tenant_id, branch_id, amount, payment_method, reference_number,
    notes, created_at, updated_at)
  VALUES (
    p_payment_id, p_sale_id, p_tenant_id, v_sale.branch_id, p_amount, p_payment_method,
    p_reference_number, p_notes, v_now, v_now);

  v_pay_status := CASE WHEN v_new_paid >= COALESCE(v_sale.grand_total, 0)
                       THEN 'paid' ELSE 'partially_paid' END;

  v_fulfillment := v_sale.fulfillment_status;
  IF v_sale.fulfillment_status IS DISTINCT FROM 'fulfilled' THEN
    FOR r IN SELECT product_id, quantity FROM public.sale_items WHERE sale_id = p_sale_id LOOP
      IF COALESCE(r.quantity, 0) > 0 THEN
        PERFORM public.decrement_stock(r.product_id, v_sale.branch_id, r.quantity::int);
      END IF;
    END LOOP;
    v_fulfillment := 'fulfilled';
    v_released := true;
  END IF;

  UPDATE public.sales SET
    amount_paid = v_new_paid,
    payment_status = v_pay_status,
    fulfillment_status = v_fulfillment,
    payment_method = p_payment_method,
    completed_at = CASE WHEN v_pay_status = 'paid' AND v_fulfillment = 'fulfilled'
                        THEN v_now ELSE completed_at END,
    updated_at = v_now
  WHERE id = p_sale_id;

  RETURN jsonb_build_object('idempotent', false, 'payment_status', v_pay_status,
    'amount_paid', v_new_paid, 'fulfillment_status', v_fulfillment,
    'status', v_sale.status, 'sale_id', p_sale_id, 'released', v_released);
END;
$$;

-- Only the service role (Edge Functions) may invoke these; not signed-in clients.
REVOKE EXECUTE ON FUNCTION public.complete_sale_v2(uuid,uuid,uuid,uuid,uuid,uuid,jsonb,text,text,text,numeric,numeric,numeric,numeric) FROM public, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_sale_payment_v2(uuid,uuid,uuid,numeric,text,text,text,boolean) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_sale_v2(uuid,uuid,uuid,uuid,uuid,uuid,jsonb,text,text,text,numeric,numeric,numeric,numeric) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_sale_payment_v2(uuid,uuid,uuid,numeric,text,text,text,boolean) TO service_role;
