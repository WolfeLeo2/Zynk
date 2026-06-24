import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Auth check
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing auth" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey);

    // Verify JWT and get user
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);
    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = await req.json();
    const {
      sale_id,
      tenant_id,
      branch_id,
      customer_id,
      salesperson_id,
      items,
      payment_method,
      payment_reference,
      notes,
      subtotal,
      tax_amount,
      discount_amount,
      grand_total,
    } = body;

    // Validate required fields
    if (!tenant_id || !branch_id || !items || !payment_method) {
      return new Response(
        JSON.stringify({ error: "Missing required fields" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Atomic completion ──
    // sale insert + items + payment + stock decrement + invoice number all run
    // inside one DB transaction. A client-supplied sale_id makes retries
    // idempotent (no duplicate sale / double stock decrement). See migration
    // 20260624000000_atomic_sale_and_payment_rpcs.sql.
    const saleId = sale_id || crypto.randomUUID();

    const { data: result, error: rpcError } = await supabase.rpc(
      "complete_sale_v2",
      {
        p_sale_id: saleId,
        p_tenant_id: tenant_id,
        p_branch_id: branch_id,
        p_customer_id: customer_id || null,
        p_created_by: user.id,
        p_salesperson_id: salesperson_id || null,
        p_items: items,
        p_payment_method: payment_method,
        p_payment_reference: payment_reference || null,
        p_notes: notes || null,
        p_subtotal: subtotal || 0,
        p_tax_amount: tax_amount || 0,
        p_discount_amount: discount_amount || 0,
        p_grand_total: grand_total || 0,
      }
    );

    if (rpcError) {
      console.error("complete_sale_v2 error:", rpcError);
      return new Response(
        JSON.stringify({ error: "Sale completion failed" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify(result),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    console.error("Unhandled error:", err);
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
