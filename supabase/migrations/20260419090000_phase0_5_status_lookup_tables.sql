-- Phase 0.5: Normalize business state fields via lookup tables + FKs.
-- This keeps tenant data writes constrained to valid state vocabularies.

BEGIN;

CREATE TABLE IF NOT EXISTS public.invoice_statuses (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_statuses (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.fulfillment_statuses (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sale_types (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.payment_methods (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.credit_note_statuses (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.commission_statuses (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.stock_adjustment_statuses (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.stock_adjustment_types (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.commission_calculation_types (
  code TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  is_legacy BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed lookup values from current runtime literals (including legacy values).
INSERT INTO public.invoice_statuses (code, label, sort_order, is_legacy) VALUES
  ('pending_approval', 'Pending Approval', 10, false),
  ('approved', 'Approved', 20, false),
  ('rejected', 'Rejected', 30, false),
  ('voided', 'Voided', 40, false),
  ('partially_paid', 'Partially Paid (Legacy)', 90, true),
  ('paid', 'Paid (Legacy)', 91, true),
  ('completed', 'Completed (Legacy)', 92, true),
  ('draft', 'Draft (Legacy)', 99, true)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.payment_statuses (code, label, sort_order, is_legacy) VALUES
  ('unpaid', 'Unpaid', 10, false),
  ('partially_paid', 'Partially Paid', 20, false),
  ('paid', 'Paid', 30, false)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.fulfillment_statuses (code, label, sort_order, is_legacy) VALUES
  ('unfulfilled', 'Unfulfilled', 10, false),
  ('fulfilled', 'Fulfilled', 20, false)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.sale_types (code, label, sort_order, is_legacy) VALUES
  ('invoice', 'Invoice', 10, false),
  ('pos_sale', 'POS Sale', 20, false),
  ('sale', 'Sale (Legacy)', 99, true)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.payment_methods (code, label, sort_order, is_legacy) VALUES
  ('cash', 'Cash', 10, false),
  ('mpesa', 'M-Pesa', 20, false),
  ('card', 'Card', 30, false),
  ('bank_transfer', 'Bank Transfer', 40, false),
  ('credit_note', 'Credit Note', 50, false),
  ('unknown', 'Unknown', 99, true)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.credit_note_statuses (code, label, sort_order, is_legacy) VALUES
  ('draft', 'Draft', 10, false),
  ('pending_approval', 'Pending Approval', 20, false),
  ('approved', 'Approved', 30, false),
  ('applied', 'Applied', 40, false),
  ('voided', 'Voided', 50, false)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.commission_statuses (code, label, sort_order, is_legacy) VALUES
  ('pending', 'Pending', 10, false),
  ('paid', 'Paid', 20, false),
  ('voided', 'Voided', 99, true)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.stock_adjustment_statuses (code, label, sort_order, is_legacy) VALUES
  ('pending', 'Pending', 10, false),
  ('approved', 'Approved', 20, false),
  ('rejected', 'Rejected', 30, false)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.stock_adjustment_types (code, label, sort_order, is_legacy) VALUES
  ('addition', 'Addition', 10, false),
  ('reduction', 'Reduction', 20, false),
  ('initial', 'Initial', 30, false),
  ('damage', 'Damage', 40, false)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

INSERT INTO public.commission_calculation_types (code, label, sort_order, is_legacy) VALUES
  ('none', 'None', 0, false),
  ('fixed', 'Fixed Amount', 10, false),
  ('percentage', 'Percentage', 20, false),
  ('percent', 'Percent (Legacy Alias)', 99, true)
ON CONFLICT (code) DO UPDATE
SET label = EXCLUDED.label,
    sort_order = EXCLUDED.sort_order,
    is_legacy = EXCLUDED.is_legacy;

-- Read-only to authenticated users, write-only to service role.
DO $$
DECLARE
  t TEXT;
  tables TEXT[] := ARRAY[
    'invoice_statuses',
    'payment_statuses',
    'fulfillment_statuses',
    'sale_types',
    'payment_methods',
    'credit_note_statuses',
    'commission_statuses',
    'stock_adjustment_statuses',
    'stock_adjustment_types',
    'commission_calculation_types'
  ];
BEGIN
  FOREACH t IN ARRAY tables LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_read_all', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_service_write', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT USING (true)',
      t || '_read_all',
      t
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR ALL USING ((SELECT auth.role()) = ''service_role'') WITH CHECK ((SELECT auth.role()) = ''service_role'')',
      t || '_service_write',
      t
    );
  END LOOP;
END $$;

-- Normalize defaults before constraints.
UPDATE public.sales
SET status = 'pending_approval'
WHERE status IS NULL OR status = '';

UPDATE public.sales
SET payment_status = 'unpaid'
WHERE payment_status IS NULL OR payment_status = '';

UPDATE public.sales
SET fulfillment_status = 'unfulfilled'
WHERE fulfillment_status IS NULL OR fulfillment_status = '';

UPDATE public.sales
SET sale_type = 'invoice'
WHERE sale_type IS NULL OR sale_type = '';

UPDATE public.stock_adjustments
SET status = 'approved'
WHERE status IS NULL OR status = '';

UPDATE public.commissions
SET status = 'pending'
WHERE status IS NULL OR status = '';

-- Add FK constraints as NOT VALID to avoid blocking on historical dirty rows.
DO $$
BEGIN
  IF to_regclass('public.sales') IS NOT NULL THEN
    ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_status_fkey;
    ALTER TABLE public.sales
      ADD CONSTRAINT sales_status_fkey
      FOREIGN KEY (status)
      REFERENCES public.invoice_statuses(code)
      NOT VALID;

    ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_payment_status_fkey;
    ALTER TABLE public.sales
      ADD CONSTRAINT sales_payment_status_fkey
      FOREIGN KEY (payment_status)
      REFERENCES public.payment_statuses(code)
      NOT VALID;

    ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_fulfillment_status_fkey;
    ALTER TABLE public.sales
      ADD CONSTRAINT sales_fulfillment_status_fkey
      FOREIGN KEY (fulfillment_status)
      REFERENCES public.fulfillment_statuses(code)
      NOT VALID;

    ALTER TABLE public.sales DROP CONSTRAINT IF EXISTS sales_sale_type_fkey;
    ALTER TABLE public.sales
      ADD CONSTRAINT sales_sale_type_fkey
      FOREIGN KEY (sale_type)
      REFERENCES public.sale_types(code)
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.sale_payments') IS NOT NULL THEN
    ALTER TABLE public.sale_payments DROP CONSTRAINT IF EXISTS sale_payments_payment_method_fkey;
    ALTER TABLE public.sale_payments
      ADD CONSTRAINT sale_payments_payment_method_fkey
      FOREIGN KEY (payment_method)
      REFERENCES public.payment_methods(code)
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.credit_notes') IS NOT NULL THEN
    ALTER TABLE public.credit_notes DROP CONSTRAINT IF EXISTS credit_notes_status_fkey;
    ALTER TABLE public.credit_notes
      ADD CONSTRAINT credit_notes_status_fkey
      FOREIGN KEY (status)
      REFERENCES public.credit_note_statuses(code)
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.commissions') IS NOT NULL THEN
    ALTER TABLE public.commissions DROP CONSTRAINT IF EXISTS commissions_status_fkey;
    ALTER TABLE public.commissions
      ADD CONSTRAINT commissions_status_fkey
      FOREIGN KEY (status)
      REFERENCES public.commission_statuses(code)
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.stock_adjustments') IS NOT NULL THEN
    ALTER TABLE public.stock_adjustments DROP CONSTRAINT IF EXISTS stock_adjustments_status_fkey;
    ALTER TABLE public.stock_adjustments
      ADD CONSTRAINT stock_adjustments_status_fkey
      FOREIGN KEY (status)
      REFERENCES public.stock_adjustment_statuses(code)
      NOT VALID;

    ALTER TABLE public.stock_adjustments DROP CONSTRAINT IF EXISTS stock_adjustments_adjustment_type_fkey;
    ALTER TABLE public.stock_adjustments
      ADD CONSTRAINT stock_adjustments_adjustment_type_fkey
      FOREIGN KEY (adjustment_type)
      REFERENCES public.stock_adjustment_types(code)
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.item_groups') IS NOT NULL THEN
    ALTER TABLE public.item_groups DROP CONSTRAINT IF EXISTS item_groups_default_commission_type_fkey;
    ALTER TABLE public.item_groups
      ADD CONSTRAINT item_groups_default_commission_type_fkey
      FOREIGN KEY (default_commission_type)
      REFERENCES public.commission_calculation_types(code)
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'products'
      AND column_name = 'commission_type'
  ) THEN
    ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_commission_type_fkey;
    ALTER TABLE public.products
      ADD CONSTRAINT products_commission_type_fkey
      FOREIGN KEY (commission_type)
      REFERENCES public.commission_calculation_types(code)
      NOT VALID;
  END IF;
END $$;

DO $$
BEGIN
  IF to_regclass('public.daily_payment_method_snapshots') IS NOT NULL THEN
    ALTER TABLE public.daily_payment_method_snapshots DROP CONSTRAINT IF EXISTS daily_payment_method_snapshots_payment_method_fkey;
    ALTER TABLE public.daily_payment_method_snapshots
      ADD CONSTRAINT daily_payment_method_snapshots_payment_method_fkey
      FOREIGN KEY (payment_method)
      REFERENCES public.payment_methods(code)
      NOT VALID;
  END IF;
END $$;

COMMIT;
