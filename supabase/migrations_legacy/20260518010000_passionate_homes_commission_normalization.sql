-- Normalization of commission types for Passionate Homes tenant to 'fixed'
-- Tenant ID: 870a2a76-4a11-4b6f-a537-ee71d4f82037
-- Migration Version: 20260518010000

BEGIN;

-- 1. Update item groups
UPDATE public.item_groups 
SET default_commission_type = 'fixed' 
WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037' 
  AND default_commission_type = 'none';

-- 2. Update products
UPDATE public.products 
SET commission_type = 'fixed' 
WHERE tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037' 
  AND commission_type = 'none';

COMMIT;
