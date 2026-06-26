# Passionate Homes Square Meter Pricing & Catalog Decoupling Implementation Plan

**Goal:** Transition the Passionate Homes tenant catalog to a per-square-meter (sqm) pricing model while maintaining stock in physical integer boxes, and execute the clean decoupling and reorganization of tile groups.

**Architecture:** Add `default_pricing_unit` and `default_coverage_per_box` to `item_groups`, and `pricing_unit` and `coverage_per_box` override fields to `products`. Update `ProductPricingService` to resolve the effective box price dynamically. Update the POS, Cart, and Invoice UI components to display both box counts and square meter coverage.

**Tech Stack:** Supabase PostgreSQL, PowerSync SQLite, Dart/Flutter, Riverpod.

## User Review Required
> [!IMPORTANT]
> - All tile commissions will remain stored **per box** in the system, even when priced per square meter.
> - Stock will remain saved as **physical integer boxes** to guarantee absolute accuracy and prevent floating-point mismatch/rounding errors.
> - All tile variant overrides (selling prices and commissions) will be cleared so that they cleanly inherit the group defaults, eliminating redundancy.
> - For Accessories, Basins, Taps, and Toilets, variant prices remain as overrides, but the commissions for Basins, Toilets, and Taps will inherit group defaults.

## Proposed Changes

### Database Migration

#### [NEW] [20260519090000_passionate_homes_sqm_pricing_and_item_shifts.sql](file:///Users/app/AndroidStudioProjects/Zynk/supabase/migrations/20260519090000_passionate_homes_sqm_pricing_and_item_shifts.sql)
We will add the new DDL schema updates and catalog shifts as a local migration.

```sql
-- DDL modifications to public.item_groups and public.products
ALTER TABLE public.item_groups ADD COLUMN IF NOT EXISTS default_pricing_unit TEXT DEFAULT 'piece';
ALTER TABLE public.item_groups ADD COLUMN IF NOT EXISTS default_coverage_per_box NUMERIC DEFAULT 1.0;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS pricing_unit TEXT;
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS coverage_per_box NUMERIC;

-- Add check constraints
ALTER TABLE public.item_groups DROP CONSTRAINT IF EXISTS chk_default_pricing_unit;
ALTER TABLE public.item_groups ADD CONSTRAINT chk_default_pricing_unit CHECK (default_pricing_unit IN ('piece', 'sqm'));

ALTER TABLE public.products DROP CONSTRAINT IF EXISTS chk_pricing_unit;
ALTER TABLE public.products ADD CONSTRAINT chk_pricing_unit CHECK (pricing_unit IN ('piece', 'sqm'));

-- Comments for documentation
COMMENT ON COLUMN public.item_groups.default_pricing_unit IS 'Default unit of measure for pricing this group: piece (flat price per box/unit) or sqm (price per square meter).';
COMMENT ON COLUMN public.item_groups.default_coverage_per_box IS 'Default coverage area per box/unit in square meters (sqm).';
COMMENT ON COLUMN public.products.pricing_unit IS 'Unit of measure override for pricing this product: piece or sqm.';
COMMENT ON COLUMN public.products.coverage_per_box IS 'Coverage area override per box/unit in square meters (sqm).';

-- 1. Rename existing host groups for Passionate Homes (870a2a76-4a11-4b6f-a537-ee71d4f82037)
UPDATE public.item_groups 
SET name = 'MR66/FGC66' 
WHERE name = 'MR66/FGC66/FGP55' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';

UPDATE public.item_groups 
SET name = 'MRP66/YMP66' 
WHERE name = 'MRP66/YMP66/PGS55' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';

UPDATE public.item_groups 
SET name = 'PMCP24' 
WHERE name = 'PMCP24/FGP33' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';

-- 2. Insert new group entities
INSERT INTO public.item_groups (id, tenant_id, name, description, default_pricing_unit, default_coverage_per_box, default_selling_price, default_commission_type, default_commission_value)
VALUES 
  (extensions.uuid_generate_v4(), '870a2a76-4a11-4b6f-a537-ee71d4f82037', 'FGP33', '300x300mm', 'sqm', 1.5, 850.00, 'fixed', 5.00),
  (extensions.uuid_generate_v4(), '870a2a76-4a11-4b6f-a537-ee71d4f82037', 'FGP55/PGS55', '500x500mm', 'sqm', 1.75, 1600.00, 'fixed', 20.00),
  (extensions.uuid_generate_v4(), '870a2a76-4a11-4b6f-a537-ee71d4f82037', 'BLO33/YMZ33', '300x300mm', 'sqm', 1.5, 870.00, 'fixed', 5.00),
  (extensions.uuid_generate_v4(), '870a2a76-4a11-4b6f-a537-ee71d4f82037', 'MRG212', '200x1200mm', 'sqm', 0.144, 1800.00, 'fixed', 20.00)
ON CONFLICT DO NOTHING;

-- 3. Update existing groups with their new pricing, box coverage size, and fixed commissions
UPDATE public.item_groups SET description = '400x400mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.92, default_selling_price = 920.00, default_commission_type = 'fixed', default_commission_value = 10.00 WHERE name = 'BLO44/FGE44' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '400x400mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.92, default_selling_price = 910.00, default_commission_type = 'fixed', default_commission_value = 10.00 WHERE name = 'FGB44' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '400x400mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.92, default_selling_price = 920.00, default_commission_type = 'fixed', default_commission_value = 10.00 WHERE name = 'GG44' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '250x400mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.5, default_selling_price = 850.00, default_commission_type = 'fixed', default_commission_value = 5.00 WHERE name = 'GW24' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '300x600mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.44, default_selling_price = 1280.00, default_commission_type = 'fixed', default_commission_value = 10.00 WHERE name = 'MCP36' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '300x600mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.44, default_selling_price = 1300.00, default_commission_type = 'fixed', default_commission_value = 10.00 WHERE name = 'MR36' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '400x400mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.92, default_selling_price = 940.00, default_commission_type = 'fixed', default_commission_value = 10.00 WHERE name = 'MR44' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '1200x600mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.44, default_selling_price = 2200.00, default_commission_type = 'fixed', default_commission_value = 50.00 WHERE name = 'MR612/MRP612' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '600x600mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.44, default_selling_price = 1700.00, default_commission_type = 'fixed', default_commission_value = 20.00 WHERE name = 'MR66/FGC66' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '400x400mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.44, default_selling_price = 1250.00, default_commission_type = 'fixed', default_commission_value = 10.00 WHERE name = 'MRG44' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '600x600mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.44, default_selling_price = 1700.00, default_commission_type = 'fixed', default_commission_value = 20.00 WHERE name = 'MRP66/YMP66' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '450x450mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.62, default_selling_price = 870.00, default_commission_type = 'fixed', default_commission_value = 20.00 WHERE name = 'MRS45/CG45' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';
UPDATE public.item_groups SET description = '250x400mm', default_pricing_unit = 'sqm', default_coverage_per_box = 1.5, default_selling_price = 850.00, default_commission_type = 'fixed', default_commission_value = 5.00 WHERE name = 'PMCP24' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';

-- 4. Shift products starting with FGP33 to the new FGP33 group
UPDATE public.products 
SET item_group_id = (SELECT id FROM public.item_groups WHERE name = 'FGP33' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037')
WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037'
  AND (name LIKE 'FGP33%' OR sku LIKE 'FGP33%');

-- 5. Shift products starting with PGS55 to the new FGP55/PGS55 group
UPDATE public.products 
SET item_group_id = (SELECT id FROM public.item_groups WHERE name = 'FGP55/PGS55' AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037')
WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037'
  AND (name LIKE 'PGS55%' OR sku LIKE 'PGS55%');

-- 6. Set products in tile groups to inherit pricing & commissions from group
UPDATE public.products
SET base_price = NULL,
    commission_type = NULL,
    commission_value = NULL
WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037'
  AND item_group_id IN (
    SELECT id FROM public.item_groups 
    WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037'
      AND name NOT IN ('Accessories', 'Basins', 'Taps', 'Toilets')
  );

-- 7. Normalize Basins, Toilets, and Taps to inherit commissions from group (while maintaining variant override prices)
UPDATE public.products
SET commission_type = NULL,
    commission_value = NULL
WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037'
  AND item_group_id IN (
    SELECT id FROM public.item_groups 
    WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037'
      AND name IN ('Basins', 'Toilets', 'Taps')
  );
```

### Client-Side PowerSync Local Schema Sync

#### [MODIFY] [powersync.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/core/config/powersync.dart)
We will add `default_pricing_unit` and `default_coverage_per_box` to `item_groups` Table schema, and `pricing_unit` and `coverage_per_box` to `products` Table schema.

### Client-Side Dart Model Definitions & Code Generation

#### [MODIFY] [schema_models.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/core/models/schema_models.dart)
Add the properties and serialization annotations to `ItemGroup` and `Product` classes.

### Dynamic Sqm Pricing Calculation Service

#### [NEW] [product_pricing_service.dart](file:///Users/app/AndroidStudioProjects/Zynk/lib/core/services/product_pricing_service.dart)
Implement a robust service helper to resolve the effective pricing per box and pricing unit dynamically.

## Verification Plan

### Automated Tests
- Run database validations via Python audit script to confirm all `Passionate Homes` variant overrides are successfully cleared, and catalog group prices match the CSV values perfectly.
- Run `dart analyze` and `dart test` (if unit tests exist) to ensure no syntax errors.

### Manual Verification
- Verify in client UI that tiles reflect correct sqm breakdown (e.g. `5 boxes (7.20 sqm) @ KES 700/sqm = KES 5,040.00`).
