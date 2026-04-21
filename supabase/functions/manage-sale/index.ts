import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Permission required for each action
const ACTION_PERMISSIONS: Record<string, string> = {
    update_draft: "create_invoices",
    clone_sale: "create_invoices",
    record_payment: "record_payments",
    approve_sale: "approve_invoices",
    reject_sale: "approve_invoices",
    void_sale: "void_sales",
    create_credit_note: "issue_credit_notes",
    approve_credit_note: "approve_invoices",
    apply_credit: "issue_credit_notes",
    submit_for_approval: "create_invoices",
    fulfill_sale: "record_payments",
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
        const token = authHeader.replace(/^Bearer\s+/i, "").trim();
        if (!token) {
            return new Response(JSON.stringify({ error: "Missing bearer token" }), {
                status: 401,
                headers: { ...corsHeaders, "Content-Type": "application/json" },
            });
        }

        const userId = parseJwtUserId(token);
        if (!userId) {
            console.error("manage-sale auth failed", {
                hasAuthHeader: Boolean(authHeader),
                reason: "invalid_jwt_payload",
            });
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
        // (e.g. approving an invoice that may not have synced to Supabase yet).
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
            .eq("user_id", userId)
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

                if (sale.status !== "pending_approval") {
                    throw new Error("Only pending approval invoices can be edited");
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
                // Backward compatibility: invoices are now created directly in pending_approval.
                return jsonResponse({ status: "pending_approval", sale_id: saleId });
            }

            case "clone_sale": {
                const sourceSaleId = saleId;

                const { data: sourceSale, error: sourceSaleError } = await supabase
                    .from("sales")
                    .select("*")
                    .eq("id", sourceSaleId)
                    .single();

                if (sourceSaleError || !sourceSale) {
                    throw new Error("Source sale not found");
                }

                if (sourceSale.tenant_id !== tenantId) {
                    throw new Error("Source sale tenant mismatch");
                }

                const { data: sourceItems, error: sourceItemsError } = await supabase
                    .from("sale_items")
                    .select("*")
                    .eq("sale_id", sourceSaleId);

                if (sourceItemsError) {
                    throw new Error(`Source sale items lookup failed: ${sourceItemsError.message}`);
                }

                if (!sourceItems || sourceItems.length === 0) {
                    throw new Error("Source sale has no items to clone");
                }

                const currentYear = new Date().getFullYear();
                const { data: seq, error: counterError } = await supabase.rpc(
                    "next_invoice_number",
                    { p_tenant_id: tenantId, p_prefix: "INV", p_year: currentYear }
                );

                if (counterError) {
                    throw new Error(`Invoice number generation failed: ${counterError.message}`);
                }

                const invoiceNumber = `INV-${currentYear}-${String(seq).padStart(5, "0")}`;
                const newSaleId = crypto.randomUUID();

                const { error: insertSaleError } = await supabase
                    .from("sales")
                    .insert({
                        id: newSaleId,
                        tenant_id: tenantId,
                        branch_id: sourceSale.branch_id,
                        customer_id: sourceSale.customer_id,
                        invoice_number: invoiceNumber,
                        sale_type: sourceSale.sale_type || "invoice",
                        created_by: userId,
                        salesperson_id: sourceSale.salesperson_id,
                        approved_by: null,
                        subtotal: Number(sourceSale.subtotal || 0),
                        tax_amount: Number(sourceSale.tax_amount || 0),
                        discount_amount: Number(sourceSale.discount_amount || 0),
                        grand_total: Number(sourceSale.grand_total || 0),
                        total_amount: Number(sourceSale.total_amount || sourceSale.grand_total || 0),
                        amount_paid: 0,
                        payment_method: null,
                        payment_status: "unpaid",
                        fulfillment_status: "unfulfilled",
                        status: "pending_approval",
                        notes: sourceSale.notes || null,
                        due_date: sourceSale.due_date || null,
                        completed_at: null,
                        voided_at: null,
                        void_reason: null,
                        external_ref: null,
                        created_at: now,
                        updated_at: now,
                    });

                if (insertSaleError) {
                    throw new Error(`Clone sale insert failed: ${insertSaleError.message}`);
                }

                const clonedItems = sourceItems.map((item: any) => ({
                    id: crypto.randomUUID(),
                    sale_id: newSaleId,
                    tenant_id: tenantId,
                    product_id: item.product_id,
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

                const { error: insertItemsError } = await supabase
                    .from("sale_items")
                    .insert(clonedItems);

                if (insertItemsError) {
                    await supabase.from("sales").delete().eq("id", newSaleId);
                    throw new Error(`Clone sale items insert failed: ${insertItemsError.message}`);
                }

                return jsonResponse({
                    sale_id: newSaleId,
                    invoice_number: invoiceNumber,
                    status: "pending_approval",
                });
            }

            case "approve_sale": {
                const { data: sale } = await supabase
                    .from("sales")
                    .select("id, tenant_id, status, payment_status, fulfillment_status, required_approvals, approval_count")
                    .eq("id", saleId)
                    .single();

                if (!sale) {
                    throw new Error("Sale not found in backend. Ensure the invoice has synced.");
                }
                
                if (sale.status !== "pending_approval") {
                    throw new Error(`Sale (${sale.status}) must be pending approval to be approved`);
                }

                const { error: approvalInsertError } = await supabase
                    .from("sale_approvals")
                    .insert({
                        id: crypto.randomUUID(),
                        sale_id: saleId,
                        tenant_id: tenantId,
                        approver_user_id: userId,
                        decision: "approved",
                        notes: params.notes || null,
                        created_at: now,
                    });

                if (approvalInsertError) {
                    if (approvalInsertError.code === "23505") {
                        throw new Error("You have already approved this invoice.");
                    }
                    throw new Error(`Approval record failed: ${approvalInsertError.message}`);
                }

                const { count: approvalCount, error: approvalCountError } = await supabase
                    .from("sale_approvals")
                    .select("id", { count: "exact", head: true })
                    .eq("sale_id", saleId)
                    .eq("decision", "approved");

                if (approvalCountError) {
                    throw new Error(`Approval count failed: ${approvalCountError.message}`);
                }

                const requiredApprovals = Math.max(1, Number(sale.required_approvals || 2));
                const nextApprovalCount = Math.min(requiredApprovals, Number(approvalCount || 0));
                const isFinalApproval = nextApprovalCount >= requiredApprovals;

                const updateData: any = {
                    approval_count: nextApprovalCount,
                    status: isFinalApproval ? "approved" : "pending_approval",
                    approved_by: isFinalApproval ? userId : null,
                    updated_at: now,
                };

                if (isFinalApproval && sale.payment_status === "paid" && sale.fulfillment_status === "fulfilled") {
                    updateData.completed_at = now;
                }

                const { error } = await supabase
                    .from("sales")
                    .update(updateData)
                    .eq("id", saleId);

                if (error) throw new Error(`Approve failed: ${error.message}`);

                return jsonResponse({
                    status: isFinalApproval ? "approved" : "pending_approval",
                    sale_id: saleId,
                    approval_count: nextApprovalCount,
                    required_approvals: requiredApprovals,
                });
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

                if (sale.status === "voided" || sale.status === "rejected") {
                    throw new Error("Voided or rejected invoices cannot be released");
                }

                const decrementedItems: Array<{ product_id: string; quantity: number }> = [];

                // Decrement stock before flipping the release flag.
                for (const item of sale.sale_items || []) {
                    const quantity = Number(item.quantity || 0);
                    if (quantity <= 0) continue;

                    const { error: decrementError } = await supabase.rpc("decrement_stock", {
                        p_product_id: item.product_id,
                        p_branch_id: sale.branch_id,
                        p_quantity: quantity,
                    });

                    if (decrementError) {
                        for (const reverted of decrementedItems) {
                            await supabase.rpc("increment_stock", {
                                p_product_id: reverted.product_id,
                                p_branch_id: sale.branch_id,
                                p_quantity: reverted.quantity,
                            });
                        }
                        throw new Error(`Stock release failed: ${decrementError.message}`);
                    }

                    decrementedItems.push({
                        product_id: item.product_id,
                        quantity,
                    });
                }

                const updateData: any = {
                    fulfillment_status: "fulfilled",
                    updated_at: now,
                };

                if (sale.payment_status === "paid") {
                    updateData.completed_at = now;
                }

                const { error } = await supabase
                    .from("sales")
                    .update(updateData)
                    .eq("id", saleId);

                if (error) {
                    for (const reverted of decrementedItems) {
                        await supabase.rpc("increment_stock", {
                            p_product_id: reverted.product_id,
                            p_branch_id: sale.branch_id,
                            p_quantity: reverted.quantity,
                        });
                    }
                    throw new Error(`Fulfill failed: ${error.message}`);
                }

                return jsonResponse({ fulfillment_status: "fulfilled", sale_id: saleId });
            }

            case "reject_sale": {
                const { data: existingSale } = await supabase
                    .from("sales")
                    .select("id, status")
                    .eq("id", saleId)
                    .single();

                if (!existingSale) {
                    throw new Error("Sale not found");
                }

                if (existingSale.status !== "pending_approval") {
                    throw new Error(`Sale (${existingSale.status}) must be pending approval to be rejected`);
                }

                const { error: rejectRecordError } = await supabase
                    .from("sale_approvals")
                    .insert({
                        id: crypto.randomUUID(),
                        sale_id: saleId,
                        tenant_id: tenantId,
                        approver_user_id: userId,
                        decision: "rejected",
                        notes: params.reason || "Rejected",
                        created_at: now,
                    });

                if (rejectRecordError) {
                    if (rejectRecordError.code === "23505") {
                        throw new Error("You have already made a decision on this invoice.");
                    }
                    throw new Error(`Reject record failed: ${rejectRecordError.message}`);
                }

                const { error } = await supabase
                    .from("sales")
                    .update({
                        status: "rejected",
                        approved_by: userId,
                        approval_count: 0,
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
                if (sale.status === "voided" || sale.status === "rejected") {
                    throw new Error("Cannot void a rejected or already voided sale");
                }

                if ((sale.amount_paid || 0) > 0) {
                    throw new Error("Cannot void a sale with recorded payments. Delete payments first.");
                }

                const restockedItems: Array<{ product_id: string; quantity: number }> = [];

                // Reverse stock if it was fulfilled
                if (sale.fulfillment_status === 'fulfilled') {
                    for (const item of sale.sale_items || []) {
                        const quantity = Number(item.quantity || 0);
                        if (quantity <= 0) continue;

                        const { error: incrementError } = await supabase.rpc("increment_stock", {
                            p_product_id: item.product_id,
                            p_branch_id: sale.branch_id,
                            p_quantity: quantity,
                        });

                        if (incrementError) {
                            for (const reverted of restockedItems) {
                                await supabase.rpc("decrement_stock", {
                                    p_product_id: reverted.product_id,
                                    p_branch_id: sale.branch_id,
                                    p_quantity: reverted.quantity,
                                });
                            }
                            throw new Error(`Stock rollback failed: ${incrementError.message}`);
                        }

                        restockedItems.push({
                            product_id: item.product_id,
                            quantity,
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

                if (error) {
                    for (const reverted of restockedItems) {
                        await supabase.rpc("decrement_stock", {
                            p_product_id: reverted.product_id,
                            p_branch_id: sale.branch_id,
                            p_quantity: reverted.quantity,
                        });
                    }
                    throw new Error(`Void failed: ${error.message}`);
                }
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

                const paymentId = crypto.randomUUID();

                // Insert payment
                const { error: payError } = await supabase
                    .from("sale_payments")
                    .insert({
                        id: paymentId,
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

                // Auto-release goods on first payment so stock is decremented immediately.
                let fulfillmentStatus = sale.fulfillment_status;
                let releasedNow = false;
                const decrementedItems: Array<{ product_id: string; quantity: number }> = [];

                if (sale.fulfillment_status !== "fulfilled") {
                    const { data: saleItems, error: saleItemsError } = await supabase
                        .from("sale_items")
                        .select("product_id, quantity")
                        .eq("sale_id", saleId);

                    if (saleItemsError) {
                        await supabase.from("sale_payments").delete().eq("id", paymentId);
                        throw new Error(`Sale items lookup failed: ${saleItemsError.message}`);
                    }

                    for (const item of saleItems || []) {
                        const quantity = Number(item.quantity || 0);
                        if (quantity <= 0) continue;

                        const { error: decrementError } = await supabase.rpc("decrement_stock", {
                            p_product_id: item.product_id,
                            p_branch_id: sale.branch_id,
                            p_quantity: quantity,
                        });

                        if (decrementError) {
                            for (const reverted of decrementedItems) {
                                await supabase.rpc("increment_stock", {
                                    p_product_id: reverted.product_id,
                                    p_branch_id: sale.branch_id,
                                    p_quantity: reverted.quantity,
                                });
                            }
                            await supabase.from("sale_payments").delete().eq("id", paymentId);
                            throw new Error(`Stock release failed: ${decrementError.message}`);
                        }

                        decrementedItems.push({
                            product_id: item.product_id,
                            quantity,
                        });
                    }

                    fulfillmentStatus = "fulfilled";
                    releasedNow = true;
                }

                const updateData: any = {
                    amount_paid: newAmountPaid,
                    payment_status: newPaymentStatus,
                    fulfillment_status: fulfillmentStatus,
                    updated_at: now,
                    payment_method: payment_method,
                };

                if (newPaymentStatus === "paid" && fulfillmentStatus === "fulfilled") {
                    updateData.completed_at = now;
                }

                const { error: updateError } = await supabase
                    .from("sales")
                    .update(updateData)
                    .eq("id", saleId);

                if (updateError) {
                    if (releasedNow) {
                        for (const reverted of decrementedItems) {
                            await supabase.rpc("increment_stock", {
                                p_product_id: reverted.product_id,
                                p_branch_id: sale.branch_id,
                                p_quantity: reverted.quantity,
                            });
                        }
                    }
                    await supabase.from("sale_payments").delete().eq("id", paymentId);
                    throw new Error(`Status update failed: ${updateError.message}`);
                }

                return jsonResponse({
                    status: sale.status,
                    payment_status: newPaymentStatus,
                    amount_paid: newAmountPaid,
                    fulfillment_status: fulfillmentStatus,
                    sale_id: saleId,
                });
            }

            case "create_credit_note": {
                const { original_sale_id, reason, items: cnItems, restock_items } = params;

                if (!original_sale_id || !reason || !cnItems?.length) {
                    throw new Error("Missing required credit note fields");
                }

                const { data: originalSale, error: originalSaleError } = await supabase
                    .from("sales")
                    .select("id, tenant_id, branch_id")
                    .eq("id", original_sale_id)
                    .single();

                if (originalSaleError || !originalSale) {
                    throw new Error("Original sale not found");
                }

                if (originalSale.tenant_id !== tenantId) {
                    throw new Error("Original sale tenant mismatch");
                }

                const normalizedItems = (cnItems as any[])
                    .filter((item) => Number(item.quantity || 0) > 0)
                    .map((item) => ({
                        product_id: item.product_id,
                        product_name: item.product_name || null,
                        quantity: Number(item.quantity || 0),
                        unit_price: Number(item.unit_price || 0),
                        tax_amount: Number(item.tax_amount || 0),
                        total: Number(item.total || 0),
                    }));

                if (!normalizedItems.length) {
                    throw new Error("Credit note must include at least one item");
                }

                const cnSubtotal = normalizedItems.reduce(
                    (sum: number, it: any) => sum + (it.unit_price * it.quantity),
                    0
                );
                const cnTax = normalizedItems.reduce(
                    (sum: number, it: any) => sum + (it.tax_amount || 0),
                    0
                );
                const cnTotal = normalizedItems.reduce(
                    (sum: number, it: any) => sum + (it.total || 0),
                    0
                );

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
                const resolvedBranchId = params.branch_id || originalSale.branch_id || null;

                const { error: cnError } = await supabase
                    .from("credit_notes")
                    .insert({
                        id: cnId,
                        tenant_id: tenantId,
                        branch_id: resolvedBranchId,
                        original_sale_id,
                        credit_number: creditNumber,
                        reason,
                        items: normalizedItems,
                        subtotal: cnSubtotal,
                        tax_amount: cnTax,
                        total: cnTotal,
                        status: "pending_approval",
                        restock_items: Boolean(restock_items),
                        created_by: userId,
                        created_at: now,
                        updated_at: now,
                    });

                if (cnError)
                    throw new Error(`Credit note creation failed: ${cnError.message}`);

                // Insert CN items
                const creditItems = normalizedItems.map((item: any) => ({
                    id: crypto.randomUUID(),
                    credit_note_id: cnId,
                    product_id: item.product_id,
                    product_name: item.product_name || null,
                    quantity: item.quantity,
                    unit_price: item.unit_price,
                    tax_amount: item.tax_amount,
                    total: item.total,
                    tenant_id: tenantId,
                    created_at: now,
                }));

                const { error: creditItemsError } = await supabase
                    .from("credit_note_items")
                    .insert(creditItems);

                if (creditItemsError) {
                    await supabase.from("credit_notes").delete().eq("id", cnId);
                    throw new Error(`Credit note items failed: ${creditItemsError.message}`);
                }

                return jsonResponse({
                    credit_note_id: cnId,
                    credit_number: creditNumber,
                    status: "pending_approval",
                });
            }

            case "approve_credit_note": {
                const { credit_note_id } = params;

                const { data: cn } = await supabase
                    .from("credit_notes")
                    .select("id, status, restock_items, branch_id, original_sale_id")
                    .eq("id", credit_note_id)
                    .single();

                if (!cn) throw new Error("Credit note not found");
                if (cn.status !== "pending_approval") {
                    throw new Error("Credit note must be pending approval to be approved");
                }

                const { data: cnItems, error: cnItemsError } = await supabase
                    .from("credit_note_items")
                    .select("product_id, quantity")
                    .eq("credit_note_id", credit_note_id);

                if (cnItemsError) {
                    throw new Error(`Credit note items lookup failed: ${cnItemsError.message}`);
                }

                const { data: originalSale } = await supabase
                    .from("sales")
                    .select("branch_id")
                    .eq("id", cn.original_sale_id)
                    .single();

                const branchForStock = cn.branch_id || originalSale?.branch_id;

                const restockedItems: Array<{ product_id: string; quantity: number }> = [];

                // Restock items (if toggled) before marking as approved.
                if (cn.restock_items) {
                    if (!branchForStock) {
                        throw new Error("Missing branch context for restock");
                    }

                    for (const item of cnItems || []) {
                        const quantity = Number(item.quantity || 0);
                        if (quantity <= 0) continue;

                        const { error: incrementError } = await supabase.rpc("increment_stock", {
                            p_product_id: item.product_id,
                            p_branch_id: branchForStock,
                            p_quantity: quantity,
                        });

                        if (incrementError) {
                            for (const reverted of restockedItems) {
                                await supabase.rpc("decrement_stock", {
                                    p_product_id: reverted.product_id,
                                    p_branch_id: branchForStock,
                                    p_quantity: reverted.quantity,
                                });
                            }
                            throw new Error(`Restock failed: ${incrementError.message}`);
                        }

                        restockedItems.push({
                            product_id: item.product_id,
                            quantity,
                        });
                    }
                }

                const { error } = await supabase
                    .from("credit_notes")
                    .update({ status: "approved", approved_by: userId, updated_at: now })
                    .eq("id", credit_note_id);

                if (error) {
                    if (branchForStock) {
                        for (const reverted of restockedItems) {
                            await supabase.rpc("decrement_stock", {
                                p_product_id: reverted.product_id,
                                p_branch_id: branchForStock,
                                p_quantity: reverted.quantity,
                            });
                        }
                    }
                    throw new Error(`CN approval failed: ${error.message}`);
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

                if (targetSale.status === "voided" || targetSale.status === "rejected") {
                    throw new Error("Credits cannot be applied to voided or rejected invoices");
                }

                if (targetSale.payment_status === "paid") {
                    throw new Error("Cannot apply credit to a fully paid invoice");
                }

                const remainingBalance = Math.max(
                    0,
                    Number(targetSale.grand_total || 0) - Number(targetSale.amount_paid || 0)
                );
                const creditAmount = Number(cn.total || 0);
                const appliedAmount = Math.min(creditAmount, remainingBalance);

                if (appliedAmount <= 0) {
                    throw new Error("No remaining balance to apply credit against");
                }

                const { error: paymentInsertError } = await supabase
                    .from("sale_payments")
                    .insert({
                        id: crypto.randomUUID(),
                        sale_id: target_sale_id,
                        tenant_id: targetSale.tenant_id,
                        branch_id: targetSale.branch_id,
                        amount: appliedAmount,
                        payment_method: "credit_note",
                        reference_number: cn.credit_number || credit_note_id,
                        notes: `Applied credit note ${cn.credit_number || credit_note_id}`,
                        created_at: now,
                        updated_at: now,
                    });

                if (paymentInsertError) {
                    throw new Error(`Credit payment insert failed: ${paymentInsertError.message}`);
                }

                const newAmountPaid = Number(targetSale.amount_paid || 0) + appliedAmount;
                const newPaymentStatus = newAmountPaid >= (targetSale.grand_total || 0) ? "paid" : "partially_paid";

                const updateData: any = {
                    amount_paid: newAmountPaid,
                    payment_status: newPaymentStatus,
                    payment_method: "credit_note",
                    updated_at: now,
                };

                if (newPaymentStatus === "paid" && targetSale.fulfillment_status === "fulfilled") {
                    updateData.completed_at = now;
                }

                const { error: payError } = await supabase
                    .from("sales")
                    .update(updateData)
                    .eq("id", target_sale_id);

                if (payError) throw new Error(`Credit application failed: ${payError.message}`);

                // Mark CN as applied
                const { error: cnApplyError } = await supabase
                    .from("credit_notes")
                    .update({
                        status: "applied",
                        applied_to_sale_id: target_sale_id,
                        updated_at: now,
                    })
                    .eq("id", credit_note_id);

                if (cnApplyError) {
                    throw new Error(`Credit note update failed: ${cnApplyError.message}`);
                }

                return jsonResponse({ status: "applied", payment_status: newPaymentStatus, credit_note_id });
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
