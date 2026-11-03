-- Tests for 20261102000000_stock_integrity.sql and
-- 20261102000100_server_side_sale_totals.sql against the live schema.
-- Run: supabase/tests/run_local.sh   (everything is rolled back at the end)
\set ON_ERROR_STOP 1
BEGIN;

-- Two tenants, one branch each; products c1..c3 in tenant A. A signed-in user
-- (u1) in tenant A for the RLS-level checks.
INSERT INTO public.tenants (id, name) VALUES
  ('00000000-0000-0000-0000-0000000000a1', 'Test A'),
  ('00000000-0000-0000-0000-0000000000a2', 'Test B');
INSERT INTO public.branches (id, tenant_id, name) VALUES
  ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'A main'),
  ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-0000000000a2', 'B main');
INSERT INTO public.products (id, tenant_id, name) VALUES
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-0000000000a1', 'Paint'),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-0000000000a1', 'Tile'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-0000000000a1', 'Grout');
INSERT INTO public.stock (id, tenant_id, branch_id, product_id, quantity) VALUES
  ('00000000-0000-0000-0000-00000000005a', '00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', 10),
  ('00000000-0000-0000-0000-00000000005b', '00000000-0000-0000-0000-0000000000a1',
   '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c2', 1);
INSERT INTO auth.users (id, aud, role, email) VALUES
  ('00000000-0000-0000-0000-0000000000e1', 'authenticated', 'authenticated', 'u1@test.local');
INSERT INTO public.profiles (user_id, tenant_id, role) VALUES
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1', 'Owner');

-- ── Bug 1: a device (authenticated, through RLS) can't set stock.quantity ─────
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000000e1","role":"authenticated"}', true);
-- Stale whole-row upsert, exactly what PowerSync uploadData sends.
INSERT INTO public.stock (id, tenant_id, branch_id, product_id, quantity)
VALUES ('00000000-0000-0000-0000-00000000005a', '00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000c1', 0)
ON CONFLICT (id) DO UPDATE SET quantity = EXCLUDED.quantity;
UPDATE public.stock SET quantity = 999 WHERE id = '00000000-0000-0000-0000-00000000005a';
INSERT INTO public.stock (tenant_id, branch_id, product_id, quantity)     -- forged new row
VALUES ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
        '00000000-0000-0000-0000-0000000000c3', 500);
RESET ROLE;

DO $$ BEGIN
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 10,
    'device upsert/update must not change quantity';
  ASSERT (SELECT quantity FROM stock WHERE product_id = '00000000-0000-0000-0000-0000000000c3') = 0,
    'device insert must not set quantity';
  ASSERT NOT has_function_privilege('authenticated', 'public.set_stock_adjustment_approval(uuid,uuid,uuid,uuid,boolean)', 'EXECUTE');
  ASSERT NOT has_function_privilege('authenticated', 'public.create_invoice_v2(uuid,uuid,uuid,uuid,uuid,uuid,jsonb,text,timestamptz,numeric,numeric,numeric)', 'EXECUTE');
END $$;
-- Server roles still can.
UPDATE public.stock SET quantity = 10 WHERE id = '00000000-0000-0000-0000-00000000005a';
DELETE FROM public.stock WHERE product_id = '00000000-0000-0000-0000-0000000000c3';

-- ── Bug 3: approval is atomic, tenant-scoped and applied once ─────────────────
INSERT INTO public.stock_adjustments (id, tenant_id, branch_id, product_id, adjustment_type, quantity, bundle_id) VALUES
  ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-0000000000c1', 'addition', 5, '00000000-0000-0000-0000-0000000000f1'),
  ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-0000000000c3', 'addition', 0.75, '00000000-0000-0000-0000-0000000000f1');

DO $$
DECLARE v_caught text;
BEGIN
  BEGIN
    PERFORM set_stock_adjustment_approval('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000f1', NULL, NULL, true);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught LIKE 'No pending adjustments%', 'cross-tenant approve must fail, got: ' || coalesce(v_caught, 'no error');
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 10;

  ASSERT set_stock_adjustment_approval('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', NULL, NULL, true) = 2;
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 15, 'approve +5';
  ASSERT (SELECT quantity FROM stock WHERE product_id = '00000000-0000-0000-0000-0000000000c3') = 0.75, 'fractional, row created';
  ASSERT (SELECT previous_quantity FROM stock_adjustments WHERE id = '00000000-0000-0000-0000-0000000000d1') = 10;
  ASSERT (SELECT previous_quantity FROM stock_adjustments WHERE id = '00000000-0000-0000-0000-0000000000d2') = 0;

  v_caught := NULL;
  BEGIN
    PERFORM set_stock_adjustment_approval('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f1', NULL, NULL, true);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught IS NOT NULL, 'double approve must fail';
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 15, 'double approve applied twice';

  ASSERT set_stock_adjustment_approval('00000000-0000-0000-0000-0000000000a1', NULL, '00000000-0000-0000-0000-0000000000d1', NULL, false) = 1;
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 10, 'unapprove -5';
  ASSERT (SELECT status FROM stock_adjustments WHERE id = '00000000-0000-0000-0000-0000000000d1') = 'pending';
  ASSERT (SELECT status FROM stock_adjustments WHERE id = '00000000-0000-0000-0000-0000000000d2') = 'approved';
END $$;

-- A bundle where one reduction exceeds stock: nothing applies.
INSERT INTO public.stock_adjustments (id, tenant_id, branch_id, product_id, adjustment_type, quantity, bundle_id) VALUES
  ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-0000000000c1', 'addition', 3, '00000000-0000-0000-0000-0000000000f2'),
  ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000b1',
   '00000000-0000-0000-0000-0000000000c2', 'reduction', -2, '00000000-0000-0000-0000-0000000000f2');
DO $$
DECLARE v_caught text;
BEGIN
  BEGIN
    PERFORM set_stock_adjustment_approval('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000f2', NULL, NULL, true);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught LIKE 'INSUFFICIENT_STOCK%', 'expected INSUFFICIENT_STOCK, got: ' || coalesce(v_caught, 'none');
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 10, 'partial bundle leaked';
  ASSERT (SELECT count(*) FROM stock_adjustments WHERE bundle_id = '00000000-0000-0000-0000-0000000000f2' AND status = 'pending') = 2;
END $$;

-- ── Server-side totals ────────────────────────────────────────────────────────
DO $$
DECLARE r jsonb; v_caught text;
BEGIN
  -- Three lines of 0.5 × 33.33 = 16.665 → stored 16.67 each (the columns are
  -- numeric(10,2)), total 50.01. The app sends its unrounded double sum
  -- (≈49.995), 1.5 cents off over 3 lines: accepted. Client subtotal/line
  -- totals are ignored; lines, total and payment all agree.
  r := complete_sale_v2('00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000b1', NULL, NULL, NULL,
        (SELECT jsonb_agg(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1',
          'quantity', 0.5, 'unit_price', 33.33, 'total', 1, 'product_name', 'Paint')) FROM generate_series(1, 3)),
        'cash', NULL, NULL, 999, 0, 0, 49.99499999999999);
  ASSERT (SELECT grand_total FROM sales WHERE id = '00000000-0000-0000-0000-000000000101') = 50.01, 'server grand_total';
  ASSERT (SELECT subtotal FROM sales WHERE id = '00000000-0000-0000-0000-000000000101') = 50.01, 'client subtotal ignored';
  ASSERT (SELECT sum(total) FROM sale_items WHERE sale_id = '00000000-0000-0000-0000-000000000101') = 50.01, 'lines add up to total';
  ASSERT (SELECT amount FROM sale_payments WHERE sale_id = '00000000-0000-0000-0000-000000000101') = 50.01, 'payment = server total';
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 8.5, 'stock -1.5';

  -- Client claims a lower total than its items add up to: rejected, nothing written.
  BEGIN
    PERFORM complete_sale_v2('00000000-0000-0000-0000-000000000102', '00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000b1', NULL, NULL, NULL,
        jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 2, 'unit_price', 100)),
        'cash', NULL, NULL, 20, 0, 0, 20);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught LIKE 'TOTAL_MISMATCH%', 'expected TOTAL_MISMATCH, got: ' || coalesce(v_caught, 'none');
  ASSERT NOT EXISTS (SELECT 1 FROM sales WHERE id = '00000000-0000-0000-0000-000000000102');
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 8.5, 'rejected sale moved stock';

  -- Order-level tax and discount still apply on top of the lines.
  r := complete_sale_v2('00000000-0000-0000-0000-000000000103', '00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000b1', NULL, NULL, NULL,
        jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 1, 'unit_price', 100)),
        'cash', NULL, NULL, 100, 16, 10, 106);
  ASSERT (SELECT grand_total FROM sales WHERE id = '00000000-0000-0000-0000-000000000103') = 106;

  -- Selling into another tenant's branch is refused.
  v_caught := NULL;
  BEGIN
    PERFORM complete_sale_v2('00000000-0000-0000-0000-000000000104', '00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000b2', NULL, NULL, NULL,
        jsonb_build_array(jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 1, 'unit_price', 1)),
        'cash', NULL, NULL, 1, 0, 0, 1);
  EXCEPTION WHEN OTHERS THEN v_caught := SQLERRM; END;
  ASSERT v_caught LIKE 'Branch % does not belong to tenant%', 'cross-tenant branch, got: ' || coalesce(v_caught, 'none');

  -- Invoice: same totals, pending approval, no stock movement, idempotent.
  r := create_invoice_v2('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000b1', NULL, NULL, NULL,
        jsonb_build_array(
          jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c1', 'quantity', 2.5, 'unit_price', 40, 'product_name', 'Paint'),
          jsonb_build_object('product_id', '00000000-0000-0000-0000-0000000000c2', 'quantity', 1, 'unit_price', 10, 'discount', 1)),
        'note', NULL, 0, 0, 109);
  ASSERT r->>'status' = 'pending_approval' AND r->>'invoice_number' LIKE 'INV-%', r::text;
  ASSERT (SELECT grand_total FROM sales WHERE id = '00000000-0000-0000-0000-000000000201') = 109;
  ASSERT (SELECT product_name FROM sale_items WHERE sale_id = '00000000-0000-0000-0000-000000000201'
          AND product_id = '00000000-0000-0000-0000-0000000000c1') = 'Paint', 'product_name kept';
  ASSERT (SELECT quantity FROM stock WHERE id = '00000000-0000-0000-0000-00000000005a') = 7.5, 'invoice moved stock';
  r := create_invoice_v2('00000000-0000-0000-0000-000000000201', '00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000b1', NULL, NULL, NULL, '[]'::jsonb, NULL, NULL, 0, 0, 0);
  ASSERT (r->>'idempotent')::boolean, 'retry must be a no-op';
  ASSERT (SELECT count(*) FROM sale_items WHERE sale_id = '00000000-0000-0000-0000-000000000201') = 2;
END $$;

SELECT 'ALL TESTS PASSED' AS result;
ROLLBACK;
