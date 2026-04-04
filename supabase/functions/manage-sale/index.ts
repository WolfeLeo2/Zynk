import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Permission required for each action
const ACTION_PERMISSIONS: Record<string, string> = {
    update_draft: "create_invoices",
    record_payment: "record_payments",
    approve_sale: "approve_invoices",
    reject_sale: "approve_invoices",
    void_sale: "void_sales",
    create_credit_note: "issue_credit_notes",
    approve_credit_note: "approve_invoices",
    apply_credit: "issue_credit_notes",
    submit_for_approval: "create_invoices",
    fulfill_sale: "approve_invoices",
    delete_payment: "void_sales",
    delete_sale: "void_sales",
};

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
        const { action, ...params } = body;

        if (!action) {
            return new Response(JSON.stringify({ error: "Missing action" }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        // ── Get tenant context ──
        // The client can pass tenant_id directly to avoid a DB lookup race condition
        // (e.g. approving a draft invoice that may not have synced to Supabase yet).
        const saleId = params.sale_id;
        if (!saleId && action !== "apply_credit") {
            return new Response(JSON.stringify({ error: "Missing sale_id" }), {
                status: 400,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        let tenantId: string;
        if (params.tenant_id) {
            // Prefer client-provided tenant_id to avoid the sale lookup entirely.
            tenantId = params.tenant_id;
        } else if (saleId) {
            const { data: sale } = await supabase
                .from("sales")
                .select("tenant_id")
                .eq("id", saleId)
                .single();
            if (!sale) {
                return new Response(JSON.stringify({ error: "Sale not found" }), {
                    status: 404,
                    headers: { ...corsHeaders, "Content-Type": "application/json" },
                });
            }
            tenantId = sale.tenant_id;
        } else {
            tenantId = params.tenant_id;
        }

        // ── Permission check ──
        const { data: profile } = await supabase
            .from("profiles")
            .select("role, permissions")
            .eq("user_id", user.id)
            .eq("tenant_id", tenantId)
            .single();

        if (!profile) {
            return new Response(JSON.stringify({ error: "Profile not found" }), {
                status: 403,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const isOwner = profile.role?.toLowerCase() === "owner";
        const perms: string[] = profile.permissions || [];
        const requiredPerm = ACTION_PERMISSIONS[action];

        if (requiredPerm && !isOwner && !perms.includes(requiredPerm)) {
            return new Response(
                JSON.stringify({ error: `Permission denied: ${requiredPerm} required` }),
                { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
            );
        }

        const now = new Date().toISOString();

        // ── Action handlers ──
        switch (action) {
            case "update_draft": {
                const {
                    customer_id,
                    salesperson_id,
                    notes: saleNotes,
                    due_date,
                    items: saleItems,
                } = params;

                if (!customer_id || !salesperson_id || !saleItems?.length) {
                    throw new Error("Missing required fields: customer_id, salesperson_id, items");
                }

                const { data: sale } = await supabase
                    .from("sales")
                    .select("id, status, amount_paid")
                    .eq("id", saleId)
                    .single();

                if (!sale) {
                    throw new Error("Sale not found");
                }

                if (!["draft", "pending_approval"].includes(sale.status)) {
                    throw new Error("Only draft or pending approval invoices can be edited");
                }

                if ((sale.amount_paid || 0) > 0) {
                    throw new Error("Cannot edit an invoice with recorded payments");
                }

                const normalizedItems = (saleItems as any[])
                    .filter((item) => Number(item.quantity || 0) > 0)
                    .map((item) => ({
                        id: item.id || crypto.randomUUID(),
                        sale_id: saleId,
                        product_id: item.product_id,
                        tenant_id: tenantId,
                        quantity: Number(item.quantity || 0),
                        unit_price: Number(item.unit_price || 0),
                        cost_price: Number(item.cost_price || 0),
                        tax_amount: Number(item.tax_amount || 0),
                        discount: Number(item.discount || 0),
                        total: Number(item.total || 0),
                        product_name: item.product_name || null,
                        created_at: now,
                        updated_at: now,
                    }));

                if (!normalizedItems.length) {
                    throw new Error("Invoice must have at least one item");
                }

                const subtotal = normalizedItems.reduce(
                    (sum, item) => sum + Number(item.total || 0),
                    0
                );

                const { error: saleUpdateError } = await supabase
                    .from("sales")
                    .update({
                        customer_id,
                        salesperson_id,
                        subtotal,
                        total_amount: subtotal,
                        grand_total: subtotal,
                        notes: saleNotes || null,
                        due_date: due_date || null,
                        updated_at: now,
                    })
                    .eq("id", saleId);

                if (saleUpdateError) {
                    throw new Error(`Draft update failed: ${saleUpdateError.message}`);
                }

                const { error: deleteItemsError } = await supabase
                    .from("sale_items")
                    .delete()
                    .eq("sale_id", saleId);

                if (deleteItemsError) {
                    throw new Error(`Draft item replace failed: ${deleteItemsError.message}`);
                }

                const { error: insertItemsError } = await supabase
                    .from("sale_items")
                    .insert(normalizedItems);

                if (insertItemsError) {
                    throw new Error(`Draft item insert failed: ${insertItemsError.message}`);
                }

                return jsonResponse({
                    sale_id: saleId,
                    status: sale.status,
                    subtotal,
                });
            }

            case "submit_for_approval": {
                const { error } = await supabase
                    .from("sales")
                    .update({ status: "pending_approval", updated_at: now })
                    .eq("id", saleId)
                    .eq("status", "draft");

                if (error) throw new Error(`Submit failed: ${error.message}`);
                return jsonResponse({ status: "pending_approval", sale_id: saleId });
            }

            case "approve_sale": {
                // Get sale to check branch for stock decrement
                const { data: sale } = await supabase
                    .from("sales")
                    .select("*, sale_items(*)")
                    .eq("id", saleId)
                    .single();

                if (!sale) {
                    throw new Error("Sale not found in backend. Ensure the invoice has synced.");
                }
                
                if (!["pending_approval", "draft"].includes(sale.status)) {
                    throw new Error(`Sale (${sale.status}) must be draft or pending approval to be approved`);
                }

                // If the invoice is already fully paid, and we are approving it, transition it to completed.
                const newStatus = sale.payment_status === "paid" ? "completed" : "approved";

                // Update status
                const { error } = await supabase
                    .from("sales")
                    .update({
                        status: newStatus,
                        approved_by: user.id,
                        updated_at: now,
                    })
                    .eq("id", saleId);

                if (error) throw new Error(`Approve failed: ${error.message}`);

                return jsonResponse({ status: newStatus, sale_id: saleId });
            }

            case "fulfill_sale": {
                // Get sale to check branch for stock decrement
                const { data: sale } = await supabase
                    .from("sales")
                    .select("*, sale_items(*)")
                    .eq("id", saleId)
                    .single();

                if (!sale || sale.fulfillment_status === "fulfilled") {
                    throw new Error("Sale not found or already fulfilled");
                }

                if (!["approved", "partially_paid", "paid", "completed"].includes(sale.status)) {
                    throw new Error("Sale must be approved or moving towards payment to be fulfilled");
                }

                const { error } = await supabase
                    .from("sales")
                    .update({
                        fulfillment_status: "fulfilled",
                        updated_at: now,
                    })
                    .eq("id", saleId);

                if (error) throw new Error(`Fulfill failed: ${error.message}`);

                // Decrement stock on fulfillment
                for (const item of sale.sale_items || []) {
                    await supabase.rpc("decrement_stock", {
                        p_product_id: item.product_id,
                        p_branch_id: sale.branch_id,
                        p_quantity: item.quantity,
                    });
                }

                return jsonResponse({ fulfillment_status: "fulfilled", sale_id: saleId });
            }

            case "reject_sale": {
                const { error } = await supabase
                    .from("sales")
                    .update({
                        status: "rejected",
                        approved_by: user.id,
                        notes: params.reason || "Rejected",
                        updated_at: now,
                    })
                    .eq("id", saleId)
                    .eq("status", "pending_approval");

                if (error) throw new Error(`Reject failed: ${error.message}`);
                return jsonResponse({ status: "rejected", sale_id: saleId });
            }

            case "void_sale": {
                const { data: sale } = await supabase
                    .from("sales")
                    .select("*, sale_items(*)")
                    .eq("id", saleId)
                    .single();

                if (!sale) throw new Error("Sale not found");
                if (sale.status === "completed" || sale.status === "voided") {
                    throw new Error("Cannot void a completed or already voided sale");
                }

                // Reverse stock if it was fulfilled
                if (sale.fulfillment_status === 'fulfilled') {
                    for (const item of sale.sale_items || []) {
                        await supabase.rpc("increment_stock", {
                            p_product_id: item.product_id,
                            p_branch_id: sale.branch_id,
                            p_quantity: item.quantity,
                        });
                    }
                }

                const { error } = await supabase
                    .from("sales")
                    .update({
                        status: "voided",
                        notes: `${sale.notes || ""}\n[VOIDED] ${params.reason || "Voided by user"}`,
                        updated_at: now,
                    })
                    .eq("id", saleId);

                if (error) throw new Error(`Void failed: ${error.message}`);
                return jsonResponse({ status: "voided", sale_id: saleId });
            }

            case "record_payment": {
                const {
                    amount,
                    payment_method,
                    reference_number,
                    notes: paymentNotes,
                } = params;

                if (!amount || !payment_method) {
                    throw new Error("Missing amount or payment_method");
                }

                const { data: sale } = await supabase
                    .from("sales")
                    .select("*")
                    .eq("id", saleId)
                    .single();

                if (!sale) throw new Error("Sale not found. Ensure the invoice has synced before recording payment.");

                // Can only accept payment if it's not fully paid and not voided.
                if (sale.payment_status === "paid" || sale.status === "voided" || sale.status === "rejected") {
                    throw new Error(`Cannot record payment on ${sale.status} sale or an already paid sale`);
                }

                // Insert payment
                const { error: payError } = await supabase
                    .from("sale_payments")
                    .insert({
                        id: crypto.randomUUID(),
                        sale_id: saleId,
                        tenant_id: sale.tenant_id,
                        branch_id: sale.branch_id,
                        amount,
                        payment_method,
                        reference_number: reference_number || null,
                        notes: paymentNotes || null,
                        created_at: now,
                        updated_at: now,
                    });

                if (payError) throw new Error(`Payment failed: ${payError.message}`);
                
                // Update sale totals
                const newAmountPaid = (sale.amount_paid || 0) + amount;
                const grandTotal = sale.grand_total || 0;

                let newPaymentStatus = "partially_paid";
                if (newAmountPaid >= grandTotal) {
                    newPaymentStatus = "paid";
                }

                let newStatus = sale.status;
                const updateData: any = {
                    amount_paid: newAmountPaid,
                    payment_status: newPaymentStatus,
                    updated_at: now,
                    payment_method: payment_method,
                };
                
                // Auto-complete logic
                if (newPaymentStatus === "paid") {
                    updateData.completed_at = now;
                    if (sale.status === "approved" || sale.status === "draft") {
                        updateData.status = "completed";
                        newStatus = "completed";
                    }
                }

                const { error: updateError } = await supabase
                    .from("sales")
                    .update(updateData)
                    .eq("id", saleId);

                if (updateError)
                    throw new Error(`Status update failed: ${updateError.message}`);

                // Auto-fulfill on first payment: if the sale was unfulfilled when
                // payment was recorded, mark it fulfilled and decrement stock now.
                // This prevents selling stock that has already been committed via payment.
                if (sale.fulfillment_status !== "fulfilled") {
                    const { error: fulfillError } = await supabase
                        .from("sales")
                        .update({
                            fulfillment_status: "fulfilled",
                            updated_at: now,
                        })
                        .eq("id", saleId);

                    if (fulfillError) throw new Error(`Fulfill on payment failed: ${fulfillError.message}`);

                    // Fetch sale items to decrement stock
                    const { data: saleItems } = await supabase
                        .from("sale_items")
                        .select("product_id, quantity")
                        .eq("sale_id", saleId);

                    for (const item of saleItems || []) {
                        await supabase.rpc("decrement_stock", {
                            p_product_id: item.product_id,
                            p_branch_id: sale.branch_id,
                            p_quantity: item.quantity,
                        });
                    }
                }

                return jsonResponse({
                    status: newStatus,
                    payment_status: newPaymentStatus,
                    amount_paid: newAmountPaid,
                    sale_id: saleId,
                });
            }

            case "create_credit_note": {
                const { original_sale_id, reason, items: cnItems, restock_items } = params;

                if (!original_sale_id || !reason || !cnItems?.length) {
                    throw new Error("Missing required credit note fields");
                }

                // Generate CN number
                const currentYear = new Date().getFullYear();
                const { data: seq, error: cnCounterError } = await supabase.rpc(
                    "next_invoice_number",
                    { p_tenant_id: tenantId, p_prefix: "CN", p_year: currentYear }
                );

                if (cnCounterError)
                    throw new Error(`CN number generation failed: ${cnCounterError.message}`);

                const creditNumber = `CN-${currentYear}-${String(seq).padStart(5, "0")}`;
                const cnId = crypto.randomUUID();
                const cnTotal = cnItems.reduce(
                    (sum: number, it: any) => sum + (it.total || 0),
                    0
                );

                const { error: cnError } = await supabase
                    .from("credit_notes")
                    .insert({
                        id: cnId,
                        tenant_id: tenantId,
                        sale_id: original_sale_id,
                        credit_number: creditNumber,
                        reason,
                        total: cnTotal,
                        status: "pending",
                        restock_items: restock_items || false,
                        created_by: user.id,
                        created_at: now,
                        updated_at: now,
                    });

                if (cnError)
                    throw new Error(`Credit note creation failed: ${cnError.message}`);

                // Insert CN items
                const creditItems = cnItems.map((item: any) => ({
                    id: crypto.randomUUID(),
                    credit_note_id: cnId,
                    product_id: item.product_id,
                    quantity: item.quantity,
                    unit_price: item.unit_price,
                    total: item.total,
                    created_at: now,
                }));

                await supabase.from("credit_note_items").insert(creditItems);

                return jsonResponse({
                    credit_note_id: cnId,
                    credit_number: creditNumber,
                    status: "pending",
                });
            }

            case "approve_credit_note": {
                const { credit_note_id } = params;

                const { data: cn } = await supabase
                    .from("credit_notes")
                    .select("*, credit_note_items(*), sales(branch_id)")
                    .eq("id", credit_note_id)
                    .single();

                if (!cn) throw new Error("Credit note not found");
                if (cn.status !== "pending") throw new Error("Credit note must be pending to be approved");

                const { error } = await supabase
                    .from("credit_notes")
                    .update({ status: "approved", updated_at: now })
                    .eq("id", credit_note_id);

                if (error) throw new Error(`CN approval failed: ${error.message}`);

                // Restock items if toggled
                if (cn.restock_items) {
                    for (const item of cn.credit_note_items || []) {
                        await supabase.rpc("increment_stock", {
                            p_product_id: item.product_id,
                            p_branch_id: cn.sales.branch_id,
                            p_quantity: item.quantity,
                        });
                    }
                }

                return jsonResponse({ status: "approved", credit_note_id });
            }

            case "apply_credit": {
                const { credit_note_id, target_sale_id } = params;

                const { data: cn } = await supabase
                    .from("credit_notes")
                    .select("*")
                    .eq("id", credit_note_id)
                    .single();

                if (!cn || cn.status !== "approved") {
                    throw new Error("Credit note not found or not approved");
                }

                // Update target sale directly to apply credit as payment
                const { data: targetSale } = await supabase
                    .from("sales")
                    .select("*")
                    .eq("id", target_sale_id)
                    .single();

                if (!targetSale) throw new Error("Target sale not found");

                const newAmountPaid = (targetSale.amount_paid || 0) + cn.total;
                const newStatus = newAmountPaid >= (targetSale.grand_total || 0) ? "paid" : "partially_paid";

                const { error: payError } = await supabase
                    .from("sales")
                    .update({
                        amount_paid: newAmountPaid,
                        status: newStatus,
                        payment_method: targetSale.payment_method || "credit_note",
                        updated_at: now,
                    })
                    .eq("id", target_sale_id);

                if (payError) throw new Error(`Credit application failed: ${payError.message}`);

                // Mark CN as applied
                await supabase
                    .from("credit_notes")
                    .update({ status: "applied", updated_at: now })
                    .eq("id", credit_note_id);

                return jsonResponse({ status: "applied", credit_note_id });
            }

            default:
                return new Response(
                    JSON.stringify({ error: `Unknown action: ${action}` }),
                    { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
                );
        }
    } catch (err: any) {
        console.error("manage-sale error:", err);
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
