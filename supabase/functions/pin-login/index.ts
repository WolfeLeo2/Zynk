import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// PIN login: verifies a staff PIN server-side and mints a real session for that
// user (Model B). LOGIN endpoint — callable without a prior session (verify_jwt=false).
//
// Brute-force throttle: per (tenant_id, client ip), 5 consecutive failures start
// an exponential lockout (30s, doubling, capped at 15 min); reset on success or
// after the window lapses. Email+password login remains as a fallback if PIN
// login is temporarily locked.
// ponytail: ip comes from x-forwarded-for, which a determined attacker can rotate;
// the slow PBKDF2 per attempt + the password fallback bound the residual risk.

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PEPPER = Deno.env.get("PIN_PEPPER");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const LOCK_THRESHOLD = 5; // failures before lockout begins
const LOCK_BASE_SECS = 30;
const LOCK_MAX_SECS = 900; // 15 min
const WINDOW_MS = 15 * 60 * 1000; // stale failures older than this reset to 0

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

// deno-lint-ignore no-explicit-any
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  try {
    if (!PEPPER) return json({ error: "Server not configured (PIN_PEPPER)" }, 500);

    const { tenant_id, pin } = await req.json();
    if (!tenant_id || !pin) return json({ error: "Missing tenant_id or pin" }, 400);

    const supabase = createClient(supabaseUrl, serviceRoleKey);
    const ip = (req.headers.get("x-forwarded-for") ?? "").split(",")[0].trim() || "unknown";
    const nowMs = Date.now();

    // --- throttle check ---
    const { data: att } = await supabase
      .from("pin_login_attempts")
      .select("fail_count, locked_until, updated_at")
      .eq("tenant_id", tenant_id).eq("ip", ip).maybeSingle();

    if (att?.locked_until && new Date(att.locked_until).getTime() > nowMs) {
      const retry = Math.ceil((new Date(att.locked_until).getTime() - nowMs) / 1000);
      return json({ error: `Too many attempts. Try again in ${retry}s.`, retry_after: retry }, 429);
    }

    // Stale failures (older than the window, not currently locked) reset to 0.
    const priorFails =
      att && (nowMs - new Date(att.updated_at).getTime()) < WINDOW_MS ? att.fail_count : 0;

    const lookup = await pinLookup(String(tenant_id), String(pin));
    const { data: profile } = await supabase
      .from("profiles")
      .select("id, user_id, pin_hash, status")
      .eq("tenant_id", tenant_id).eq("pin_lookup", lookup).maybeSingle();

    const pinOk = profile != null && (await verifyPin(String(pin), profile.pin_hash));

    if (!pinOk) {
      const fails = priorFails + 1;
      let lockedUntil: string | null = null;
      if (fails >= LOCK_THRESHOLD) {
        const secs = Math.min(LOCK_MAX_SECS, LOCK_BASE_SECS * 2 ** (fails - LOCK_THRESHOLD));
        lockedUntil = new Date(nowMs + secs * 1000).toISOString();
      }
      await supabase.from("pin_login_attempts").upsert({
        tenant_id, ip, fail_count: fails, locked_until: lockedUntil,
        updated_at: new Date(nowMs).toISOString(),
      }, { onConflict: "tenant_id,ip" });
      return json({ error: "Invalid PIN" }, 401);
    }

    // Correct PIN — clear the throttle for this (tenant, ip).
    await supabase.from("pin_login_attempts").delete().eq("tenant_id", tenant_id).eq("ip", ip);

    if (profile!.status && profile!.status !== "active") {
      return json({ error: "Account inactive" }, 403);
    }

    const { data: targetUser } = await supabase.auth.admin.getUserById(profile!.user_id);
    const email = targetUser?.user?.email;
    if (!email) return json({ error: "Invalid PIN" }, 401);

    const { data: link, error: linkErr } = await supabase.auth.admin.generateLink({
      type: "magiclink", email,
    });
    if (linkErr || !link?.properties?.hashed_token) return json({ error: "Could not start session" }, 500);

    return json({
      token_hash: link.properties.hashed_token,
      profile_id: profile!.id,
      user_id: profile!.user_id,
    });
  } catch (_e) {
    return json({ error: "Internal error" }, 500);
  }
});
