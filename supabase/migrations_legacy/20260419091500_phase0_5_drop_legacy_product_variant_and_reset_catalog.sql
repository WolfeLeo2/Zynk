-- Phase 0.5: Remove dead variant schema and reset product-domain data.
-- User-approved decision: reset across all tenants, while preserving users/profiles/tenants/staff.

BEGIN;

CREATE SCHEMA IF NOT EXISTS backup_20260419;

DO $$
BEGIN
  IF to_regclass('backup_20260419.products') IS NULL THEN
    CREATE TABLE backup_20260419.products AS TABLE public.products WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.stock') IS NULL THEN
    CREATE TABLE backup_20260419.stock AS TABLE public.stock WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.stock_adjustments') IS NULL THEN
    CREATE TABLE backup_20260419.stock_adjustments AS TABLE public.stock_adjustments WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.sale_items') IS NULL THEN
    CREATE TABLE backup_20260419.sale_items AS TABLE public.sale_items WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.sales') IS NULL THEN
    CREATE TABLE backup_20260419.sales AS TABLE public.sales WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.sale_payments') IS NULL THEN
    CREATE TABLE backup_20260419.sale_payments AS TABLE public.sale_payments WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.credit_note_items') IS NULL THEN
    CREATE TABLE backup_20260419.credit_note_items AS TABLE public.credit_note_items WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.credit_notes') IS NULL THEN
    CREATE TABLE backup_20260419.credit_notes AS TABLE public.credit_notes WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.commissions') IS NULL THEN
    CREATE TABLE backup_20260419.commissions AS TABLE public.commissions WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.composite_item_components') IS NULL THEN
    CREATE TABLE backup_20260419.composite_item_components AS TABLE public.composite_item_components WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.categories') IS NULL THEN
    CREATE TABLE backup_20260419.categories AS TABLE public.categories WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.item_groups') IS NULL THEN
    CREATE TABLE backup_20260419.item_groups AS TABLE public.item_groups WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.units_of_measurement') IS NULL THEN
    CREATE TABLE backup_20260419.units_of_measurement AS TABLE public.units_of_measurement WITH DATA;
  END IF;

  IF to_regclass('backup_20260419.stock_adjustment_reasons') IS NULL THEN
    CREATE TABLE backup_20260419.stock_adjustment_reasons AS TABLE public.stock_adjustment_reasons WITH DATA;
  END IF;

  IF to_regclass('public.daily_product_sales_snapshots') IS NOT NULL
     AND to_regclass('backup_20260419.daily_product_sales_snapshots') IS NULL THEN
    CREATE TABLE backup_20260419.daily_product_sales_snapshots AS TABLE public.daily_product_sales_snapshots WITH DATA;
  END IF;

  IF to_regclass('public.daily_payment_method_snapshots') IS NOT NULL
     AND to_regclass('backup_20260419.daily_payment_method_snapshots') IS NULL THEN
    CREATE TABLE backup_20260419.daily_payment_method_snapshots AS TABLE public.daily_payment_method_snapshots WITH DATA;
  END IF;

  IF to_regclass('public.daily_kpi_snapshots') IS NOT NULL
     AND to_regclass('backup_20260419.daily_kpi_snapshots') IS NULL THEN
    CREATE TABLE backup_20260419.daily_kpi_snapshots AS TABLE public.daily_kpi_snapshots WITH DATA;
  END IF;
END $$;

-- Reset product-domain data and product-related transactional references.
-- Keep users/profiles/tenants/staff/branches intact.
TRUNCATE TABLE
  public.sale_payments,
  public.sale_items,
  public.credit_note_items,
  public.credit_notes,
  public.commissions,
  public.sales,
  public.stock_adjustments,
  public.stock,
  public.composite_item_components,
  public.daily_product_sales_snapshots,
  public.daily_payment_method_snapshots,
  public.daily_kpi_snapshots,
  public.products,
  public.categories,
  public.item_groups,
  public.units_of_measurement,
  public.stock_adjustment_reasons
RESTART IDENTITY CASCADE;

-- Remove dead legacy variant/group schema.
ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_group_id_fkey;
ALTER TABLE public.products DROP COLUMN IF EXISTS group_id;
ALTER TABLE public.products DROP COLUMN IF EXISTS product_type;
ALTER TABLE public.products DROP COLUMN IF EXISTS variant_options;
ALTER TABLE public.products DROP COLUMN IF EXISTS variant_images;

DROP INDEX IF EXISTS public.idx_products_group_id;
DROP TABLE IF EXISTS public.stock_item_groups CASCADE;

COMMIT;
