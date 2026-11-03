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
        // getUser verifies the signature; decoding the payload alone would trust a forged token.
        const { data: { user } } = await supabase.auth.getUser(token);
        const userId = user?.id ?? null;

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

                // One transaction: all of the bundle applies, or none of it.
                const { data: count, error } = await supabase.rpc("set_stock_adjustment_approval", {
                    p_tenant_id: tenant_id,
                    p_bundle_id: bundle_id ?? null,
                    p_adjustment_id: bundle_id ? null : adjustment_id,
                    p_user_id: userId,
                    p_approve: true,
                });
                if (error) throw new Error(error.message);

                return jsonResponse({ status: "approved", count });
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
                    .eq("tenant_id", tenant_id)
                    .eq("status", "pending");

                if (bundle_id) updateQuery.eq("bundle_id", bundle_id);
                else updateQuery.eq("id", adjustment_id);

                const { error: updateError } = await updateQuery;
                if (updateError) throw new Error(`Rejection failed: ${updateError.message}`);

                return jsonResponse({ status: "rejected" });
            }

            case "unapprove_adjustment": {
                if (!bundle_id && !adjustment_id) {
                    throw new Error("Missing bundle_id or adjustment_id");
                }

                const { data: count, error } = await supabase.rpc("set_stock_adjustment_approval", {
                    p_tenant_id: tenant_id,
                    p_bundle_id: bundle_id ?? null,
                    p_adjustment_id: bundle_id ? null : adjustment_id,
                    p_user_id: userId,
                    p_approve: false,
                });
                if (error) throw new Error(error.message);

                return jsonResponse({ status: "unapproved", count });
            }

            case "delete_adjustment": {
                 if (!bundle_id && !adjustment_id) {
                    throw new Error("Missing bundle_id or adjustment_id");
                }

                // Hard Delete as requested
                const deleteQuery = supabase
                    .from("stock_adjustments")
                    .delete()
                    .eq("tenant_id", tenant_id)
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
