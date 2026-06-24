-- Re-runnable self-test for complete_sale_v2 / record_sale_payment_v2.
-- Safe against production: every write is rolled back by the final RAISE.
-- Run with:  supabase db execute --file supabase/tests/atomic_rpcs_test.sql
-- (or paste into the SQL editor). It RAISEs 'TEST RESULTS >>> ...' on success;
-- read the asserted values in the message — all "(exp ...)" must match.
DO $$
DECLARE
  v_tenant uuid; v_branch uuid; v_prod uuid; v_stock0 int;
  v_sale uuid := gen_random_uuid(); v_sale2 uuid := gen_random_uuid();
  v_pay1 uuid := gen_random_uuid(); v_pay2 uuid := gen_random_uuid(); v_pay3 uuid := gen_random_uuid();
  r jsonb; v_stock1 int; v_items int; v_pays int; v_paid numeric; v_log text := ''; v_caught text;
BEGIN
  SELECT s.tenant_id, s.branch_id, s.product_id, s.quantity
    INTO v_tenant, v_branch, v_prod, v_stock0
    FROM public.stock s WHERE s.quantity > 5 LIMIT 1;

  -- complete_sale_v2: atomic insert + idempotent retry (no double decrement)
  r := public.complete_sale_v2(v_sale, v_tenant, v_branch, NULL, NULL, NULL,
        jsonb_build_array(jsonb_build_object('product_id', v_prod,'quantity',2,'unit_price',50,'total',100,'product_name','T')),
        'cash', NULL, 'test', 100, 0, 0, 100);
  SELECT count(*) INTO v_items FROM public.sale_items WHERE sale_id=v_sale;
  SELECT count(*) INTO v_pays FROM public.sale_payments WHERE sale_id=v_sale;
  SELECT quantity INTO v_stock1 FROM public.stock WHERE product_id=v_prod AND branch_id=v_branch;
  v_log := v_log || format('complete idem=%s items=%s pays=%s stock %s->%s(exp %s) | ',
    r->>'idempotent', v_items, v_pays, v_stock0, v_stock1, v_stock0-2);

  r := public.complete_sale_v2(v_sale, v_tenant, v_branch, NULL, NULL, NULL,
        jsonb_build_array(jsonb_build_object('product_id', v_prod,'quantity',2,'unit_price',50,'total',100,'product_name','T')),
        'cash', NULL, 'test', 100, 0, 0, 100);
  SELECT quantity INTO v_stock1 FROM public.stock WHERE product_id=v_prod AND branch_id=v_branch;
  v_log := v_log || format('retry idem=%s stockStill=%s(exp %s) | ', r->>'idempotent', v_stock1, v_stock0-2);

  -- record_sale_payment_v2: partial -> idempotent retry -> paid -> reject overpay/negative
  INSERT INTO public.sales(id,tenant_id,branch_id,invoice_number,sale_type,grand_total,amount_paid,status,fulfillment_status,payment_status,created_at,updated_at)
    VALUES (v_sale2,v_tenant,v_branch,'TST-PAY','invoice',100,0,'completed','unfulfilled','unpaid',now(),now());
  INSERT INTO public.sale_items(id,sale_id,tenant_id,product_id,quantity,unit_price,total,product_name,created_at,updated_at)
    VALUES (gen_random_uuid(),v_sale2,v_tenant,v_prod,1,100,100,'T',now(),now());

  r := public.record_sale_payment_v2(v_pay1,v_sale2,v_tenant,40,'cash');
  v_log := v_log || format('pay1 st=%s paid=%s(exp 40) ful=%s(exp fulfilled) | ', r->>'payment_status', r->>'amount_paid', r->>'fulfillment_status');
  r := public.record_sale_payment_v2(v_pay1,v_sale2,v_tenant,40,'cash');
  SELECT amount_paid INTO v_paid FROM public.sales WHERE id=v_sale2;
  v_log := v_log || format('pay1 retry idem=%s paidNow=%s(exp 40) | ', r->>'idempotent', v_paid);
  r := public.record_sale_payment_v2(v_pay2,v_sale2,v_tenant,60,'cash');
  v_log := v_log || format('pay2 st=%s(exp paid) paid=%s(exp 100) | ', r->>'payment_status', r->>'amount_paid');
  BEGIN
    r := public.record_sale_payment_v2(v_pay3,v_sale2,v_tenant,10,'cash');
    v_caught := 'NOT_REJECTED!';
  EXCEPTION WHEN OTHERS THEN v_caught := 'rejected ok'; END;
  v_log := v_log || format('pay3 on paid -> %s(exp rejected ok) | ', v_caught);
  BEGIN
    r := public.record_sale_payment_v2(gen_random_uuid(),v_sale,v_tenant,-5,'cash');
    v_log := v_log || 'neg NOT rejected! | ';
  EXCEPTION WHEN OTHERS THEN v_log := v_log || 'neg rejected ok | '; END;

  -- overpayment guard: a fresh 100-balance invoice, pay 150
  DECLARE v_ovp uuid := gen_random_uuid();
  BEGIN
    INSERT INTO public.sales(id,tenant_id,branch_id,invoice_number,sale_type,grand_total,amount_paid,status,fulfillment_status,payment_status,created_at,updated_at)
      VALUES (v_ovp,v_tenant,v_branch,'TST-OVP','invoice',100,0,'completed','unfulfilled','unpaid',now(),now());
    INSERT INTO public.sale_items(id,sale_id,tenant_id,product_id,quantity,unit_price,total,product_name,created_at,updated_at)
      VALUES (gen_random_uuid(),v_ovp,v_tenant,v_prod,1,100,100,'T',now(),now());
    BEGIN
      r := public.record_sale_payment_v2(gen_random_uuid(),v_ovp,v_tenant,150,'cash',NULL,NULL,false);
      v_log := v_log || 'overpay guard ON NOT rejected! | ';
    EXCEPTION WHEN OTHERS THEN v_log := v_log || 'overpay guard ON rejected ok | '; END;
    r := public.record_sale_payment_v2(gen_random_uuid(),v_ovp,v_tenant,150,'cash',NULL,NULL,true);
    v_log := v_log || format('overpay allow=true st=%s(exp paid) paid=%s(exp 150) | ', r->>'payment_status', r->>'amount_paid');
  END;

  RAISE EXCEPTION E'TEST RESULTS >>> %', v_log;  -- rolls back all test writes
END $$;
