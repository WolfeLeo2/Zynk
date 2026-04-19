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

        const userId = parseJwtUserId(token);
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
            subtotal,
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

        // ── Generate sequential invoice number ──
        const currentYear = new Date().getFullYear();
        const { data: seq, error: counterError } = await supabase.rpc(
            "next_invoice_number",
            { p_tenant_id: tenant_id, p_prefix: "INV", p_year: currentYear }
        );

        if (counterError) {
            return new Response(
                JSON.stringify({ error: `Invoice number generation failed: ${counterError.message}` }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const invoiceNumber = `INV-${currentYear}-${String(seq).padStart(5, "0")}`;
        const saleId = crypto.randomUUID();
        const now = new Date().toISOString();

        // ── Insert pending-approval invoice (NO stock decrement, NO payment) ──
        const { error: saleError } = await supabase.from("sales").insert({
            id: saleId,
            tenant_id,
            branch_id,
            customer_id: customer_id || null,
            invoice_number: invoiceNumber,
            sale_type: "invoice",
            created_by: userId,
            salesperson_id,
            subtotal: subtotal || 0,
            tax_amount: tax_amount || 0,
            discount_amount: discount_amount || 0,
            grand_total: grand_total || 0,
            amount_paid: 0,
            status: "pending_approval",
            notes: notes || null,
            due_date: due_date || null,
            created_at: now,
            updated_at: now,
        });

        if (saleError) {
            return new Response(
                JSON.stringify({ error: `Invoice creation failed: ${saleError.message}` }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        // ── Insert invoice items ──
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
            await supabase.from("sales").delete().eq("id", saleId);
            return new Response(
                JSON.stringify({ error: `Items creation failed: ${itemsError.message}` }),
                { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        return new Response(
            JSON.stringify({
                sale_id: saleId,
                invoice_number: invoiceNumber,
                status: "pending_approval",
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

function parseJwtUserId(token: string): string | null {
    try {
        const parts = token.split(".");
        if (parts.length < 2) return null;

        const base64Url = parts[1];
        const base64 = base64Url.replace(/-/g, "+").replace(/_/g, "/");
        const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, "=");
        const payload = JSON.parse(atob(padded));

        return typeof payload?.sub === "string" && payload.sub.length > 0
            ? payload.sub
            : null;
    } catch (_) {
        return null;
    }
}
