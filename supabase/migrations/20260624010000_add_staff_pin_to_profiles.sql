-- Staff PIN login (Model B) — server-only PIN material on profiles.
-- pin_hash / pin_lookup are NEVER synced to devices: they are simply not declared
-- in the PowerSync client Schema (lib/core/config/powersync.dart), so PowerSync
-- drops them. PIN verification + session minting happen in edge functions.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS pin_hash text,
  ADD COLUMN IF NOT EXISTS pin_set_at timestamptz,
  ADD COLUMN IF NOT EXISTS pin_lookup text;

-- One PIN per tenant: pin_lookup is a deterministic peppered HMAC of the PIN,
-- so it both enforces uniqueness and lets pin-login find the staffer.
CREATE UNIQUE INDEX IF NOT EXISTS profiles_tenant_pin_lookup_uniq
  ON public.profiles (tenant_id, pin_lookup) WHERE pin_lookup IS NOT NULL;

COMMENT ON COLUMN public.profiles.pin_hash IS 'Server-only slow-KDF hash of the staff PIN. Never synced to devices.';
COMMENT ON COLUMN public.profiles.pin_lookup IS 'Server-only HMAC(pepper, tenant_id|pin) — uniqueness + lookup for pin-login. Never synced to devices.';
