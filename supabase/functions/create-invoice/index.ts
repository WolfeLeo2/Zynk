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
        const authHeader = req.headers.get("Authorization");
        if (!authHeader) {
            return new Response(JSON.stringify({ error: "Missing auth" }), {
                status: 401,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const supabase = createClient(supabaseUrl, serviceRoleKey);
        const token = authHeader.replace(/^Bearer\s+/i, "").trim();
        if (!token) {
            return new Response(JSON.stringify({ error: "Missing bearer token" }), {
                status: 401,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        // getUser verifies the signature; decoding the payload alone would trust a forged token.
        const { data: { user } } = await supabase.auth.getUser(token);
        const userId = user?.id ?? null;
        if (!userId) {
            console.error("create-invoice auth failed", {
                hasAuthHeader: Boolean(authHeader),
                reason: "invalid_jwt_payload",
            });
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
            salesperson_id,
            items,
            notes,
            due_date,
            tax_amount,
            discount_amount,
            grand_total,
        } = body;

        if (!tenant_id || !branch_id || !salesperson_id || !items?.length) {
            return new Response(
                JSON.stringify({ error: "Missing required fields (tenant_id, branch_id, salesperson_id, items)" }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // ── Permission check ──
        const { data: profile } = await supabase
            .from("profiles")
            .select("role, permissions")
            .eq("user_id", userId)
            .eq("tenant_id", tenant_id)
            .single();

        if (!profile) {
            return new Response(JSON.stringify({ error: "Profile not found" }), {
                status: 403,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const isOwner = profile.role?.toLowerCase() === "owner";
        const perms: string[] = profile.permissions || [];
        if (!isOwner && !perms.includes("create_invoices")) {
            return new Response(
                JSON.stringify({ error: "Permission denied: create_invoices required" }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // ── Create the invoice in one transaction ──
        // Totals are computed server-side from the items; grand_total is only a
        // cross-check (TOTAL_MISMATCH). See 20261102000100_server_side_sale_totals.sql.
        const saleId = body.sale_id || crypto.randomUUID();
        const { data: result, error: rpcError } = await supabase.rpc("create_invoice_v2", {
            p_sale_id: saleId,
            p_tenant_id: tenant_id,
            p_branch_id: branch_id,
            p_customer_id: customer_id || null,
            p_created_by: userId,
            p_salesperson_id: salesperson_id,
            p_items: items,
            p_notes: notes || null,
            p_due_date: due_date || null,
            p_tax_amount: tax_amount || 0,
            p_discount_amount: discount_amount || 0,
            p_grand_total: grand_total || 0,
        });

        if (rpcError) {
            return new Response(
                JSON.stringify({ error: `Invoice creation failed: ${rpcError.message}` }),
                { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        return new Response(
            JSON.stringify({
                sale_id: result.sale_id,
                invoice_number: result.invoice_number,
                status: result.status,
            }),
            {
                status: 200,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
        );
    } catch (err) {
        console.error("create-invoice error:", err);
        return new Response(
            JSON.stringify({ error: err.message || "Internal server error" }),
            {
                status: 500,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
        );
    }
});
