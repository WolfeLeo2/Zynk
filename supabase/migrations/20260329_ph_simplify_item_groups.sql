-- PH Branch Migration: Simplify item_groups and products
-- Applied via Supabase MCP on 2026-03-29

-- Remove variant/product_type system from products
ALTER TABLE public.products
  DROP COLUMN IF EXISTS product_type,
  DROP COLUMN IF EXISTS variant_options,
  DROP COLUMN IF EXISTS variant_images,
  DROP COLUMN IF EXISTS parent_id,
  DROP COLUMN IF EXISTS group_id;  -- was referencing dead stock_item_groups table

-- Remove attributes from item_groups (now pure organizational containers)
ALTER TABLE public.item_groups
  DROP COLUMN IF EXISTS attributes;

-- Drop the dead stock_item_groups table (never used in the app)
DROP TABLE IF EXISTS public.stock_item_groups CASCADE;
