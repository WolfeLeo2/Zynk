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
      tenant_id,
      branch_id,
      customer_id,
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

    // ── Generate sequential invoice number ──
    const currentYear = new Date().getFullYear();

    // Upsert counter row and atomically increment
    const { data: counterData, error: counterError } = await supabase.rpc(
      "next_invoice_number",
      {
        p_tenant_id: tenant_id,
        p_prefix: "INV",
        p_year: currentYear,
      }
    );

    if (counterError) {
      console.error("Counter error:", counterError);
      return new Response(
        JSON.stringify({ error: `Invoice number generation failed: ${counterError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const seq = counterData as number;
    const invoiceNumber = `INV-${currentYear}-${String(seq).padStart(5, "0")}`;

    // ── Generate UUIDv7 ──
    const saleId = crypto.randomUUID(); // Deno uses v4; for v7 we'd need a lib, using v4 for now

    const now = new Date().toISOString();

    // ── Insert sale ──
    const { error: saleError } = await supabase.from("sales").insert({
      id: saleId,
      tenant_id,
      branch_id,
      customer_id: customer_id || null,
      invoice_number: invoiceNumber,
      sale_type: "pos_sale",
      created_by: user.id,
      subtotal: subtotal || 0,
      tax_amount: tax_amount || 0,
      discount_amount: discount_amount || 0,
      grand_total: grand_total || 0,
      amount_paid: grand_total || 0,
      payment_method,
      status: "completed",
      fulfillment_status: "fulfilled",
      notes: notes || null,
      completed_at: now,
      created_at: now,
      updated_at: now,
    });

    if (saleError) {
      console.error("Sale insert error:", saleError);
      return new Response(
        JSON.stringify({ error: `Sale creation failed: ${saleError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Insert sale items ──
    const saleItems = items.map((item: any) => ({
      id: crypto.randomUUID(),
      sale_id: saleId,
      tenant_id,
      product_id: item.product_id,
      quantity: item.quantity,
      unit_price: item.unit_price,
      cost_price: item.cost_price || 0,
      tax_amount: item.tax_amount || 0,
      discount: item.discount || 0,
      total: item.total,
      created_at: now,
      updated_at: now,
    }));

    const { error: itemsError } = await supabase
      .from("sale_items")
      .insert(saleItems);

    if (itemsError) {
      console.error("Items insert error:", itemsError);
      // Rollback sale
      await supabase.from("sales").delete().eq("id", saleId);
      return new Response(
        JSON.stringify({ error: `Items creation failed: ${itemsError.message}` }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Insert payment record ──
    const { error: paymentError } = await supabase
      .from("sale_payments")
      .insert({
        id: crypto.randomUUID(),
        sale_id: saleId,
        tenant_id,
        amount: grand_total || 0,
        payment_method,
        reference_number: null,
        notes: "POS Sale initial payment",
        created_at: now,
        updated_at: now,
      });

    if (paymentError) {
      console.error("Payment insert error:", paymentError);
    }



    // ── Decrement stock ──
    for (const item of items) {
      const { error: stockError } = await supabase.rpc(
        "decrement_stock",
        {
          p_product_id: item.product_id,
          p_branch_id: branch_id,
          p_quantity: item.quantity,
        }
      );

      if (stockError) {
        console.error(`Stock decrement error for ${item.product_id}:`, stockError);
      }
    }

    return new Response(
      JSON.stringify({
        sale_id: saleId,
        invoice_number: invoiceNumber,
        status: "completed",
      }),
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
