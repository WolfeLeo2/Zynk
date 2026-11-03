-- Baseline: schema of the live project (kfqionlpnjetpmuzsvfb) as of 2026-11-02,
-- dumped with `supabase db dump`. The live migration history (applied via the
-- dashboard) never matched the files now in supabase/migrations_legacy/.




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "backup_20260419";


ALTER SCHEMA "backup_20260419" OWNER TO "postgres";


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."complete_sale_v2"("p_sale_id" "uuid", "p_tenant_id" "uuid", "p_branch_id" "uuid", "p_customer_id" "uuid", "p_created_by" "uuid", "p_salesperson_id" "uuid", "p_items" "jsonb", "p_payment_method" "text", "p_payment_reference" "text", "p_notes" "text", "p_subtotal" numeric, "p_tax_amount" numeric, "p_discount_amount" numeric, "p_grand_total" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_existing public.sales%ROWTYPE;
  v_seq int; v_invoice text;
  v_now timestamptz := now();
  v_year int := extract(year from now())::int;
  v_item jsonb;
BEGIN
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
    p_payment_method, 'completed', 'fulfilled', 'paid', p_notes, v_now, v_now, v_now);

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    IF COALESCE((v_item->>'quantity')::numeric, 0) <= 0 THEN
      RAISE EXCEPTION 'Item quantity must be positive';
    END IF;
    INSERT INTO public.sale_items(
      id, sale_id, tenant_id, product_id, quantity, unit_price, cost_price,
      tax_amount, discount, total, product_name, created_at, updated_at)
    VALUES (
      gen_random_uuid(), p_sale_id, p_tenant_id, (v_item->>'product_id')::uuid,
      (v_item->>'quantity')::numeric, COALESCE((v_item->>'unit_price')::numeric,0),
      COALESCE((v_item->>'cost_price')::numeric,0), COALESCE((v_item->>'tax_amount')::numeric,0),
      COALESCE((v_item->>'discount')::numeric,0), COALESCE((v_item->>'total')::numeric,0),
      v_item->>'product_name', v_now, v_now);
    PERFORM public.decrement_stock((v_item->>'product_id')::uuid, p_branch_id, (v_item->>'quantity')::numeric);
  END LOOP;

  INSERT INTO public.sale_payments(
    id, sale_id, tenant_id, branch_id, amount, payment_method, reference_number, notes,
    recorded_by, created_at, updated_at)
  VALUES (
    gen_random_uuid(), p_sale_id, p_tenant_id, p_branch_id, COALESCE(p_grand_total,0),
    p_payment_method, p_payment_reference, 'POS Sale initial payment', p_created_by, v_now, v_now);

  PERFORM public.recalculate_sale_commissions(p_sale_id);

  RETURN jsonb_build_object('idempotent', false, 'sale_id', p_sale_id,
    'invoice_number', v_invoice, 'status', 'completed');
END;
$$;


ALTER FUNCTION "public"."complete_sale_v2"("p_sale_id" "uuid", "p_tenant_id" "uuid", "p_branch_id" "uuid", "p_customer_id" "uuid", "p_created_by" "uuid", "p_salesperson_id" "uuid", "p_items" "jsonb", "p_payment_method" "text", "p_payment_reference" "text", "p_notes" "text", "p_subtotal" numeric, "p_tax_amount" numeric, "p_discount_amount" numeric, "p_grand_total" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_tenant_id"() RETURNS "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT p.tenant_id
  FROM public.profiles p
  WHERE p.user_id = (SELECT auth.uid())
  LIMIT 1;
$$;


ALTER FUNCTION "public"."current_tenant_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."decrement_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_current numeric;
BEGIN
  SELECT quantity INTO v_current
  FROM public.stock
  WHERE product_id = p_product_id AND branch_id = p_branch_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'NO_STOCK_RECORD: product % is not stocked in branch %', p_product_id, p_branch_id;
  END IF;

  IF v_current - p_quantity < 0 THEN
    RAISE EXCEPTION 'INSUFFICIENT_STOCK: product % has % in stock in branch %, requested %', p_product_id, v_current, p_branch_id, p_quantity;
  END IF;

  UPDATE public.stock
  SET quantity = quantity - p_quantity,
      last_updated = NOW()
  WHERE product_id = p_product_id AND branch_id = p_branch_id;
END;
$$;


ALTER FUNCTION "public"."decrement_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_credit_note_number"("p_tenant_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  next_num INTEGER;
BEGIN
  SELECT COALESCE(MAX(
    CASE WHEN credit_number ~ '^\d+$' THEN credit_number::INTEGER ELSE 0 END
  ), 0) + 1
  INTO next_num
  FROM public.credit_notes
  WHERE tenant_id = p_tenant_id AND credit_number IS NOT NULL;
  
  RETURN 'CN-' || LPAD(next_num::TEXT, 6, '0');
END;
$_$;


ALTER FUNCTION "public"."generate_credit_note_number"("p_tenant_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_invoice_number"("p_tenant_id" "uuid") RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
DECLARE
  next_num INTEGER;
BEGIN
  SELECT COALESCE(MAX(
    CASE WHEN invoice_number ~ '^\d+$' THEN invoice_number::INTEGER ELSE 0 END
  ), 0) + 1
  INTO next_num
  FROM public.sales
  WHERE tenant_id = p_tenant_id AND invoice_number IS NOT NULL;
  
  RETURN 'INV-' || LPAD(next_num::TEXT, 6, '0');
END;
$_$;


ALTER FUNCTION "public"."generate_invoice_number"("p_tenant_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."handle_new_user"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  new_tenant_id UUID;
  is_owner BOOLEAN;
  shop_name TEXT;
  display_name TEXT;
  biz_address TEXT;
  biz_phone TEXT;
  biz_logo_url TEXT;
BEGIN
  -- Extract metadata
  is_owner := (new.raw_user_meta_data->>'is_owner')::BOOLEAN;
  shop_name := new.raw_user_meta_data->>'shop_name';
  display_name := new.raw_user_meta_data->>'display_name';
  biz_address := new.raw_user_meta_data->>'business_address';
  biz_phone := new.raw_user_meta_data->>'business_phone';
  biz_logo_url := new.raw_user_meta_data->>'logo_url';

  -- OPTION A: Owner Signing Up
  IF is_owner IS TRUE AND shop_name IS NOT NULL THEN
    -- 1. Create a new Tenant with business info (using new.email for email)
    INSERT INTO public.tenants (name, plan_type, address, phone, email, logo_url)
    VALUES (shop_name, 'Basic', biz_address, biz_phone, new.email, biz_logo_url)
    RETURNING id INTO new_tenant_id;

    -- 2. Create the "Main Branch" inheriting the contact details
    INSERT INTO public.branches (tenant_id, name, address, phone)
    VALUES (new_tenant_id, 'Main Branch', biz_address, biz_phone);

    -- 3. Create Profile linked to this Tenant
    INSERT INTO public.profiles (user_id, tenant_id, role, display_name)
    VALUES (new.id, new_tenant_id, 'Owner', display_name);

    -- 4. Update User App Metadata with Tenant ID so it appears in JWT (must use UPDATE in AFTER trigger)
    UPDATE auth.users
    SET raw_app_meta_data = COALESCE(raw_app_meta_data, '{}'::jsonb) || 
      jsonb_build_object('tenant_id', new_tenant_id, 'role', 'Owner')
    WHERE id = new.id;

  END IF;

  RETURN new;
END;
$$;


ALTER FUNCTION "public"."handle_new_user"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."increment_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id uuid;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM public.products WHERE id = p_product_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'NO_SUCH_PRODUCT: product % does not exist', p_product_id;
  END IF;

  -- ON CONFLICT against stock_branch_id_product_id_key makes this race-safe:
  -- two concurrent arrivals both land, one inserting and one adding.
  INSERT INTO public.stock (tenant_id, branch_id, product_id, quantity, last_updated)
  VALUES (v_tenant_id, p_branch_id, p_product_id, p_quantity, NOW())
  ON CONFLICT (branch_id, product_id) DO UPDATE
    SET quantity = public.stock.quantity + EXCLUDED.quantity,
        last_updated = NOW();
END;
$$;


ALTER FUNCTION "public"."increment_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."next_invoice_number"("p_tenant_id" "uuid", "p_prefix" "text" DEFAULT 'INV'::"text", "p_year" integer DEFAULT (EXTRACT(year FROM "now"()))::integer) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_seq INT;
BEGIN
  INSERT INTO public.tenant_invoice_counters (tenant_id, prefix, year, last_seq)
  VALUES (p_tenant_id, p_prefix, p_year, 1)
  ON CONFLICT (tenant_id, prefix, year)
  DO UPDATE SET last_seq = public.tenant_invoice_counters.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN v_seq;
END;
$$;


ALTER FUNCTION "public"."next_invoice_number"("p_tenant_id" "uuid", "p_prefix" "text", "p_year" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_sale_commissions"("p_sale_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant uuid;
  v_salesperson uuid;
  v_total numeric := 0;
BEGIN
  SELECT tenant_id, salesperson_id INTO v_tenant, v_salesperson
  FROM public.sales WHERE id = p_sale_id;

  -- Rebuild only unpaid commissions; already-paid rows are immutable history.
  DELETE FROM public.commissions WHERE sale_id = p_sale_id AND status = 'pending';

  IF v_salesperson IS NULL THEN
    RETURN;
  END IF;

  SELECT COALESCE(SUM(
    CASE COALESCE(p.commission_type, ig.default_commission_type, 'none')
      WHEN 'fixed' THEN COALESCE(p.commission_value, ig.default_commission_value, 0) * COALESCE(si.quantity, 0)
      WHEN 'percentage' THEN (COALESCE(si.total, 0) / 100.0) * COALESCE(p.commission_value, ig.default_commission_value, 0)
      ELSE 0
    END
  ), 0)
  INTO v_total
  FROM public.sale_items si
  JOIN public.products p ON p.id = si.product_id
  LEFT JOIN public.item_groups ig ON ig.id = p.item_group_id
  WHERE si.sale_id = p_sale_id;

  IF v_total > 0 THEN
    INSERT INTO public.commissions (tenant_id, salesperson_id, sale_id, amount, status)
    VALUES (v_tenant, v_salesperson, p_sale_id, v_total, 'pending');
  END IF;
END;
$$;


ALTER FUNCTION "public"."recalculate_sale_commissions"("p_sale_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_sale_payment_v2"("p_payment_id" "uuid", "p_sale_id" "uuid", "p_tenant_id" "uuid", "p_amount" numeric, "p_payment_method" "text", "p_reference_number" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text", "p_allow_overpayment" boolean DEFAULT true, "p_recorded_by" "uuid" DEFAULT NULL::"uuid") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_sale public.sales%ROWTYPE;
  v_new_paid numeric; v_pay_status text; v_fulfillment text;
  v_released boolean := false; v_now timestamptz := now(); r record;
BEGIN
  IF EXISTS (SELECT 1 FROM public.sale_payments WHERE id = p_payment_id) THEN
    SELECT * INTO v_sale FROM public.sales WHERE id = p_sale_id;
    RETURN jsonb_build_object('idempotent', true, 'payment_status', v_sale.payment_status,
      'amount_paid', v_sale.amount_paid, 'fulfillment_status', v_sale.fulfillment_status,
      'status', v_sale.status, 'sale_id', p_sale_id);
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Payment amount must be positive';
  END IF;

  SELECT * INTO v_sale FROM public.sales WHERE id = p_sale_id AND tenant_id = p_tenant_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Sale not found for tenant';
  END IF;

  IF v_sale.payment_status = 'paid' OR v_sale.status IN ('voided', 'rejected') THEN
    RAISE EXCEPTION 'Cannot record payment on a % / already-paid sale', v_sale.status;
  END IF;

  v_new_paid := COALESCE(v_sale.amount_paid, 0) + p_amount;

  -- Overpayment guard: reject unless the caller explicitly allows it (the client
  -- sets allow_overpayment=true only after the user confirms in a dialog).
  IF v_new_paid > COALESCE(v_sale.grand_total, 0) + 0.01 AND NOT p_allow_overpayment THEN
    RAISE EXCEPTION 'OVERPAYMENT: payment of % exceeds outstanding balance of %',
      p_amount, GREATEST(COALESCE(v_sale.grand_total,0) - COALESCE(v_sale.amount_paid,0), 0);
  END IF;

  INSERT INTO public.sale_payments(
    id, sale_id, tenant_id, branch_id, amount, payment_method, reference_number, notes,
    recorded_by, created_at, updated_at)
  VALUES (
    p_payment_id, p_sale_id, p_tenant_id, v_sale.branch_id, p_amount, p_payment_method,
    p_reference_number, p_notes, p_recorded_by, v_now, v_now);

  v_pay_status := CASE WHEN v_new_paid >= COALESCE(v_sale.grand_total, 0) THEN 'paid' ELSE 'partially_paid' END;

  v_fulfillment := v_sale.fulfillment_status;
  IF v_sale.fulfillment_status IS DISTINCT FROM 'fulfilled' THEN
    FOR r IN SELECT product_id, quantity FROM public.sale_items WHERE sale_id = p_sale_id LOOP
      IF COALESCE(r.quantity, 0) > 0 THEN
        PERFORM public.decrement_stock(r.product_id, v_sale.branch_id, r.quantity);
      END IF;
    END LOOP;
    v_fulfillment := 'fulfilled';
    v_released := true;
  END IF;

  UPDATE public.sales SET
    amount_paid = v_new_paid, payment_status = v_pay_status, fulfillment_status = v_fulfillment,
    payment_method = p_payment_method,
    completed_at = CASE WHEN v_pay_status = 'paid' AND v_fulfillment = 'fulfilled' THEN v_now ELSE completed_at END,
    updated_at = v_now
  WHERE id = p_sale_id;

  RETURN jsonb_build_object('idempotent', false, 'payment_status', v_pay_status,
    'amount_paid', v_new_paid, 'fulfillment_status', v_fulfillment,
    'status', v_sale.status, 'sale_id', p_sale_id, 'released', v_released);
END;
$$;


ALTER FUNCTION "public"."record_sale_payment_v2"("p_payment_id" "uuid", "p_sale_id" "uuid", "p_tenant_id" "uuid", "p_amount" numeric, "p_payment_method" "text", "p_reference_number" "text", "p_notes" "text", "p_allow_overpayment" boolean, "p_recorded_by" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_daily_operational_aggregates"("p_snapshot_date" "date" DEFAULT ((("now"() AT TIME ZONE 'utc'::"text"))::"date" - 1)) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  DELETE FROM public.daily_kpi_snapshots
  WHERE snapshot_date = p_snapshot_date;

  INSERT INTO public.daily_kpi_snapshots (
    snapshot_date, tenant_id, branch_id, orders_count, gross_sales,
    payments_collected, pending_approval_count, low_stock_count,
    inventory_value, created_at, updated_at
  )
  WITH branch_scope AS (
    SELECT b.tenant_id, b.id AS branch_id
    FROM public.branches b
  ),
  sales_agg AS (
    SELECT
      s.tenant_id,
      s.branch_id,
      COUNT(*) FILTER (
        WHERE s.status NOT IN ('draft', 'voided', 'rejected', 'pending_approval')
      )::integer AS orders_count,
      COALESCE(
        SUM(
          CASE
            WHEN s.status NOT IN ('draft', 'voided', 'rejected')
            THEN s.grand_total
            ELSE 0
          END
        ),
        0
      )::numeric AS gross_sales,
      COUNT(*) FILTER (WHERE s.status = 'pending_approval')::integer AS pending_approval_count
    FROM public.sales s
    WHERE (s.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
    GROUP BY s.tenant_id, s.branch_id
  ),
  payments_agg AS (
    SELECT
      sp.tenant_id,
      sp.branch_id,
      COALESCE(SUM(sp.amount), 0)::numeric AS payments_collected
    FROM public.sale_payments sp
    WHERE (sp.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
    GROUP BY sp.tenant_id, sp.branch_id
  ),
  stock_agg AS (
    SELECT
      st.tenant_id,
      st.branch_id,
      COUNT(*) FILTER (
        WHERE st.quantity <= st.reorder_level AND st.quantity >= 0
      )::integer AS low_stock_count,
      COALESCE(
        SUM(
          CASE
            WHEN st.quantity > 0 THEN st.quantity * COALESCE(p.cost_price, 0)
            ELSE 0
          END
        ),
        0
      )::numeric AS inventory_value
    FROM public.stock st
    LEFT JOIN public.products p ON p.id = st.product_id
    GROUP BY st.tenant_id, st.branch_id
  )
  SELECT
    p_snapshot_date,
    bs.tenant_id,
    bs.branch_id,
    COALESCE(sa.orders_count, 0),
    COALESCE(sa.gross_sales, 0),
    COALESCE(pa.payments_collected, 0),
    COALESCE(sa.pending_approval_count, 0),
    COALESCE(sta.low_stock_count, 0),
    COALESCE(sta.inventory_value, 0),
    now(),
    now()
  FROM branch_scope bs
  LEFT JOIN sales_agg sa
    ON sa.tenant_id = bs.tenant_id AND sa.branch_id = bs.branch_id
  LEFT JOIN payments_agg pa
    ON pa.tenant_id = bs.tenant_id AND pa.branch_id = bs.branch_id
  LEFT JOIN stock_agg sta
    ON sta.tenant_id = bs.tenant_id AND sta.branch_id = bs.branch_id;

  DELETE FROM public.daily_payment_method_snapshots
  WHERE snapshot_date = p_snapshot_date;

  INSERT INTO public.daily_payment_method_snapshots (
    snapshot_date, tenant_id, branch_id, payment_method, txn_count,
    total_amount, created_at, updated_at
  )
  SELECT
    p_snapshot_date,
    sp.tenant_id,
    sp.branch_id,
    COALESCE(NULLIF(sp.payment_method, ''), 'unknown') AS payment_method,
    COUNT(*)::integer,
    COALESCE(SUM(sp.amount), 0)::numeric,
    now(),
    now()
  FROM public.sale_payments sp
  WHERE (sp.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
  GROUP BY sp.tenant_id, sp.branch_id, COALESCE(NULLIF(sp.payment_method, ''), 'unknown');

  DELETE FROM public.daily_product_sales_snapshots
  WHERE snapshot_date = p_snapshot_date;

  INSERT INTO public.daily_product_sales_snapshots (
    snapshot_date, tenant_id, branch_id, product_id, quantity_sold,
    revenue_total, created_at, updated_at
  )
  SELECT
    p_snapshot_date,
    s.tenant_id,
    s.branch_id,
    si.product_id,
    COALESCE(SUM(si.quantity), 0)::numeric,
    COALESCE(SUM(si.total), 0)::numeric,
    now(),
    now()
  FROM public.sale_items si
  INNER JOIN public.sales s ON s.id = si.sale_id
  WHERE (s.created_at AT TIME ZONE 'utc')::date = p_snapshot_date
    AND s.status NOT IN ('draft', 'voided', 'rejected')
  GROUP BY s.tenant_id, s.branch_id, si.product_id;
END;
$$;


ALTER FUNCTION "public"."refresh_daily_operational_aggregates"("p_snapshot_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_sale_item_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN
    SELECT tenant_id INTO NEW.tenant_id
    FROM sales
    WHERE id = NEW.sale_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_sale_item_tenant_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_credit_note_items_json"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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


ALTER FUNCTION "public"."sync_credit_note_items_json"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_kpi_expenses"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_date DATE;
    v_branch_id UUID;
    v_tenant_id UUID;
    v_total_expenses NUMERIC;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_date := OLD.expense_date::DATE;
        v_branch_id := OLD.branch_id;
        v_tenant_id := OLD.tenant_id;
    ELSE
        v_date := NEW.expense_date::DATE;
        v_branch_id := NEW.branch_id;
        v_tenant_id := NEW.tenant_id;
    END IF;

    -- Calculate total expenses for this branch and date
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses 
    FROM expenses 
    WHERE tenant_id = v_tenant_id AND branch_id = v_branch_id AND expense_date::DATE = v_date;

    -- Update or Insert snapshot
    INSERT INTO daily_kpi_snapshots (snapshot_date, tenant_id, branch_id, total_expenses, net_profit)
    VALUES (v_date, v_tenant_id, v_branch_id, v_total_expenses, -v_total_expenses)
    ON CONFLICT (snapshot_date, tenant_id, branch_id)
    DO UPDATE SET 
        total_expenses = v_total_expenses,
        net_profit = daily_kpi_snapshots.gross_sales - v_total_expenses;

    RETURN NULL;
END;
$$;


ALTER FUNCTION "public"."update_kpi_expenses"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "backup_20260419"."categories" (
    "id" "text",
    "tenant_id" "uuid",
    "name" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "synced_at" timestamp with time zone,
    "branch_id" "uuid"
);


ALTER TABLE "backup_20260419"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."commissions" (
    "id" "uuid",
    "tenant_id" "uuid",
    "salesperson_id" "uuid",
    "sale_id" "uuid",
    "amount" numeric,
    "status" character varying,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "backup_20260419"."commissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."composite_item_components" (
    "id" "uuid",
    "tenant_id" "uuid",
    "composite_product_id" "uuid",
    "component_product_id" "uuid",
    "quantity" integer
);


ALTER TABLE "backup_20260419"."composite_item_components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."credit_note_items" (
    "id" "uuid",
    "credit_note_id" "uuid",
    "product_id" "uuid",
    "product_name" "text",
    "quantity" integer,
    "unit_price" numeric(12,2),
    "tax_amount" numeric(12,2),
    "total" numeric(12,2),
    "tenant_id" "uuid",
    "created_at" timestamp with time zone
);


ALTER TABLE "backup_20260419"."credit_note_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."credit_notes" (
    "id" "uuid",
    "tenant_id" "uuid",
    "branch_id" "uuid",
    "original_sale_id" "uuid",
    "credit_number" "text",
    "status" "text",
    "reason" "text",
    "items" "jsonb",
    "subtotal" numeric,
    "tax_amount" numeric,
    "total" numeric,
    "applied_to_sale_id" "uuid",
    "created_by" "uuid",
    "approved_by" "uuid",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "restock_items" boolean
);


ALTER TABLE "backup_20260419"."credit_notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."customers" (
    "id" "uuid",
    "tenant_id" "uuid",
    "name" "text",
    "phone" "text",
    "email" "text",
    "loyalty_points" integer,
    "credit_limit" numeric(10,2),
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "branch_id" "uuid"
);


ALTER TABLE "backup_20260419"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."daily_kpi_snapshots" (
    "snapshot_date" "date",
    "tenant_id" "uuid",
    "branch_id" "uuid",
    "orders_count" integer,
    "gross_sales" numeric,
    "payments_collected" numeric,
    "pending_approval_count" integer,
    "low_stock_count" integer,
    "inventory_value" numeric,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "backup_20260419"."daily_kpi_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."daily_payment_method_snapshots" (
    "snapshot_date" "date",
    "tenant_id" "uuid",
    "branch_id" "uuid",
    "payment_method" "text",
    "txn_count" integer,
    "total_amount" numeric,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "backup_20260419"."daily_payment_method_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."daily_product_sales_snapshots" (
    "snapshot_date" "date",
    "tenant_id" "uuid",
    "branch_id" "uuid",
    "product_id" "uuid",
    "quantity_sold" bigint,
    "revenue_total" numeric,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone
);


ALTER TABLE "backup_20260419"."daily_product_sales_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."item_groups" (
    "id" "uuid",
    "tenant_id" "uuid",
    "name" "text",
    "description" "text",
    "default_commission_type" "text",
    "default_commission_value" real,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "synced_at" timestamp with time zone,
    "branch_id" "uuid",
    "attributes" "jsonb"
);


ALTER TABLE "backup_20260419"."item_groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."products" (
    "id" "uuid",
    "tenant_id" "uuid",
    "name" "text",
    "sku" "text",
    "description" "text",
    "base_price" numeric(10,2),
    "tax_category" "text",
    "is_service" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "item_group_id" "uuid",
    "commission_type" "text",
    "commission_value" real,
    "image_url" "text",
    "barcode" "text",
    "category_id" "text",
    "cost_price" real,
    "branch_id" "uuid",
    "group_id" "uuid",
    "variant_options" "jsonb",
    "product_type" "text",
    "uom_id" "uuid",
    "variant_images" "jsonb",
    "parent_id" "uuid"
);


ALTER TABLE "backup_20260419"."products" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."sale_items" (
    "id" "uuid",
    "sale_id" "uuid",
    "product_id" "uuid",
    "quantity" integer,
    "unit_price" numeric(10,2),
    "tax_amount" numeric(10,2),
    "total" numeric(10,2),
    "tenant_id" "uuid",
    "discount" numeric,
    "cost_price" numeric,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "product_name" "text"
);


ALTER TABLE "backup_20260419"."sale_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."sale_payments" (
    "id" "uuid",
    "sale_id" "uuid",
    "tenant_id" "uuid",
    "amount" numeric(10,2),
    "payment_method" "text",
    "reference_number" "text",
    "notes" "text",
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "branch_id" "uuid"
);


ALTER TABLE "backup_20260419"."sale_payments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."sales" (
    "id" "uuid",
    "tenant_id" "uuid",
    "branch_id" "uuid",
    "customer_id" "uuid",
    "total_amount" numeric(10,2),
    "payment_method" "text",
    "status" "text",
    "synced_at" timestamp with time zone,
    "external_ref" "text",
    "created_at" timestamp with time zone,
    "invoice_number" "text",
    "sale_type" "text",
    "created_by" "uuid",
    "approved_by" "uuid",
    "subtotal" numeric,
    "tax_amount" numeric,
    "discount_amount" numeric,
    "grand_total" numeric,
    "amount_paid" numeric,
    "notes" "text",
    "due_date" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "voided_at" timestamp with time zone,
    "void_reason" "text",
    "updated_at" timestamp with time zone,
    "fulfillment_status" "text",
    "salesperson_id" "uuid",
    "payment_status" "text"
);


ALTER TABLE "backup_20260419"."sales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."stock" (
    "id" "uuid",
    "tenant_id" "uuid",
    "branch_id" "uuid",
    "product_id" "uuid",
    "quantity" integer,
    "reorder_level" integer,
    "last_updated" timestamp with time zone
);


ALTER TABLE "backup_20260419"."stock" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."stock_adjustment_reasons" (
    "id" "uuid",
    "tenant_id" "uuid",
    "label" "text",
    "created_at" timestamp with time zone
);


ALTER TABLE "backup_20260419"."stock_adjustment_reasons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."stock_adjustments" (
    "id" "uuid",
    "tenant_id" "uuid",
    "branch_id" "uuid",
    "product_id" "uuid",
    "adjustment_type" "text",
    "quantity" integer,
    "reference_number" "text",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone,
    "reason_id" "uuid",
    "status" character varying
);


ALTER TABLE "backup_20260419"."stock_adjustments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "backup_20260419"."units_of_measurement" (
    "id" "uuid",
    "tenant_id" "uuid",
    "label" "text",
    "abbreviation" "text",
    "base_unit_id" "uuid",
    "conversion_factor" real,
    "created_at" timestamp with time zone
);


ALTER TABLE "backup_20260419"."units_of_measurement" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."backup_item_groups_20260519" (
    "id" "uuid",
    "tenant_id" "uuid",
    "name" "text",
    "description" "text",
    "default_commission_value" real,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "synced_at" timestamp with time zone,
    "branch_id" "uuid",
    "attributes" "jsonb",
    "default_selling_price" numeric,
    "default_buying_price" numeric,
    "default_commission_type" "text"
);


ALTER TABLE "public"."backup_item_groups_20260519" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."backup_products_20260519" (
    "id" "uuid",
    "tenant_id" "uuid",
    "name" "text",
    "sku" "text",
    "description" "text",
    "base_price" numeric(10,2),
    "tax_category" "text",
    "is_service" boolean,
    "created_at" timestamp with time zone,
    "updated_at" timestamp with time zone,
    "item_group_id" "uuid",
    "commission_value" real,
    "image_url" "text",
    "barcode" "text",
    "category_id" "text",
    "cost_price" real,
    "branch_id" "uuid",
    "uom_id" "uuid",
    "parent_id" "uuid",
    "commission_type" "text"
);


ALTER TABLE "public"."backup_products_20260519" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."branches" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "location" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "location_id" "uuid",
    "address" "text",
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "phone" "text"
);


ALTER TABLE "public"."branches" OWNER TO "postgres";


COMMENT ON COLUMN "public"."branches"."address" IS 'Physical address or location description of the branch.';



CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "text" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone,
    "branch_id" "uuid"
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."commission_calculation_types" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."commission_calculation_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."commission_statuses" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."commission_statuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."commissions" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "salesperson_id" "uuid" NOT NULL,
    "sale_id" "uuid" NOT NULL,
    "amount" numeric NOT NULL,
    "status" character varying DEFAULT 'pending'::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."commissions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."composite_item_components" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "composite_product_id" "uuid" NOT NULL,
    "component_product_id" "uuid" NOT NULL,
    "quantity" integer NOT NULL
);


ALTER TABLE "public"."composite_item_components" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."credit_note_items" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "credit_note_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "product_name" "text",
    "quantity" numeric DEFAULT 1 NOT NULL,
    "unit_price" numeric(12,2) DEFAULT 0 NOT NULL,
    "tax_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "total" numeric(12,2) DEFAULT 0 NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "credit_note_items_quantity_check" CHECK (("quantity" > (0)::numeric))
);


ALTER TABLE "public"."credit_note_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."credit_note_statuses" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."credit_note_statuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."credit_notes" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "original_sale_id" "uuid" NOT NULL,
    "credit_number" "text",
    "status" "text" DEFAULT 'draft'::"text" NOT NULL,
    "reason" "text" DEFAULT ''::"text" NOT NULL,
    "items" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "subtotal" numeric DEFAULT 0,
    "tax_amount" numeric DEFAULT 0,
    "total" numeric DEFAULT 0,
    "applied_to_sale_id" "uuid",
    "created_by" "uuid",
    "approved_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "restock_items" boolean DEFAULT false
);


ALTER TABLE "public"."credit_notes" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."customers" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "loyalty_points" integer DEFAULT 0,
    "credit_limit" numeric(10,2) DEFAULT 0.00,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "branch_id" "uuid"
);


ALTER TABLE "public"."customers" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_kpi_snapshots" (
    "snapshot_date" "date" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "orders_count" integer DEFAULT 0 NOT NULL,
    "gross_sales" numeric DEFAULT 0 NOT NULL,
    "payments_collected" numeric DEFAULT 0 NOT NULL,
    "pending_approval_count" integer DEFAULT 0 NOT NULL,
    "low_stock_count" integer DEFAULT 0 NOT NULL,
    "inventory_value" numeric DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "total_expenses" numeric DEFAULT 0,
    "net_profit" numeric DEFAULT 0
);


ALTER TABLE "public"."daily_kpi_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_payment_method_snapshots" (
    "snapshot_date" "date" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "payment_method" "text" NOT NULL,
    "txn_count" integer DEFAULT 0 NOT NULL,
    "total_amount" numeric DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."daily_payment_method_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."daily_product_sales_snapshots" (
    "snapshot_date" "date" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity_sold" numeric DEFAULT 0 NOT NULL,
    "revenue_total" numeric DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."daily_product_sales_snapshots" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expense_categories" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."expense_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expenses" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "category_id" "uuid" NOT NULL,
    "staff_member_id" "uuid",
    "amount" numeric DEFAULT 0 NOT NULL,
    "description" "text",
    "payment_method" "text",
    "expense_date" timestamp with time zone DEFAULT "now"(),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."expenses" OWNER TO "postgres";


COMMENT ON COLUMN "public"."expenses"."staff_member_id" IS 'Recorded-by staffer. New rows: profiles.id. Historic rows: staff_members.id. No FK.';



CREATE TABLE IF NOT EXISTS "public"."fulfillment_statuses" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."fulfillment_statuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."invoice_statuses" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."invoice_statuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."item_groups" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "default_commission_value" real,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone,
    "branch_id" "uuid",
    "attributes" "jsonb" DEFAULT '[]'::"jsonb",
    "default_selling_price" numeric,
    "default_buying_price" numeric,
    "default_commission_type" "text" DEFAULT 'none'::"text",
    "default_pricing_unit" "text" DEFAULT 'piece'::"text",
    "default_coverage_per_box" numeric DEFAULT 1.0,
    CONSTRAINT "chk_default_pricing_unit" CHECK (("default_pricing_unit" = ANY (ARRAY['piece'::"text", 'sqm'::"text"])))
);


ALTER TABLE "public"."item_groups" OWNER TO "postgres";


COMMENT ON COLUMN "public"."item_groups"."attributes" IS 'Ordered list of variant attribute names defined by this group, e.g. ["Color","Size"]';



COMMENT ON COLUMN "public"."item_groups"."default_pricing_unit" IS 'Default unit of measure for pricing this group: piece (flat price per box/unit) or sqm (price per square meter).';



COMMENT ON COLUMN "public"."item_groups"."default_coverage_per_box" IS 'Default coverage area per box/unit in square meters (sqm).';



CREATE TABLE IF NOT EXISTS "public"."locations" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" DEFAULT 'Region'::"text",
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "synced_at" timestamp with time zone
);


ALTER TABLE "public"."locations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_methods" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."payment_methods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payment_statuses" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."payment_statuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."pin_login_attempts" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "ip" "text" NOT NULL,
    "fail_count" integer DEFAULT 0 NOT NULL,
    "locked_until" timestamp with time zone,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."pin_login_attempts" OWNER TO "postgres";


COMMENT ON TABLE "public"."pin_login_attempts" IS 'Server-only PIN-login throttle, keyed by (tenant_id, client ip). Managed by the pin-login Edge Function.';



CREATE TABLE IF NOT EXISTS "public"."product_branches" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."product_branches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."products" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "sku" "text",
    "description" "text",
    "base_price" numeric(10,2),
    "tax_category" "text" DEFAULT 'VAT_16'::"text",
    "is_service" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "item_group_id" "uuid",
    "commission_value" real,
    "image_url" "text",
    "barcode" "text",
    "category_id" "text",
    "cost_price" real,
    "branch_id" "uuid",
    "uom_id" "uuid",
    "parent_id" "uuid",
    "commission_type" "text" DEFAULT 'none'::"text",
    "pricing_unit" "text",
    "coverage_per_box" numeric,
    CONSTRAINT "chk_pricing_unit" CHECK (("pricing_unit" = ANY (ARRAY['piece'::"text", 'sqm'::"text"])))
);


ALTER TABLE "public"."products" OWNER TO "postgres";


COMMENT ON COLUMN "public"."products"."pricing_unit" IS 'Unit of measure override for pricing this product: piece or sqm.';



COMMENT ON COLUMN "public"."products"."coverage_per_box" IS 'Coverage area override per box/unit in square meters (sqm).';



CREATE TABLE IF NOT EXISTS "public"."profile_branches" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "profile_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."profile_branches" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "role" "text" DEFAULT 'Cashier'::"text",
    "display_name" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "profile_picture_url" "text",
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "permissions" "jsonb" DEFAULT '[]'::"jsonb",
    "phone" "text",
    "address" "text",
    "status" "text" DEFAULT 'active'::"text",
    "pin_hash" "text",
    "pin_set_at" timestamp with time zone,
    "pin_lookup" "text",
    CONSTRAINT "profiles_role_check" CHECK (("role" = ANY (ARRAY['Owner'::"text", 'Manager'::"text", 'Cashier'::"text"]))),
    CONSTRAINT "profiles_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'deleted'::"text", 'blocked'::"text"])))
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


COMMENT ON COLUMN "public"."profiles"."status" IS 'Lifecycle status of the user account: active, inactive (blocked), or deleted (soft-delete).';



COMMENT ON COLUMN "public"."profiles"."pin_hash" IS 'Server-only slow-KDF hash of the staff PIN. Never synced to devices (excluded from the PowerSync client schema).';



COMMENT ON COLUMN "public"."profiles"."pin_lookup" IS 'Server-only HMAC(pepper, tenant_id|pin) — uniqueness + lookup for pin-login. Never synced to devices.';



CREATE TABLE IF NOT EXISTS "public"."sale_approvals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sale_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "approver_user_id" "uuid" NOT NULL,
    "decision" "text" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "sale_approvals_decision_check" CHECK (("decision" = ANY (ARRAY['approved'::"text", 'rejected'::"text"])))
);


ALTER TABLE "public"."sale_approvals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sale_items" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "sale_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" numeric DEFAULT 1,
    "unit_price" numeric(10,2) DEFAULT 0.00,
    "tax_amount" numeric(10,2) DEFAULT 0.00,
    "total" numeric(10,2) DEFAULT 0.00,
    "tenant_id" "uuid",
    "discount" numeric DEFAULT 0,
    "cost_price" numeric DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "product_name" "text"
);


ALTER TABLE "public"."sale_items" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sale_payments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "sale_id" "uuid" NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "amount" numeric(10,2) NOT NULL,
    "payment_method" "text" NOT NULL,
    "reference_number" "text",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "branch_id" "uuid",
    "recorded_by" "uuid"
);


ALTER TABLE "public"."sale_payments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."sale_payments"."recorded_by" IS 'auth user id of the staffer who recorded this payment (joins profiles.user_id for a display name). Distinct from sales.created_by / sales.salesperson_id.';



CREATE TABLE IF NOT EXISTS "public"."sale_types" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."sale_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "customer_id" "uuid",
    "total_amount" numeric(10,2) DEFAULT 0.00,
    "payment_method" "text",
    "status" "text" DEFAULT 'Draft'::"text",
    "synced_at" timestamp with time zone DEFAULT "now"(),
    "external_ref" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "invoice_number" "text",
    "sale_type" "text" DEFAULT 'sale'::"text" NOT NULL,
    "created_by" "uuid",
    "approved_by" "uuid",
    "subtotal" numeric DEFAULT 0,
    "tax_amount" numeric DEFAULT 0,
    "discount_amount" numeric DEFAULT 0,
    "grand_total" numeric DEFAULT 0,
    "amount_paid" numeric DEFAULT 0,
    "notes" "text",
    "due_date" timestamp with time zone,
    "completed_at" timestamp with time zone,
    "voided_at" timestamp with time zone,
    "void_reason" "text",
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "fulfillment_status" "text" DEFAULT 'unfulfilled'::"text",
    "salesperson_id" "uuid",
    "payment_status" "text" DEFAULT 'unpaid'::"text" NOT NULL,
    "required_approvals" integer DEFAULT 2 NOT NULL,
    "approval_count" integer DEFAULT 0 NOT NULL,
    CONSTRAINT "sales_payment_status_check" CHECK (("payment_status" = ANY (ARRAY['unpaid'::"text", 'partially_paid'::"text", 'paid'::"text"])))
);


ALTER TABLE "public"."sales" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."staff_members" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid",
    "name" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "profile_picture_url" "text",
    "status" "text" DEFAULT 'active'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "staff_members_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'inactive'::"text", 'blocked'::"text", 'deleted'::"text"])))
);


ALTER TABLE "public"."staff_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "quantity" numeric DEFAULT 0,
    "reorder_level" integer DEFAULT 5,
    "last_updated" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."stock" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_adjustment_reasons" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "label" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."stock_adjustment_reasons" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_adjustment_statuses" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."stock_adjustment_statuses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_adjustment_types" (
    "code" "text" NOT NULL,
    "label" "text" NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_legacy" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."stock_adjustment_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_adjustments" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "branch_id" "uuid" NOT NULL,
    "product_id" "uuid" NOT NULL,
    "adjustment_type" "text" NOT NULL,
    "quantity" numeric NOT NULL,
    "reference_number" "text",
    "notes" "text",
    "created_by" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "reason_id" "uuid",
    "status" character varying DEFAULT 'pending'::character varying,
    "bundle_id" "uuid",
    "approved_by" "uuid",
    "approved_at" timestamp with time zone,
    "rejection_reason" "text",
    "previous_quantity" numeric,
    "salesperson_id" "uuid",
    CONSTRAINT "stock_adjustments_adjustment_type_check" CHECK (("adjustment_type" = ANY (ARRAY['addition'::"text", 'reduction'::"text", 'initial'::"text", 'damage'::"text"])))
);


ALTER TABLE "public"."stock_adjustments" OWNER TO "postgres";


COMMENT ON COLUMN "public"."stock_adjustments"."bundle_id" IS 'Identifier for grouping multiple adjustments into a single batch or bundle.';



COMMENT ON COLUMN "public"."stock_adjustments"."salesperson_id" IS 'Salesperson. New rows: profiles.id (logged-in staffer). Historic rows: staff_members.id. No FK (resolve name from either table).';



CREATE TABLE IF NOT EXISTS "public"."tenant_invoice_counters" (
    "tenant_id" "uuid" NOT NULL,
    "prefix" "text" DEFAULT 'INV'::"text" NOT NULL,
    "year" integer NOT NULL,
    "last_seq" integer DEFAULT 0 NOT NULL
);


ALTER TABLE "public"."tenant_invoice_counters" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" "uuid" DEFAULT "extensions"."uuid_generate_v4"() NOT NULL,
    "name" "text" NOT NULL,
    "plan_type" "text" DEFAULT 'Basic'::"text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "address" "text",
    "phone" "text",
    "email" "text",
    "logo_url" "text",
    "updated_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"())
);


ALTER TABLE "public"."tenants" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."units_of_measurement" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" "uuid" NOT NULL,
    "label" "text" NOT NULL,
    "abbreviation" "text",
    "base_unit_id" "uuid",
    "conversion_factor" real DEFAULT 1.0,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."units_of_measurement" OWNER TO "postgres";


ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."commission_calculation_types"
    ADD CONSTRAINT "commission_calculation_types_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."commission_statuses"
    ADD CONSTRAINT "commission_statuses_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."commissions"
    ADD CONSTRAINT "commissions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."composite_item_components"
    ADD CONSTRAINT "composite_item_components_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."credit_note_items"
    ADD CONSTRAINT "credit_note_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."credit_note_statuses"
    ADD CONSTRAINT "credit_note_statuses_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."daily_kpi_snapshots"
    ADD CONSTRAINT "daily_kpi_snapshots_pkey" PRIMARY KEY ("snapshot_date", "tenant_id", "branch_id");



ALTER TABLE ONLY "public"."daily_payment_method_snapshots"
    ADD CONSTRAINT "daily_payment_method_snapshots_pkey" PRIMARY KEY ("snapshot_date", "tenant_id", "branch_id", "payment_method");



ALTER TABLE ONLY "public"."daily_product_sales_snapshots"
    ADD CONSTRAINT "daily_product_sales_snapshots_pkey" PRIMARY KEY ("snapshot_date", "tenant_id", "branch_id", "product_id");



ALTER TABLE ONLY "public"."expense_categories"
    ADD CONSTRAINT "expense_categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."fulfillment_statuses"
    ADD CONSTRAINT "fulfillment_statuses_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."invoice_statuses"
    ADD CONSTRAINT "invoice_statuses_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."item_groups"
    ADD CONSTRAINT "item_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payment_methods"
    ADD CONSTRAINT "payment_methods_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."payment_statuses"
    ADD CONSTRAINT "payment_statuses_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."pin_login_attempts"
    ADD CONSTRAINT "pin_login_attempts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pin_login_attempts"
    ADD CONSTRAINT "pin_login_attempts_tenant_ip_uniq" UNIQUE ("tenant_id", "ip");



ALTER TABLE ONLY "public"."product_branches"
    ADD CONSTRAINT "product_branches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_branches"
    ADD CONSTRAINT "product_branches_product_id_branch_id_key" UNIQUE ("product_id", "branch_id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_branches"
    ADD CONSTRAINT "profile_branches_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profile_branches"
    ADD CONSTRAINT "profile_branches_profile_id_branch_id_key" UNIQUE ("profile_id", "branch_id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sale_approvals"
    ADD CONSTRAINT "sale_approvals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sale_approvals"
    ADD CONSTRAINT "sale_approvals_sale_id_approver_user_id_key" UNIQUE ("sale_id", "approver_user_id");



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sale_payments"
    ADD CONSTRAINT "sale_payments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."sale_types"
    ADD CONSTRAINT "sale_types_pkey" PRIMARY KEY ("code");



ALTER TABLE "public"."sales"
    ADD CONSTRAINT "sales_approval_count_valid" CHECK ((("required_approvals" >= 1) AND ("approval_count" >= 0) AND ("approval_count" <= "required_approvals"))) NOT VALID;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."staff_members"
    ADD CONSTRAINT "staff_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_adjustment_reasons"
    ADD CONSTRAINT "stock_adjustment_reasons_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock_adjustment_statuses"
    ADD CONSTRAINT "stock_adjustment_statuses_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."stock_adjustment_types"
    ADD CONSTRAINT "stock_adjustment_types_pkey" PRIMARY KEY ("code");



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."stock"
    ADD CONSTRAINT "stock_branch_id_product_id_key" UNIQUE ("branch_id", "product_id");



ALTER TABLE ONLY "public"."stock"
    ADD CONSTRAINT "stock_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tenant_invoice_counters"
    ADD CONSTRAINT "tenant_invoice_counters_pkey" PRIMARY KEY ("tenant_id", "prefix", "year");



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenants_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."units_of_measurement"
    ADD CONSTRAINT "units_of_measurement_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_branches_location_id" ON "public"."branches" USING "btree" ("location_id");



CREATE INDEX "idx_branches_tenant_id" ON "public"."branches" USING "btree" ("tenant_id");



CREATE INDEX "idx_categories_branch_id" ON "public"."categories" USING "btree" ("branch_id");



CREATE INDEX "idx_categories_tenant_id" ON "public"."categories" USING "btree" ("tenant_id");



CREATE INDEX "idx_commissions_sale_id" ON "public"."commissions" USING "btree" ("sale_id");



CREATE INDEX "idx_commissions_status" ON "public"."commissions" USING "btree" ("status");



CREATE INDEX "idx_commissions_tenant_sale" ON "public"."commissions" USING "btree" ("tenant_id", "sale_id");



CREATE INDEX "idx_commissions_tenant_salesperson_status_created" ON "public"."commissions" USING "btree" ("tenant_id", "salesperson_id", "status", "created_at" DESC);



CREATE INDEX "idx_composite_item_components_component_product_id" ON "public"."composite_item_components" USING "btree" ("component_product_id");



CREATE INDEX "idx_composite_item_components_composite_product_id" ON "public"."composite_item_components" USING "btree" ("composite_product_id");



CREATE INDEX "idx_credit_note_items_note_id" ON "public"."credit_note_items" USING "btree" ("credit_note_id");



CREATE INDEX "idx_credit_note_items_product_id" ON "public"."credit_note_items" USING "btree" ("product_id");



CREATE INDEX "idx_credit_note_items_tenant_credit" ON "public"."credit_note_items" USING "btree" ("tenant_id", "credit_note_id");



CREATE INDEX "idx_credit_notes_applied_to_sale_id" ON "public"."credit_notes" USING "btree" ("applied_to_sale_id");



CREATE INDEX "idx_credit_notes_approved_by" ON "public"."credit_notes" USING "btree" ("approved_by");



CREATE INDEX "idx_credit_notes_branch_id" ON "public"."credit_notes" USING "btree" ("branch_id");



CREATE INDEX "idx_credit_notes_created_by" ON "public"."credit_notes" USING "btree" ("created_by");



CREATE INDEX "idx_credit_notes_original_sale" ON "public"."credit_notes" USING "btree" ("original_sale_id");



CREATE INDEX "idx_credit_notes_status" ON "public"."credit_notes" USING "btree" ("status");



CREATE INDEX "idx_credit_notes_tenant" ON "public"."credit_notes" USING "btree" ("tenant_id");



CREATE INDEX "idx_credit_notes_tenant_created" ON "public"."credit_notes" USING "btree" ("tenant_id", "created_at" DESC);



CREATE INDEX "idx_customers_branch_id" ON "public"."customers" USING "btree" ("branch_id");



CREATE INDEX "idx_customers_tenant_id" ON "public"."customers" USING "btree" ("tenant_id");



CREATE INDEX "idx_daily_kpi_snapshots_branch_id" ON "public"."daily_kpi_snapshots" USING "btree" ("branch_id");



CREATE INDEX "idx_daily_kpi_snapshots_tenant_date" ON "public"."daily_kpi_snapshots" USING "btree" ("tenant_id", "snapshot_date", "branch_id");



CREATE INDEX "idx_daily_payment_method_snapshots_branch_id" ON "public"."daily_payment_method_snapshots" USING "btree" ("branch_id");



CREATE INDEX "idx_daily_payment_method_snapshots_payment_method" ON "public"."daily_payment_method_snapshots" USING "btree" ("payment_method");



CREATE INDEX "idx_daily_payment_method_snapshots_tenant_date" ON "public"."daily_payment_method_snapshots" USING "btree" ("tenant_id", "snapshot_date", "branch_id");



CREATE INDEX "idx_daily_product_sales_snapshots_branch_id" ON "public"."daily_product_sales_snapshots" USING "btree" ("branch_id");



CREATE INDEX "idx_daily_product_sales_snapshots_product_id" ON "public"."daily_product_sales_snapshots" USING "btree" ("product_id");



CREATE INDEX "idx_daily_product_sales_snapshots_tenant_date" ON "public"."daily_product_sales_snapshots" USING "btree" ("tenant_id", "snapshot_date", "branch_id");



CREATE INDEX "idx_expense_categories_tenant_id" ON "public"."expense_categories" USING "btree" ("tenant_id");



CREATE INDEX "idx_expenses_branch_id" ON "public"."expenses" USING "btree" ("branch_id");



CREATE INDEX "idx_expenses_category_id" ON "public"."expenses" USING "btree" ("category_id");



CREATE INDEX "idx_expenses_payment_method" ON "public"."expenses" USING "btree" ("payment_method");



CREATE INDEX "idx_expenses_staff_member_id" ON "public"."expenses" USING "btree" ("staff_member_id");



CREATE INDEX "idx_expenses_tenant_id" ON "public"."expenses" USING "btree" ("tenant_id");



CREATE INDEX "idx_item_groups_branch_id" ON "public"."item_groups" USING "btree" ("branch_id");



CREATE INDEX "idx_item_groups_default_commission_type" ON "public"."item_groups" USING "btree" ("default_commission_type");



CREATE INDEX "idx_item_groups_tenant_id" ON "public"."item_groups" USING "btree" ("tenant_id");



CREATE INDEX "idx_locations_tenant_id" ON "public"."locations" USING "btree" ("tenant_id");



CREATE INDEX "idx_product_branches_branch_id" ON "public"."product_branches" USING "btree" ("branch_id");



CREATE INDEX "idx_product_branches_tenant_branch" ON "public"."product_branches" USING "btree" ("tenant_id", "branch_id");



CREATE INDEX "idx_product_branches_tenant_product" ON "public"."product_branches" USING "btree" ("tenant_id", "product_id");



CREATE INDEX "idx_products_branch_id" ON "public"."products" USING "btree" ("branch_id");



CREATE INDEX "idx_products_category_id" ON "public"."products" USING "btree" ("category_id");



CREATE INDEX "idx_products_commission_type" ON "public"."products" USING "btree" ("commission_type");



CREATE INDEX "idx_products_item_group_id" ON "public"."products" USING "btree" ("item_group_id");



CREATE INDEX "idx_products_parent_id" ON "public"."products" USING "btree" ("parent_id");



CREATE INDEX "idx_products_tenant_id" ON "public"."products" USING "btree" ("tenant_id");



CREATE INDEX "idx_products_uom_id" ON "public"."products" USING "btree" ("uom_id");



CREATE INDEX "idx_profiles_branch_id" ON "public"."profiles" USING "btree" ("branch_id");



CREATE INDEX "idx_profiles_tenant_id" ON "public"."profiles" USING "btree" ("tenant_id");



CREATE INDEX "idx_profiles_user_id" ON "public"."profiles" USING "btree" ("user_id");



CREATE INDEX "idx_sale_approvals_tenant_approver" ON "public"."sale_approvals" USING "btree" ("tenant_id", "approver_user_id");



CREATE INDEX "idx_sale_approvals_tenant_sale_created" ON "public"."sale_approvals" USING "btree" ("tenant_id", "sale_id", "created_at" DESC);



CREATE INDEX "idx_sale_items_product_id" ON "public"."sale_items" USING "btree" ("product_id");



CREATE INDEX "idx_sale_items_sale_id" ON "public"."sale_items" USING "btree" ("sale_id");



CREATE INDEX "idx_sale_items_tenant_sale" ON "public"."sale_items" USING "btree" ("tenant_id", "sale_id");



CREATE INDEX "idx_sale_payments_branch_id" ON "public"."sale_payments" USING "btree" ("branch_id");



CREATE INDEX "idx_sale_payments_payment_method" ON "public"."sale_payments" USING "btree" ("payment_method");



CREATE INDEX "idx_sale_payments_sale_id" ON "public"."sale_payments" USING "btree" ("sale_id");



CREATE INDEX "idx_sale_payments_tenant_branch_created" ON "public"."sale_payments" USING "btree" ("tenant_id", "branch_id", "created_at" DESC);



CREATE INDEX "idx_sale_payments_tenant_method_created" ON "public"."sale_payments" USING "btree" ("tenant_id", "payment_method", "created_at" DESC);



CREATE INDEX "idx_sale_payments_tenant_sale_created" ON "public"."sale_payments" USING "btree" ("tenant_id", "sale_id", "created_at" DESC);



CREATE INDEX "idx_sales_approved_by" ON "public"."sales" USING "btree" ("approved_by");



CREATE INDEX "idx_sales_branch" ON "public"."sales" USING "btree" ("branch_id");



CREATE INDEX "idx_sales_branch_created" ON "public"."sales" USING "btree" ("branch_id", "created_at" DESC);



CREATE INDEX "idx_sales_created_at" ON "public"."sales" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_sales_created_by" ON "public"."sales" USING "btree" ("created_by");



CREATE INDEX "idx_sales_customer_id" ON "public"."sales" USING "btree" ("customer_id");



CREATE INDEX "idx_sales_fulfillment_status" ON "public"."sales" USING "btree" ("fulfillment_status");



CREATE INDEX "idx_sales_invoice_number" ON "public"."sales" USING "btree" ("invoice_number");



CREATE INDEX "idx_sales_payment_status" ON "public"."sales" USING "btree" ("payment_status");



CREATE INDEX "idx_sales_pending_approval_created" ON "public"."sales" USING "btree" ("tenant_id", "created_at" DESC) WHERE ("status" = 'pending_approval'::"text");



CREATE INDEX "idx_sales_sale_type" ON "public"."sales" USING "btree" ("sale_type");



CREATE INDEX "idx_sales_status" ON "public"."sales" USING "btree" ("status");



CREATE INDEX "idx_sales_tenant_branch_created" ON "public"."sales" USING "btree" ("tenant_id", "branch_id", "created_at" DESC);



CREATE INDEX "idx_sales_tenant_fulfillment_status" ON "public"."sales" USING "btree" ("tenant_id", "fulfillment_status");



CREATE INDEX "idx_sales_tenant_payment_status" ON "public"."sales" USING "btree" ("tenant_id", "payment_status");



CREATE INDEX "idx_sales_tenant_status" ON "public"."sales" USING "btree" ("tenant_id", "status");



CREATE INDEX "idx_staff_members_branch_id" ON "public"."staff_members" USING "btree" ("branch_id");



CREATE INDEX "idx_staff_members_tenant_id" ON "public"."staff_members" USING "btree" ("tenant_id");



CREATE INDEX "idx_stock_adjustments_adjustment_type" ON "public"."stock_adjustments" USING "btree" ("adjustment_type");



CREATE INDEX "idx_stock_adjustments_approved_by" ON "public"."stock_adjustments" USING "btree" ("approved_by");



CREATE INDEX "idx_stock_adjustments_branch_id" ON "public"."stock_adjustments" USING "btree" ("branch_id");



CREATE INDEX "idx_stock_adjustments_bundle_id" ON "public"."stock_adjustments" USING "btree" ("bundle_id");



CREATE INDEX "idx_stock_adjustments_created_by" ON "public"."stock_adjustments" USING "btree" ("created_by");



CREATE INDEX "idx_stock_adjustments_pending_created" ON "public"."stock_adjustments" USING "btree" ("tenant_id", "created_at" DESC) WHERE (("status")::"text" = 'pending'::"text");



CREATE INDEX "idx_stock_adjustments_product_id" ON "public"."stock_adjustments" USING "btree" ("product_id");



CREATE INDEX "idx_stock_adjustments_reason_id" ON "public"."stock_adjustments" USING "btree" ("reason_id");



CREATE INDEX "idx_stock_adjustments_salesperson_id" ON "public"."stock_adjustments" USING "btree" ("salesperson_id");



CREATE INDEX "idx_stock_adjustments_status" ON "public"."stock_adjustments" USING "btree" ("status");



CREATE INDEX "idx_stock_adjustments_tenant_id" ON "public"."stock_adjustments" USING "btree" ("tenant_id");



CREATE INDEX "idx_stock_branch_product" ON "public"."stock" USING "btree" ("branch_id", "product_id");



CREATE INDEX "idx_stock_product_id" ON "public"."stock" USING "btree" ("product_id");



CREATE INDEX "idx_stock_reorder" ON "public"."stock" USING "btree" ("branch_id", "quantity", "reorder_level");



CREATE INDEX "idx_stock_tenant_branch_product" ON "public"."stock" USING "btree" ("tenant_id", "branch_id", "product_id");



CREATE INDEX "idx_units_of_measurement_base_unit_id" ON "public"."units_of_measurement" USING "btree" ("base_unit_id");



CREATE UNIQUE INDEX "profiles_tenant_pin_lookup_uniq" ON "public"."profiles" USING "btree" ("tenant_id", "pin_lookup") WHERE ("pin_lookup" IS NOT NULL);



CREATE OR REPLACE TRIGGER "trg_sync_credit_note_items_json" AFTER INSERT OR DELETE OR UPDATE ON "public"."credit_note_items" FOR EACH ROW EXECUTE FUNCTION "public"."sync_credit_note_items_json"();



CREATE OR REPLACE TRIGGER "trg_update_kpi_expenses" AFTER INSERT OR DELETE OR UPDATE ON "public"."expenses" FOR EACH ROW EXECUTE FUNCTION "public"."update_kpi_expenses"();



CREATE OR REPLACE TRIGGER "trigger_set_sale_item_tenant_id" BEFORE INSERT ON "public"."sale_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_sale_item_tenant_id"();



CREATE OR REPLACE TRIGGER "update_branches_updated_at" BEFORE UPDATE ON "public"."branches" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_staff_members_updated_at" BEFORE UPDATE ON "public"."staff_members" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_location_id_fkey" FOREIGN KEY ("location_id") REFERENCES "public"."locations"("id");



ALTER TABLE ONLY "public"."branches"
    ADD CONSTRAINT "branches_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."commissions"
    ADD CONSTRAINT "commissions_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."commissions"
    ADD CONSTRAINT "commissions_status_fkey" FOREIGN KEY ("status") REFERENCES "public"."commission_statuses"("code") NOT VALID;



ALTER TABLE ONLY "public"."composite_item_components"
    ADD CONSTRAINT "composite_item_components_component_product_id_fkey" FOREIGN KEY ("component_product_id") REFERENCES "public"."products"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."composite_item_components"
    ADD CONSTRAINT "composite_item_components_composite_product_id_fkey" FOREIGN KEY ("composite_product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."credit_note_items"
    ADD CONSTRAINT "credit_note_items_credit_note_id_fkey" FOREIGN KEY ("credit_note_id") REFERENCES "public"."credit_notes"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."credit_note_items"
    ADD CONSTRAINT "credit_note_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id");



ALTER TABLE ONLY "public"."credit_note_items"
    ADD CONSTRAINT "credit_note_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_applied_to_sale_id_fkey" FOREIGN KEY ("applied_to_sale_id") REFERENCES "public"."sales"("id");



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id");



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_original_sale_id_fkey" FOREIGN KEY ("original_sale_id") REFERENCES "public"."sales"("id");



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_status_fkey" FOREIGN KEY ("status") REFERENCES "public"."credit_note_statuses"("code") NOT VALID;



ALTER TABLE ONLY "public"."credit_notes"
    ADD CONSTRAINT "credit_notes_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."customers"
    ADD CONSTRAINT "customers_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_kpi_snapshots"
    ADD CONSTRAINT "daily_kpi_snapshots_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_kpi_snapshots"
    ADD CONSTRAINT "daily_kpi_snapshots_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_payment_method_snapshots"
    ADD CONSTRAINT "daily_payment_method_snapshots_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_payment_method_snapshots"
    ADD CONSTRAINT "daily_payment_method_snapshots_payment_method_fkey" FOREIGN KEY ("payment_method") REFERENCES "public"."payment_methods"("code") NOT VALID;



ALTER TABLE ONLY "public"."daily_payment_method_snapshots"
    ADD CONSTRAINT "daily_payment_method_snapshots_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_product_sales_snapshots"
    ADD CONSTRAINT "daily_product_sales_snapshots_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_product_sales_snapshots"
    ADD CONSTRAINT "daily_product_sales_snapshots_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."daily_product_sales_snapshots"
    ADD CONSTRAINT "daily_product_sales_snapshots_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_categories"
    ADD CONSTRAINT "expense_categories_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."expense_categories"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_payment_method_fkey" FOREIGN KEY ("payment_method") REFERENCES "public"."payment_methods"("code");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."item_groups"
    ADD CONSTRAINT "item_groups_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."item_groups"
    ADD CONSTRAINT "item_groups_default_commission_type_fkey" FOREIGN KEY ("default_commission_type") REFERENCES "public"."commission_calculation_types"("code");



ALTER TABLE ONLY "public"."item_groups"
    ADD CONSTRAINT "item_groups_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."locations"
    ADD CONSTRAINT "locations_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."product_branches"
    ADD CONSTRAINT "product_branches_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_branches"
    ADD CONSTRAINT "product_branches_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."product_branches"
    ADD CONSTRAINT "product_branches_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_commission_type_fkey" FOREIGN KEY ("commission_type") REFERENCES "public"."commission_calculation_types"("code");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_item_group_id_fkey" FOREIGN KEY ("item_group_id") REFERENCES "public"."item_groups"("id");



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."products"
    ADD CONSTRAINT "products_uom_id_fkey" FOREIGN KEY ("uom_id") REFERENCES "public"."units_of_measurement"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_approvals"
    ADD CONSTRAINT "sale_approvals_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_approvals"
    ADD CONSTRAINT "sale_approvals_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_items"
    ADD CONSTRAINT "sale_items_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id");



ALTER TABLE ONLY "public"."sale_payments"
    ADD CONSTRAINT "sale_payments_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_payments"
    ADD CONSTRAINT "sale_payments_payment_method_fkey" FOREIGN KEY ("payment_method") REFERENCES "public"."payment_methods"("code") NOT VALID;



ALTER TABLE ONLY "public"."sale_payments"
    ADD CONSTRAINT "sale_payments_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "public"."sales"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sale_payments"
    ADD CONSTRAINT "sale_payments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_customer_id_fkey" FOREIGN KEY ("customer_id") REFERENCES "public"."customers"("id");



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_fulfillment_status_fkey" FOREIGN KEY ("fulfillment_status") REFERENCES "public"."fulfillment_statuses"("code") NOT VALID;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_payment_status_fkey" FOREIGN KEY ("payment_status") REFERENCES "public"."payment_statuses"("code") NOT VALID;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_sale_type_fkey" FOREIGN KEY ("sale_type") REFERENCES "public"."sale_types"("code") NOT VALID;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_status_fkey" FOREIGN KEY ("status") REFERENCES "public"."invoice_statuses"("code") NOT VALID;



ALTER TABLE ONLY "public"."sales"
    ADD CONSTRAINT "sales_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."staff_members"
    ADD CONSTRAINT "staff_members_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."staff_members"
    ADD CONSTRAINT "staff_members_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_adjustment_type_fkey" FOREIGN KEY ("adjustment_type") REFERENCES "public"."stock_adjustment_types"("code") NOT VALID;



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_approved_by_fkey" FOREIGN KEY ("approved_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "auth"."users"("id");



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_reason_id_fkey" FOREIGN KEY ("reason_id") REFERENCES "public"."stock_adjustment_reasons"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_status_fkey" FOREIGN KEY ("status") REFERENCES "public"."stock_adjustment_statuses"("code") NOT VALID;



ALTER TABLE ONLY "public"."stock_adjustments"
    ADD CONSTRAINT "stock_adjustments_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock"
    ADD CONSTRAINT "stock_branch_id_fkey" FOREIGN KEY ("branch_id") REFERENCES "public"."branches"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock"
    ADD CONSTRAINT "stock_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "public"."products"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."stock"
    ADD CONSTRAINT "stock_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenant_invoice_counters"
    ADD CONSTRAINT "tenant_invoice_counters_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."units_of_measurement"
    ADD CONSTRAINT "units_of_measurement_base_unit_id_fkey" FOREIGN KEY ("base_unit_id") REFERENCES "public"."units_of_measurement"("id") ON DELETE SET NULL;



ALTER TABLE "public"."branches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "branches_tenant_isolation" ON "public"."branches" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_tenant_isolation" ON "public"."categories" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."commission_calculation_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commission_calculation_types_read_all" ON "public"."commission_calculation_types" FOR SELECT USING (true);



CREATE POLICY "commission_calculation_types_service_write" ON "public"."commission_calculation_types" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."commission_statuses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commission_statuses_read_all" ON "public"."commission_statuses" FOR SELECT USING (true);



CREATE POLICY "commission_statuses_service_write" ON "public"."commission_statuses" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."commissions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "commissions_tenant_isolation" ON "public"."commissions" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."composite_item_components" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "composite_item_components_tenant_isolation" ON "public"."composite_item_components" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."credit_note_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "credit_note_items_tenant_isolation" ON "public"."credit_note_items" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."credit_note_statuses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "credit_note_statuses_read_all" ON "public"."credit_note_statuses" FOR SELECT USING (true);



CREATE POLICY "credit_note_statuses_service_write" ON "public"."credit_note_statuses" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."credit_notes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "credit_notes_tenant_isolation" ON "public"."credit_notes" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."customers" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "customers_tenant_isolation" ON "public"."customers" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."daily_kpi_snapshots" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "daily_kpi_snapshots_select_tenant" ON "public"."daily_kpi_snapshots" FOR SELECT USING (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "daily_kpi_snapshots_service_delete" ON "public"."daily_kpi_snapshots" FOR DELETE USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "daily_kpi_snapshots_service_insert" ON "public"."daily_kpi_snapshots" FOR INSERT WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "daily_kpi_snapshots_service_update" ON "public"."daily_kpi_snapshots" FOR UPDATE USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



ALTER TABLE "public"."daily_payment_method_snapshots" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "daily_payment_method_snapshots_select_tenant" ON "public"."daily_payment_method_snapshots" FOR SELECT USING (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "daily_payment_method_snapshots_service_delete" ON "public"."daily_payment_method_snapshots" FOR DELETE USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "daily_payment_method_snapshots_service_insert" ON "public"."daily_payment_method_snapshots" FOR INSERT WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "daily_payment_method_snapshots_service_update" ON "public"."daily_payment_method_snapshots" FOR UPDATE USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



ALTER TABLE "public"."daily_product_sales_snapshots" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "daily_product_sales_snapshots_select_tenant" ON "public"."daily_product_sales_snapshots" FOR SELECT USING (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "daily_product_sales_snapshots_service_delete" ON "public"."daily_product_sales_snapshots" FOR DELETE USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "daily_product_sales_snapshots_service_insert" ON "public"."daily_product_sales_snapshots" FOR INSERT WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



CREATE POLICY "daily_product_sales_snapshots_service_update" ON "public"."daily_product_sales_snapshots" FOR UPDATE USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



ALTER TABLE "public"."expense_categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "expense_categories_tenant_isolation" ON "public"."expense_categories" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."expenses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "expenses_tenant_isolation" ON "public"."expenses" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."fulfillment_statuses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "fulfillment_statuses_read_all" ON "public"."fulfillment_statuses" FOR SELECT USING (true);



CREATE POLICY "fulfillment_statuses_service_write" ON "public"."fulfillment_statuses" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."invoice_statuses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "invoice_statuses_read_all" ON "public"."invoice_statuses" FOR SELECT USING (true);



CREATE POLICY "invoice_statuses_service_write" ON "public"."invoice_statuses" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."item_groups" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "item_groups_tenant_isolation" ON "public"."item_groups" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."locations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "locations_tenant_isolation" ON "public"."locations" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."payment_methods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payment_methods_read_all" ON "public"."payment_methods" FOR SELECT USING (true);



CREATE POLICY "payment_methods_service_write" ON "public"."payment_methods" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."payment_statuses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payment_statuses_read_all" ON "public"."payment_statuses" FOR SELECT USING (true);



CREATE POLICY "payment_statuses_service_write" ON "public"."payment_statuses" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."pin_login_attempts" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."product_branches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "product_branches_tenant_isolation" ON "public"."product_branches" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."products" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "products_tenant_isolation" ON "public"."products" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."profile_branches" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profile_branches_tenant_isolation" ON "public"."profile_branches" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "profiles_delete_own" ON "public"."profiles" FOR DELETE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "profiles_insert_own" ON "public"."profiles" FOR INSERT WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



CREATE POLICY "profiles_select_own_or_tenant" ON "public"."profiles" FOR SELECT USING ((("user_id" = ( SELECT "auth"."uid"() AS "uid")) OR ("tenant_id" = "public"."current_tenant_id"())));



CREATE POLICY "profiles_update_own" ON "public"."profiles" FOR UPDATE USING (("user_id" = ( SELECT "auth"."uid"() AS "uid"))) WITH CHECK (("user_id" = ( SELECT "auth"."uid"() AS "uid")));



ALTER TABLE "public"."sale_approvals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sale_approvals_tenant_isolation" ON "public"."sale_approvals" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."sale_items" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sale_items_tenant_isolation" ON "public"."sale_items" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."sale_payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sale_payments_tenant_isolation" ON "public"."sale_payments" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."sale_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sale_types_read_all" ON "public"."sale_types" FOR SELECT USING (true);



CREATE POLICY "sale_types_service_write" ON "public"."sale_types" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."sales" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "sales_tenant_isolation" ON "public"."sales" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "service_role_access_invoice_counters" ON "public"."tenant_invoice_counters" USING ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text")) WITH CHECK ((( SELECT "auth"."role"() AS "role") = 'service_role'::"text"));



ALTER TABLE "public"."staff_members" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "staff_members_tenant_isolation" ON "public"."staff_members" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."stock" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."stock_adjustment_reasons" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stock_adjustment_reasons_tenant_isolation" ON "public"."stock_adjustment_reasons" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."stock_adjustment_statuses" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stock_adjustment_statuses_read_all" ON "public"."stock_adjustment_statuses" FOR SELECT USING (true);



CREATE POLICY "stock_adjustment_statuses_service_write" ON "public"."stock_adjustment_statuses" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."stock_adjustment_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stock_adjustment_types_read_all" ON "public"."stock_adjustment_types" FOR SELECT USING (true);



CREATE POLICY "stock_adjustment_types_service_write" ON "public"."stock_adjustment_types" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."stock_adjustments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "stock_adjustments_tenant_isolation" ON "public"."stock_adjustments" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



CREATE POLICY "stock_tenant_isolation" ON "public"."stock" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."tenant_invoice_counters" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tenants_select_own" ON "public"."tenants" FOR SELECT USING (("id" = "public"."current_tenant_id"()));



ALTER TABLE "public"."units_of_measurement" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "units_of_measurement_tenant_isolation" ON "public"."units_of_measurement" USING (("tenant_id" = "public"."current_tenant_id"())) WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));



CREATE PUBLICATION "powersync" FOR ALL TABLES WITH (publish = 'insert, update, delete, truncate');


ALTER PUBLICATION "powersync" OWNER TO "postgres";




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";












GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































REVOKE ALL ON FUNCTION "public"."complete_sale_v2"("p_sale_id" "uuid", "p_tenant_id" "uuid", "p_branch_id" "uuid", "p_customer_id" "uuid", "p_created_by" "uuid", "p_salesperson_id" "uuid", "p_items" "jsonb", "p_payment_method" "text", "p_payment_reference" "text", "p_notes" "text", "p_subtotal" numeric, "p_tax_amount" numeric, "p_discount_amount" numeric, "p_grand_total" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."complete_sale_v2"("p_sale_id" "uuid", "p_tenant_id" "uuid", "p_branch_id" "uuid", "p_customer_id" "uuid", "p_created_by" "uuid", "p_salesperson_id" "uuid", "p_items" "jsonb", "p_payment_method" "text", "p_payment_reference" "text", "p_notes" "text", "p_subtotal" numeric, "p_tax_amount" numeric, "p_discount_amount" numeric, "p_grand_total" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."current_tenant_id"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."current_tenant_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."current_tenant_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."decrement_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."decrement_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."generate_credit_note_number"("p_tenant_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."generate_credit_note_number"("p_tenant_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."generate_invoice_number"("p_tenant_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."generate_invoice_number"("p_tenant_id" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."handle_new_user"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."increment_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."increment_stock"("p_product_id" "uuid", "p_branch_id" "uuid", "p_quantity" numeric) TO "service_role";



REVOKE ALL ON FUNCTION "public"."next_invoice_number"("p_tenant_id" "uuid", "p_prefix" "text", "p_year" integer) FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."next_invoice_number"("p_tenant_id" "uuid", "p_prefix" "text", "p_year" integer) TO "service_role";



REVOKE ALL ON FUNCTION "public"."recalculate_sale_commissions"("p_sale_id" "uuid") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."recalculate_sale_commissions"("p_sale_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."record_sale_payment_v2"("p_payment_id" "uuid", "p_sale_id" "uuid", "p_tenant_id" "uuid", "p_amount" numeric, "p_payment_method" "text", "p_reference_number" "text", "p_notes" "text", "p_allow_overpayment" boolean, "p_recorded_by" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."record_sale_payment_v2"("p_payment_id" "uuid", "p_sale_id" "uuid", "p_tenant_id" "uuid", "p_amount" numeric, "p_payment_method" "text", "p_reference_number" "text", "p_notes" "text", "p_allow_overpayment" boolean, "p_recorded_by" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."record_sale_payment_v2"("p_payment_id" "uuid", "p_sale_id" "uuid", "p_tenant_id" "uuid", "p_amount" numeric, "p_payment_method" "text", "p_reference_number" "text", "p_notes" "text", "p_allow_overpayment" boolean, "p_recorded_by" "uuid") TO "service_role";



REVOKE ALL ON FUNCTION "public"."refresh_daily_operational_aggregates"("p_snapshot_date" "date") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."refresh_daily_operational_aggregates"("p_snapshot_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."set_sale_item_tenant_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_sale_item_tenant_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_sale_item_tenant_id"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."sync_credit_note_items_json"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."sync_credit_note_items_json"() TO "service_role";



REVOKE ALL ON FUNCTION "public"."update_kpi_expenses"() FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."update_kpi_expenses"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";
























GRANT ALL ON TABLE "public"."backup_item_groups_20260519" TO "anon";
GRANT ALL ON TABLE "public"."backup_item_groups_20260519" TO "authenticated";
GRANT ALL ON TABLE "public"."backup_item_groups_20260519" TO "service_role";



GRANT ALL ON TABLE "public"."backup_products_20260519" TO "anon";
GRANT ALL ON TABLE "public"."backup_products_20260519" TO "authenticated";
GRANT ALL ON TABLE "public"."backup_products_20260519" TO "service_role";



GRANT ALL ON TABLE "public"."branches" TO "anon";
GRANT ALL ON TABLE "public"."branches" TO "authenticated";
GRANT ALL ON TABLE "public"."branches" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."commission_calculation_types" TO "anon";
GRANT ALL ON TABLE "public"."commission_calculation_types" TO "authenticated";
GRANT ALL ON TABLE "public"."commission_calculation_types" TO "service_role";



GRANT ALL ON TABLE "public"."commission_statuses" TO "anon";
GRANT ALL ON TABLE "public"."commission_statuses" TO "authenticated";
GRANT ALL ON TABLE "public"."commission_statuses" TO "service_role";



GRANT ALL ON TABLE "public"."commissions" TO "anon";
GRANT ALL ON TABLE "public"."commissions" TO "authenticated";
GRANT ALL ON TABLE "public"."commissions" TO "service_role";



GRANT ALL ON TABLE "public"."composite_item_components" TO "anon";
GRANT ALL ON TABLE "public"."composite_item_components" TO "authenticated";
GRANT ALL ON TABLE "public"."composite_item_components" TO "service_role";



GRANT ALL ON TABLE "public"."credit_note_items" TO "anon";
GRANT ALL ON TABLE "public"."credit_note_items" TO "authenticated";
GRANT ALL ON TABLE "public"."credit_note_items" TO "service_role";



GRANT ALL ON TABLE "public"."credit_note_statuses" TO "anon";
GRANT ALL ON TABLE "public"."credit_note_statuses" TO "authenticated";
GRANT ALL ON TABLE "public"."credit_note_statuses" TO "service_role";



GRANT ALL ON TABLE "public"."credit_notes" TO "anon";
GRANT ALL ON TABLE "public"."credit_notes" TO "authenticated";
GRANT ALL ON TABLE "public"."credit_notes" TO "service_role";



GRANT ALL ON TABLE "public"."customers" TO "anon";
GRANT ALL ON TABLE "public"."customers" TO "authenticated";
GRANT ALL ON TABLE "public"."customers" TO "service_role";



GRANT ALL ON TABLE "public"."daily_kpi_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."daily_kpi_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_kpi_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."daily_payment_method_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."daily_payment_method_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_payment_method_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."daily_product_sales_snapshots" TO "anon";
GRANT ALL ON TABLE "public"."daily_product_sales_snapshots" TO "authenticated";
GRANT ALL ON TABLE "public"."daily_product_sales_snapshots" TO "service_role";



GRANT ALL ON TABLE "public"."expense_categories" TO "anon";
GRANT ALL ON TABLE "public"."expense_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."expense_categories" TO "service_role";



GRANT ALL ON TABLE "public"."expenses" TO "anon";
GRANT ALL ON TABLE "public"."expenses" TO "authenticated";
GRANT ALL ON TABLE "public"."expenses" TO "service_role";



GRANT ALL ON TABLE "public"."fulfillment_statuses" TO "anon";
GRANT ALL ON TABLE "public"."fulfillment_statuses" TO "authenticated";
GRANT ALL ON TABLE "public"."fulfillment_statuses" TO "service_role";



GRANT ALL ON TABLE "public"."invoice_statuses" TO "anon";
GRANT ALL ON TABLE "public"."invoice_statuses" TO "authenticated";
GRANT ALL ON TABLE "public"."invoice_statuses" TO "service_role";



GRANT ALL ON TABLE "public"."item_groups" TO "anon";
GRANT ALL ON TABLE "public"."item_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."item_groups" TO "service_role";



GRANT ALL ON TABLE "public"."locations" TO "anon";
GRANT ALL ON TABLE "public"."locations" TO "authenticated";
GRANT ALL ON TABLE "public"."locations" TO "service_role";



GRANT ALL ON TABLE "public"."payment_methods" TO "anon";
GRANT ALL ON TABLE "public"."payment_methods" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_methods" TO "service_role";



GRANT ALL ON TABLE "public"."payment_statuses" TO "anon";
GRANT ALL ON TABLE "public"."payment_statuses" TO "authenticated";
GRANT ALL ON TABLE "public"."payment_statuses" TO "service_role";



GRANT ALL ON TABLE "public"."pin_login_attempts" TO "anon";
GRANT ALL ON TABLE "public"."pin_login_attempts" TO "authenticated";
GRANT ALL ON TABLE "public"."pin_login_attempts" TO "service_role";



GRANT ALL ON TABLE "public"."product_branches" TO "anon";
GRANT ALL ON TABLE "public"."product_branches" TO "authenticated";
GRANT ALL ON TABLE "public"."product_branches" TO "service_role";



GRANT ALL ON TABLE "public"."products" TO "anon";
GRANT ALL ON TABLE "public"."products" TO "authenticated";
GRANT ALL ON TABLE "public"."products" TO "service_role";



GRANT ALL ON TABLE "public"."profile_branches" TO "anon";
GRANT ALL ON TABLE "public"."profile_branches" TO "authenticated";
GRANT ALL ON TABLE "public"."profile_branches" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."sale_approvals" TO "anon";
GRANT ALL ON TABLE "public"."sale_approvals" TO "authenticated";
GRANT ALL ON TABLE "public"."sale_approvals" TO "service_role";



GRANT ALL ON TABLE "public"."sale_items" TO "anon";
GRANT ALL ON TABLE "public"."sale_items" TO "authenticated";
GRANT ALL ON TABLE "public"."sale_items" TO "service_role";



GRANT ALL ON TABLE "public"."sale_payments" TO "anon";
GRANT ALL ON TABLE "public"."sale_payments" TO "authenticated";
GRANT ALL ON TABLE "public"."sale_payments" TO "service_role";



GRANT ALL ON TABLE "public"."sale_types" TO "anon";
GRANT ALL ON TABLE "public"."sale_types" TO "authenticated";
GRANT ALL ON TABLE "public"."sale_types" TO "service_role";



GRANT ALL ON TABLE "public"."sales" TO "anon";
GRANT ALL ON TABLE "public"."sales" TO "authenticated";
GRANT ALL ON TABLE "public"."sales" TO "service_role";



GRANT ALL ON TABLE "public"."staff_members" TO "anon";
GRANT ALL ON TABLE "public"."staff_members" TO "authenticated";
GRANT ALL ON TABLE "public"."staff_members" TO "service_role";



GRANT ALL ON TABLE "public"."stock" TO "anon";
GRANT ALL ON TABLE "public"."stock" TO "authenticated";
GRANT ALL ON TABLE "public"."stock" TO "service_role";



GRANT ALL ON TABLE "public"."stock_adjustment_reasons" TO "anon";
GRANT ALL ON TABLE "public"."stock_adjustment_reasons" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_adjustment_reasons" TO "service_role";



GRANT ALL ON TABLE "public"."stock_adjustment_statuses" TO "anon";
GRANT ALL ON TABLE "public"."stock_adjustment_statuses" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_adjustment_statuses" TO "service_role";



GRANT ALL ON TABLE "public"."stock_adjustment_types" TO "anon";
GRANT ALL ON TABLE "public"."stock_adjustment_types" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_adjustment_types" TO "service_role";



GRANT ALL ON TABLE "public"."stock_adjustments" TO "anon";
GRANT ALL ON TABLE "public"."stock_adjustments" TO "authenticated";
GRANT ALL ON TABLE "public"."stock_adjustments" TO "service_role";



GRANT ALL ON TABLE "public"."tenant_invoice_counters" TO "anon";
GRANT ALL ON TABLE "public"."tenant_invoice_counters" TO "authenticated";
GRANT ALL ON TABLE "public"."tenant_invoice_counters" TO "service_role";



GRANT ALL ON TABLE "public"."tenants" TO "anon";
GRANT ALL ON TABLE "public"."tenants" TO "authenticated";
GRANT ALL ON TABLE "public"."tenants" TO "service_role";



GRANT ALL ON TABLE "public"."units_of_measurement" TO "anon";
GRANT ALL ON TABLE "public"."units_of_measurement" TO "authenticated";
GRANT ALL ON TABLE "public"."units_of_measurement" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































