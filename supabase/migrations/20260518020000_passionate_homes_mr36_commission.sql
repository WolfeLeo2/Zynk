-- Set default commission value for MR36 group to 10
-- Group ID: 32574d9d-4337-48cf-b6b0-7349c4aaf64b
-- Migration Version: 20260518020000

BEGIN;

UPDATE public.item_groups 
SET default_commission_value = 10 
WHERE id = '32574d9d-4337-48cf-b6b0-7349c4aaf64b' 
  AND tenant_id = '870a2a76-4a11-4b6f-a537-ee71d4f82037';

COMMIT;
