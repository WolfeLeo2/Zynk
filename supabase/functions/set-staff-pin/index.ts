import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PEPPER = Deno.env.get("PIN_PEPPER");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PBKDF2_ITERATIONS = 100_000;
const te = new TextEncoder();

const b64 = (buf: ArrayBuffer) => btoa(String.fromCharCode(...new Uint8Array(buf)));

async function hashPin(pin: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const key = await crypto.subtle.importKey("raw", te.encode(pin), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", salt, iterations: PBKDF2_ITERATIONS, hash: "SHA-256" }, key, 256);
  return `pbkdf2$${PBKDF2_ITERATIONS}$${b64(salt.buffer)}$${b64(bits)}`;
}

async function pinLookup(tenantId: string, pin: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", te.encode(PEPPER!), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return b64(await crypto.subtle.sign("HMAC", key, te.encode(`${tenantId}|${pin}`)));
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

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Missing auth" }, 401);

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) return json({ error: "Unauthorized" }, 401);

    const { target_profile_id, pin } = await req.json();
    if (!target_profile_id || !pin) return json({ error: "Missing target_profile_id or pin" }, 400);
    if (!/^\d{6,}$/.test(String(pin))) return json({ error: "PIN must be at least 6 digits" }, 400);

    // Caller must be an Owner.
    const { data: caller } = await supabase
      .from("profiles").select("role, tenant_id").eq("user_id", user.id).single();
    if (!caller || caller.role !== "Owner") return json({ error: "Owner role required" }, 403);

    // Target must be in the caller's tenant.
    const { data: target } = await supabase
      .from("profiles").select("id, tenant_id").eq("id", target_profile_id).single();
    if (!target || target.tenant_id !== caller.tenant_id) {
      return json({ error: "Target not found in your tenant" }, 404);
    }

    const lookup = await pinLookup(caller.tenant_id, String(pin));

    // PIN must be unique within the tenant.
    const { data: clash } = await supabase
      .from("profiles").select("id").eq("tenant_id", caller.tenant_id)
      .eq("pin_lookup", lookup).neq("id", target_profile_id).maybeSingle();
    if (clash) return json({ error: "That PIN is already in use" }, 409);

    const pinHash = await hashPin(String(pin));
    const { error: updErr } = await supabase.from("profiles")
      .update({ pin_hash: pinHash, pin_lookup: lookup, pin_set_at: new Date().toISOString() })
      .eq("id", target_profile_id).eq("tenant_id", caller.tenant_id);
    if (updErr) return json({ error: "Failed to set PIN" }, 500);

    return json({ ok: true });
  } catch (_e) {
    return json({ error: "Internal error" }, 500);
  }
});
