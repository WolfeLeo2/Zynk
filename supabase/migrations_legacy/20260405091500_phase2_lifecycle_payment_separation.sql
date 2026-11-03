-- Phase 2: Separate lifecycle status from payment/release status end-to-end.
-- Normalizes legacy lifecycle values and aligns payment status from monetary state.

-- Normalize lifecycle casing from historical defaults.
UPDATE public.sales
SET status = lower(status)
WHERE status IS NOT NULL
  AND status <> lower(status);

-- Legacy lifecycle values that represented payment state are mapped back to
-- approved lifecycle. Payment/release state should be read from payment_status
-- and fulfillment_status.
UPDATE public.sales
SET status = 'approved'
WHERE status IN ('partially_paid', 'paid', 'completed');

-- Ensure fulfillment status is present.
UPDATE public.sales
SET fulfillment_status = 'unfulfilled'
WHERE fulfillment_status IS NULL OR fulfillment_status = '';

-- Recompute payment status from amount paid vs grand total.
UPDATE public.sales
SET payment_status = CASE
  WHEN COALESCE(grand_total, 0) <= 0 THEN 'paid'
  WHEN COALESCE(amount_paid, 0) <= 0 THEN 'unpaid'
  WHEN COALESCE(amount_paid, 0) < COALESCE(grand_total, 0) THEN 'partially_paid'
  ELSE 'paid'
END;

-- completed_at is derived from approved + paid + fulfilled.
UPDATE public.sales
SET completed_at = CASE
  WHEN status = 'approved'
    AND payment_status = 'paid'
    AND fulfillment_status = 'fulfilled'
  THEN COALESCE(completed_at, now())
  ELSE NULL
END;
