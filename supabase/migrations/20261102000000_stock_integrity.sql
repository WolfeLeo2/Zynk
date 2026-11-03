-- Stock integrity.
--  1. stock.quantity is server-owned. RLS on stock only checks the tenant, so a
--     device's PowerSync upsert of a whole stock row could overwrite quantity
--     and silently undo sales/approvals made on the server since it last synced.
--  2. Stock-adjustment approve/unapprove run in one transaction, scoped to the
--     tenant. The Edge Function used to chain separate calls per adjustment, so
--     a failure part-way applied some of a bundle, and it never checked that the
--     adjustments belonged to the caller's tenant.

-- ── 1. stock.quantity is server-owned ─────────────────────────────────────────
-- Devices still insert zero "seed" rows (createProduct/createBranch), so writes
-- stay allowed; only server roles (SECURITY DEFINER functions run as postgres,
-- service_role) may set quantity. Keeping the old value instead of raising means
-- older app versions that still upsert whole rows don't get their upload queue
-- stuck on a permission error.
CREATE OR REPLACE FUNCTION public.stock_quantity_server_owned()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') THEN
    IF TG_OP = 'INSERT' THEN
      NEW.quantity := 0;
    ELSE
      NEW.quantity := OLD.quantity;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER stock_quantity_server_owned
  BEFORE INSERT OR UPDATE ON public.stock
  FOR EACH ROW EXECUTE FUNCTION public.stock_quantity_server_owned();

-- ── 2. Atomic, tenant-scoped approve / unapprove ──────────────────────────────
-- Uses the live increment_stock / decrement_stock, so their NO_STOCK_RECORD and
-- INSUFFICIENT_STOCK checks still apply; any of them raising rolls back the
-- whole bundle. FOR UPDATE + the status filter make a concurrent double-approve
-- apply stock once: the second caller re-checks status after the lock and
-- finds nothing.
CREATE OR REPLACE FUNCTION public.set_stock_adjustment_approval(
  p_tenant_id uuid,
  p_bundle_id uuid,
  p_adjustment_id uuid,
  p_user_id uuid,
  p_approve boolean
) RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_prev numeric;
  v_delta numeric;
  v_count int := 0;
BEGIN
  IF p_bundle_id IS NULL AND p_adjustment_id IS NULL THEN
    RAISE EXCEPTION 'Missing bundle_id or adjustment_id';
  END IF;

  FOR r IN
    SELECT id, product_id, branch_id, quantity FROM public.stock_adjustments
    WHERE tenant_id = p_tenant_id
      AND status = CASE WHEN p_approve THEN 'pending' ELSE 'approved' END
      AND CASE WHEN p_bundle_id IS NOT NULL THEN bundle_id = p_bundle_id
               ELSE id = p_adjustment_id END
    ORDER BY id
    FOR UPDATE
  LOOP
    SELECT quantity INTO v_prev FROM public.stock
      WHERE product_id = r.product_id AND branch_id = r.branch_id
      FOR UPDATE;
    v_delta := CASE WHEN p_approve THEN 1 ELSE -1 END * COALESCE(r.quantity, 0);

    IF v_delta > 0 THEN
      PERFORM public.increment_stock(r.product_id, r.branch_id, v_delta);
    ELSIF v_delta < 0 THEN
      PERFORM public.decrement_stock(r.product_id, r.branch_id, -v_delta);
    END IF;

    UPDATE public.stock_adjustments SET
      status = CASE WHEN p_approve THEN 'approved' ELSE 'pending' END,
      approved_by = CASE WHEN p_approve THEN p_user_id END,
      approved_at = CASE WHEN p_approve THEN now() END,
      previous_quantity = CASE WHEN p_approve THEN COALESCE(v_prev, 0) END
    WHERE id = r.id;
    v_count := v_count + 1;
  END LOOP;

  IF v_count = 0 THEN
    RAISE EXCEPTION 'No % adjustments found to %',
      CASE WHEN p_approve THEN 'pending' ELSE 'approved' END,
      CASE WHEN p_approve THEN 'approve' ELSE 'unapprove' END;
  END IF;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.set_stock_adjustment_approval(uuid, uuid, uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_stock_adjustment_approval(uuid, uuid, uuid, uuid, boolean) TO service_role;
