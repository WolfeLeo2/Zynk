-- Tests for 20261103000000_atomic_invoice_edit.sql. Run: supabase/tests/run_local.sh
\set ON_ERROR_STOP 1
BEGIN;

INSERT INTO public.tenants (id, name) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'Test A'),
  ('00000000-0000-0000-0000-0000000000a2', 'Test B');
INSERT INTO public.branches (id, tenant_id, name) VALUES
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'A main');
INSERT INTO public.products (id, tenant_id, name) VALUES
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Tile'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000a1', 'Grout');
-- Paying an invoice releases its stock.
INSERT INTO public.stock (tenant_id, branch_id, product_id, quantity) VALUES
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', 10),
  ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c2', 10);

DO $$
DECLARE r jsonb; v_caught text; v_inv uuid := '00000000-0000-0000-0000-000000000201';
BEGIN
  r := create_invoice_v2(v_inv, '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
        NULL, NULL, NULL,
        jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 1, 'unit_price', 100)),
        NULL, NULL, 0, 0, 100);

  -- Edit: the client's line totals (999) are ignored; zero-quantity lines are
  -- removals; fractional lines are rounded like everywhere else.
  r := update_invoice_draft_v2(v_inv, '00000000-0000-0000-0000-0000000000a1', NULL, NULL,
        jsonb_build_array(
          jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 0.5, 'unit_price', 33.33, 'total', 999),
          jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c2', 'quantity', 2, 'unit_price', 10, 'discount', 1, 'total', 999),
          jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 0, 'unit_price', 50)),
        'edited', NULL);
  ASSERT (r->>'grand_total')::numeric = 35.67, r::text;            -- 16.67 + 19.00
  ASSERT (SELECT grand_total FROM sales WHERE id = v_inv) = 35.67, 'stored total';
  ASSERT (SELECT subtotal FROM sales WHERE id = v_inv) = 35.67;
  ASSERT (SELECT sum(total) FROM sale_items WHERE sale_id = v_inv) = 35.67, 'lines add up to total';
  ASSERT (SELECT count(*) FROM sale_items WHERE sale_id = v_inv) = 2, 'zero-quantity line removed';
  ASSERT (SELECT notes FROM sales WHERE id = v_inv) = 'edited';

  -- Another tenant can't edit it, even with the right sale id.
  BEGIN
    PERFORM update_invoice_draft_v2(v_inv, '00000000-0000-0000-0000-0000000000a2', NULL, NULL,
      jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 1, 'unit_price', 1)), NULL, NULL);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught = 'Sale not found', 'cross-tenant edit, got: ' || coalesce(v_caught, 'none');

  -- All lines removed → refused, invoice unchanged.
  v_caught := NULL;
  BEGIN
    PERFORM update_invoice_draft_v2(v_inv, '00000000-0000-0000-0000-0000000000a1', NULL, NULL,
      jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 0)), NULL, NULL);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught = 'Invoice must have at least one item', coalesce(v_caught, 'none');
  ASSERT (SELECT count(*) FROM sale_items WHERE sale_id = v_inv) = 2, 'failed edit must not drop items';

  -- A bad line rolls the whole edit back (no half-replaced items).
  v_caught := NULL;
  BEGIN
    PERFORM update_invoice_draft_v2(v_inv, '00000000-0000-0000-0000-0000000000a1', NULL, NULL,
      jsonb_build_array(
        jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 1, 'unit_price', 5),
        jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c2', 'quantity', 1, 'unit_price', -5)), NULL, NULL);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught LIKE '%unit_price must be non-negative%', coalesce(v_caught, 'none');
  ASSERT (SELECT grand_total FROM sales WHERE id = v_inv) = 35.67, 'failed edit changed the total';

  -- Once paid, it can't be edited.
  PERFORM record_sale_payment_v2(gen_random_uuid(), v_inv, '00000000-0000-0000-0000-0000000000a1', 10, 'cash');
  v_caught := NULL;
  BEGIN
    PERFORM update_invoice_draft_v2(v_inv, '00000000-0000-0000-0000-0000000000a1', NULL, NULL,
      jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 1, 'unit_price', 1)), NULL, NULL);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught = 'Cannot edit an invoice with recorded payments', coalesce(v_caught, 'none');

  ASSERT NOT has_function_privilege('authenticated', 'public.update_invoice_draft_v2(uuid,uuid,uuid,uuid,jsonb,text,timestamptz)', 'EXECUTE');
END $$;

SELECT 'ALL INVOICE EDIT TESTS PASSED' AS result;
ROLLBACK;
