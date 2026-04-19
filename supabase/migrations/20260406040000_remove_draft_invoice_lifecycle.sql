-- Invoices should start in pending_approval and no longer use draft lifecycle.

UPDATE public.sales
SET status = 'pending_approval',
    updated_at = NOW()
WHERE status = 'draft';