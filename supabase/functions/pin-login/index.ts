import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// PIN login: verifies a staff PIN server-side and mints a real session for that
// user, so the device signs in as the actual staffer (Model B). This is a LOGIN
// endpoint — intentionally callable without a prior session (verify_jwt = false).
//
// TODO (hardening, before production): per-(tenant_id) attempt rate-limiting +
// lockout, to blunt online PIN brute force. Tracked in the feature plan §10/§12.

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PEPPER = Deno.env.get("PIN_PEPPER");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const te = new TextEncoder();
const b64 = (buf: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(buf)));
const fromB64 = (s: string) => Uint8Array.from(atob(s), (c) => c.charCodeAt(0));

async function pinLookup(tenantId: string, pin: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", te.encode(PEPPER!), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return b64(await crypto.subtle.sign("HMAC", key, te.encode(`${tenantId}|${pin}`)));
}

async function verifyPin(pin: string, stored: string | null): Promise<boolean> {
  if (!stored) return false;
  const [scheme, iterStr, saltB64, hashB64] = stored.split("$");
  if (scheme !== "pbkdf2") return false;
  const key = await crypto.subtle.importKey("raw", te.encode(pin), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt: fromB64(saltB64), iterations: parseInt(iterStr), hash: "SHA-256" }, key, 256);
  const a = new Uint8Array(bits), b = fromB64(hashB64);
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    if (!PEPPER) return json({ error: "Server not configured (PIN_PEPPER)" }, 500);

    const { tenant_id, pin } = await req.json();
    if (!tenant_id || !pin) return json({ error: "Missing tenant_id or pin" }, 400);

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const lookup = await pinLookup(String(tenant_id), String(pin));

    const { data: profile } = await supabase
      .from("profiles")
      .select("id, user_id, pin_hash, status")
      .eq("tenant_id", tenant_id).eq("pin_lookup", lookup).maybeSingle();

    // Generic error — never reveal whether the PIN or the tenant was wrong.
    const invalid = () => json({ error: "Invalid PIN" }, 401);
    if (!profile || !(await verifyPin(String(pin), profile.pin_hash))) return invalid();
    if (profile.status && profile.status !== "active") return json({ error: "Account inactive" }, 403);

    const { data: targetUser } = await supabase.auth.admin.getUserById(profile.user_id);
    const email = targetUser?.user?.email;
    if (!email) return invalid();

    // Mint a session for the real staffer (no email is sent by generateLink).
    const { data: link, error: linkErr } = await supabase.auth.admin.generateLink({
      type: "magiclink", email,
    });
    if (linkErr || !link?.properties?.hashed_token) return json({ error: "Could not start session" }, 500);

    // Client completes with supabase.auth.verifyOtp({ token_hash, type: 'email' }).
    return json({
      token_hash: link.properties.hashed_token,
      profile_id: profile.id,
      user_id: profile.user_id,
    });
  } catch (_e) {
    return json({ error: "Internal error" }, 500);
  }
});
