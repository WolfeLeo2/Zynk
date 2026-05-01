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
            return jsonResponse({ error: "Missing auth" }, 401);
        }

        const supabase = createClient(supabaseUrl, serviceRoleKey);
        const token = authHeader.replace(/^Bearer\s+/i, "").trim();
        const userId = parseJwtUserId(token);

        if (!userId) {
            return jsonResponse({ error: "Unauthorized" }, 401);
        }

        const body = await req.json();
        const { action, tenant_id, bundle_id, adjustment_id, reason } = body;

        if (!action || !tenant_id) {
            return jsonResponse({ error: "Missing action or tenant_id" }, 400);
        }

        // 1. Permission Check
        const { data: profile } = await supabase
            .from("profiles")
            .select("role, permissions")
            .eq("user_id", userId)
            .eq("tenant_id", tenant_id)
            .single();

        if (!profile) {
            return jsonResponse({ error: "Profile not found" }, 403);
        }

        const isOwner = profile.role?.toLowerCase() === "owner";
        const perms: string[] = profile.permissions || [];
        // Use "approve_stock" permission for these actions
        const canManageStock = isOwner || perms.includes("approve_stock");

        if (!canManageStock) {
            return jsonResponse({ error: "Permission denied: approve_stock required" }, 403);
        }

        const now = new Date().toISOString();

        switch (action) {
            case "approve_adjustment": {
                if (!bundle_id && !adjustment_id) {
                    throw new Error("Missing bundle_id or adjustment_id");
                }

                const query = supabase.from("stock_adjustments").select("*").eq("status", "pending");
                if (bundle_id) query.eq("bundle_id", bundle_id);
                else query.eq("id", adjustment_id);

                const { data: adjustments, error: fetchError } = await query;

                if (fetchError || !adjustments || adjustments.length === 0) {
                    throw new Error("No pending adjustments found to approve");
                }

                // Atomic stock updates
                for (const adj of adjustments) {
                    const quantity = Math.abs(Number(adj.quantity || 0));
                    const changeValue = Number(adj.quantity || 0);
                    const rpcName = changeValue >= 0 ? "increment_stock" : "decrement_stock";

                    // 1. Fetch current stock before applying
                    const { data: stockData } = await supabase
                        .from("stock")
                        .select("quantity")
                        .eq("product_id", adj.product_id)
                        .eq("branch_id", adj.branch_id)
                        .single();
                    
                    const previousQuantity = stockData?.quantity || 0;

                    // 2. Update stock via RPC
                    if (quantity !== 0) {
                        const { error: stockError } = await supabase.rpc(rpcName, {
                            p_product_id: adj.product_id,
                            p_branch_id: adj.branch_id,
                            p_quantity: quantity,
                        });

                        if (stockError) {
                            throw new Error(`Stock update failed for ${adj.product_id}: ${stockError.message}`);
                        }
                    }

                    // 3. Update individual adjustment record with previous_quantity snapshot
                    const { error: adjUpdateError } = await supabase
                        .from("stock_adjustments")
                        .update({
                            status: "approved",
                            approved_by: userId,
                            approved_at: now,
                            previous_quantity: previousQuantity
                        })
                        .eq("id", adj.id);
                    
                    if (adjUpdateError) {
                        throw new Error(`Adjustment update failed for ${adj.id}: ${adjUpdateError.message}`);
                    }
                }

                return jsonResponse({ status: "approved", count: adjustments.length });
            }

            case "reject_adjustment": {
                if (!bundle_id && !adjustment_id) {
                    throw new Error("Missing bundle_id or adjustment_id");
                }

                // Update status (Removed non-existent updated_at column)
                const updateQuery = supabase
                    .from("stock_adjustments")
                    .update({
                        status: "rejected",
                        rejection_reason: reason || "Rejected by manager",
                        approved_by: userId,
                        approved_at: now,
                    })
                    .eq("status", "pending");

                if (bundle_id) updateQuery.eq("bundle_id", bundle_id);
                else updateQuery.eq("id", adjustment_id);

                const { error: updateError } = await updateQuery;
                if (updateError) throw new Error(`Rejection failed: ${updateError.message}`);

                return jsonResponse({ status: "rejected" });
            }

            case "delete_adjustment": {
                 if (!bundle_id && !adjustment_id) {
                    throw new Error("Missing bundle_id or adjustment_id");
                }

                // Hard Delete as requested
                const deleteQuery = supabase
                    .from("stock_adjustments")
                    .delete()
                    .eq("status", "pending"); 

                if (bundle_id) deleteQuery.eq("bundle_id", bundle_id);
                else deleteQuery.eq("id", adjustment_id);

                const { error: deleteError } = await deleteQuery;
                if (deleteError) throw new Error(`Hard Delete failed: ${deleteError.message}`);

                return jsonResponse({ status: "deleted" });
            }

            default:
                return jsonResponse({ error: `Unknown action: ${action}` }, 400);
        }
    } catch (err: any) {
        console.error("manage-stock-adjustment error:", err);
        return jsonResponse({ error: err.message || "Internal server error" }, 500);
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
