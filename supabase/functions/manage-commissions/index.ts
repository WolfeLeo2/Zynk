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
        const userId = parseJwtUserId(token);

        if (!userId) {
            return new Response(JSON.stringify({ error: "Unauthorized" }), {
                status: 401,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const body = await req.json();
        const { action, tenant_id, ...params } = body;

        if (!action || !tenant_id) {
            return new Response(JSON.stringify({ error: "Missing action or tenant_id" }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        // Permission check
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
        
        // We'll use 'record_payments' as the required permission for paying commissions
        if (!isOwner && !perms.includes("record_payments")) {
            return new Response(
                JSON.stringify({ error: "Permission denied: record_payments required" }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const now = new Date().toISOString();

        switch (action) {
            case "mark_paid": {
                const { commission_id } = params;
                if (!commission_id) throw new Error("Missing commission_id");

                const { error } = await supabase
                    .from("commissions")
                    .update({ status: "paid", updated_at: now })
                    .eq("id", commission_id)
                    .eq("tenant_id", tenant_id);

                if (error) throw error;
                return jsonResponse({ success: true, commission_id });
            }

            case "mark_all_paid": {
                const { salesperson_id, branch_id, month } = params;
                if (!salesperson_id) throw new Error("Missing salesperson_id");

                console.log(`Marking all paid for salesperson ${salesperson_id}, branch ${branch_id}, month ${month}`);

                let query = supabase
                    .from("commissions")
                    .update({ status: "paid", updated_at: now })
                    .eq("salesperson_id", salesperson_id)
                    .eq("tenant_id", tenant_id)
                    .eq("status", "pending");

                if (month) {
                    // Filter by created_at range for the specific month (yyyy-MM)
                    const [year, mon] = month.split('-').map(Number);
                    const startDate = new Date(Date.UTC(year, mon - 1, 1)).toISOString();
                    const endDate = new Date(Date.UTC(year, mon, 1)).toISOString();
                    
                    query = query.filter('created_at', 'gte', startDate).filter('created_at', 'lt', endDate);
                }

                if (branch_id && branch_id !== "all") {
                    // Commissions are linked to sales, so we filter by sales.branch_id
                    const { data: saleIds } = await supabase
                        .from("sales")
                        .select("id")
                        .eq("branch_id", branch_id)
                        .eq("tenant_id", tenant_id);
                    
                    if (saleIds && saleIds.length > 0) {
                        query = query.in("sale_id", saleIds.map(s => s.id));
                    } else if (saleIds && saleIds.length === 0) {
                        // No sales for this branch, so nothing to update
                        return jsonResponse({ success: true, count: 0 });
                    }
                }

                const { data, error, count } = await query.select('id');
                if (error) throw error;
                
                return jsonResponse({ success: true, salesperson_id, count: data?.length ?? 0 });
            }

            default:
                return new Response(
                    JSON.stringify({ error: `Unknown action: ${action}` }),
                    { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
                );
        }
    } catch (err: any) {
        return new Response(
            JSON.stringify({ error: err.message || "Internal server error" }),
            { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
    }
});

function jsonResponse(data: any, status = 200) {
    return new Response(JSON.stringify(data), {
        status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
}

function parseJwtUserId(token: string): string | null {
    try {
        const parts = token.split(".");
        if (parts.length < 2) return null;
        const payload = JSON.parse(atob(parts[1].replace(/-/g, "+").replace(/_/g, "/")));
        return payload?.sub || null;
    } catch (_) {
        return null;
    }
}
