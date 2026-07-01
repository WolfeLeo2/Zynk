import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/utils/error_messages.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/services/app_logger.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';

final _log = AppLogger('SalesService');

/// Resolved pricing for a single invoice line.
/// [quantity] is the persisted unit count (boxes for sqm-based items),
/// [unitPrice] is the per-persisted-unit price (per box for sqm), and [total]
/// is `unitPrice * quantity`.
typedef InvoiceLine = ({int quantity, double unitPrice, double total});

/// Thin client service that delegates heavy operations to Supabase edge functions.
///
/// **Client-side:** Draft creation (offline-capable via PowerSync), data reads.
/// **Server-side (edge):** complete-sale, record-payment, manage-sale (approve/void/credit).
class SalesService {
  final SupabaseClient _supabase;

  SalesService(this._supabase);

  /// Single source of truth for invoice line-item pricing — used by the create,
  /// edit and clone screens so totals never drift between them.
  ///
  /// [enteredPrice] is the per-sqm price for sqm-based items, otherwise the unit
  /// price. [enteredQty] is the total sqm for sqm-based items, otherwise the
  /// unit count. sqm quantities are rounded UP to whole boxes.
  static InvoiceLine resolveLine({
    required bool isSqmBased,
    required double coveragePerBox,
    required double enteredPrice,
    required double enteredQty,
  }) {
    if (isSqmBased) {
      final coverage = coveragePerBox <= 0 ? 1.0 : coveragePerBox;
      final boxes = (enteredQty / coverage).ceil();
      final unitPrice = enteredPrice * coverage; // price per box
      return (quantity: boxes, unitPrice: unitPrice, total: unitPrice * boxes);
    }
    final qty = enteredQty.toInt();
    return (quantity: qty, unitPrice: enteredPrice, total: enteredPrice * qty);
  }

  /// Ensures the session is fresh before making edge function calls.
  Future<void> _ensureSession() async {
    final session = _supabase.auth.currentSession;
    if (session == null) {
      throw Exception('Not authenticated. Please sign in again.');
    }

    final expiresAt = session.expiresAt;
    if (expiresAt != null) {
      final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      if (expiryTime.difference(DateTime.now()).inSeconds < 60) {
        _log.i('Session expiring soon, refreshing...');
        await _refreshAndValidateSession();
        return;
      }
    }

    try {
      final userResponse = await _supabase.auth.getUser();
      if (userResponse.user == null) {
        await _refreshAndValidateSession();
      }
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('jwt') ||
          message.contains('token') ||
          message.contains('auth')) {
        await _refreshAndValidateSession();
        return;
      }
      _log.e('Session validation failed: $e');
      rethrow;
    }
  }

  Future<void> _refreshAndValidateSession() async {
    try {
      final refreshed = await _supabase.auth.refreshSession();
      if (refreshed.session == null) {
        throw Exception('Session refresh returned null session');
      }

      final userResponse = await _supabase.auth.getUser();
      if (userResponse.user == null) {
        throw Exception('Session refresh did not yield a valid user');
      }
    } catch (e) {
      _log.e('Session refresh failed: $e');
      throw Exception(
        'Your session is invalid or expired. Please sign out and sign in again.',
      );
    }
  }

  Future<dynamic> _invokeEdgeFunction(
    String functionName, {
    required Map<String, dynamic> body,
  }) async {
    await _ensureSession();

    // functions.invoke throws FunctionException on any non-2xx. On a 401 we
    // refresh the session and retry once; otherwise surface a friendly message.
    try {
      return await _supabase.functions.invoke(functionName, body: body);
    } on FunctionException catch (e) {
      if (e.status == 401) {
        _log.i('$functionName returned 401, refreshing session and retrying');
        await _refreshAndValidateSession();
        try {
          return await _supabase.functions.invoke(functionName, body: body);
        } on FunctionException catch (e2) {
          throw Exception(friendlyError(e2));
        }
      }
      throw Exception(friendlyError(e));
    }
  }

  void _throwAuthAwareError({
    required int? status,
    required dynamic data,
    required String action,
  }) {
    final raw =
        (data is Map<String, dynamic>
                ? data['error'] ?? data['message'] ?? data['msg']
                : data)
            ?.toString();
    final normalized = (raw ?? '').toLowerCase();

    if (status == 401 ||
        normalized.contains('invalid jwt') ||
        normalized.contains('jwt')) {
      throw Exception(
        'Session invalid for $action. Please sign out and sign in again.',
      );
    }

    throw Exception('$action failed: ${raw ?? 'Unknown error'}');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POS: All sales now go through the invoice flow.
  // The complete-sale edge function is kept for API/backward compatibility
  // but is no longer called from the Flutter app.
  // ─────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────
  // B2B: CREATE AN INVOICE (pending approval, no payment, no stock decrement)
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a pending-approval invoice through the authoritative server write path.
  Future<void> createPendingApprovalInvoiceLocal({
    required final String tenantId,
    required final String branchId,
    required final String customerId,
    required final List<PosCartItem> cartItems,
    final String? salespersonId,
    final String? notes,
    final String? dueDate,
  }) async {
    await _ensureSession();

    // 1. Calculate totals
    double subtotal = 0;
    final payloadItems = <Map<String, dynamic>>[];

    for (final item in cartItems) {
      if (item.quantity <= 0) continue;
      final lineTotal = item.effectivePrice * item.quantity;
      subtotal += lineTotal;
      payloadItems.add({
        'product_id': item.product.id,
        'quantity': item.quantity,
        'unit_price': item.effectivePrice,
        'cost_price': item.product.costPrice ?? 0.0,
        'tax_amount': 0.0,
        'discount': 0.0,
        'total': lineTotal,
        'product_name': item.effectiveName,
      });
    }

    if (payloadItems.isEmpty) {
      throw Exception('No invoice items to submit.');
    }

    // Hardcoded tax & discount mappings for now
    final double taxAmount = 0.0;
    final double discountAmount = 0.0;
    final double grandTotal = subtotal + taxAmount - discountAmount;

    // 2. Create pending-approval invoice server-side (authoritative write path)
    final response = await _invokeEdgeFunction(
      'create-invoice',
      body: {
        'tenant_id': tenantId,
        'branch_id': branchId,
        'customer_id': customerId,
        'salesperson_id': salespersonId,
        'items': payloadItems,
        'notes': notes,
        'due_date': dueDate,
        'subtotal': subtotal,
        'tax_amount': taxAmount,
        'discount_amount': discountAmount,
        'grand_total': grandTotal,
      },
    );

    if (response.status != 200) {
      _throwAuthAwareError(
        status: response.status,
        data: response.data,
        action: 'create-invoice',
      );
    }

    final payload = response.data as Map<String, dynamic>? ?? {};
    final saleId = payload['sale_id'] as String?;
    if (saleId == null || saleId.isEmpty) {
      throw Exception('create-invoice did not return sale_id');
    }

    _log.i('Pending-approval invoice created server-side: $saleId');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECORD PAYMENT (Server-authoritative)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> recordPayment({
    required String saleId,
    required String tenantId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
    bool allowOverpayment = false,
  }) async {
    // Stable idempotency key: a 401-refresh retry re-sends the same body, so a
    // network retry can't double-charge or double-release stock.
    final paymentId = const Uuid().v4();
    await _manageSale('record_payment', {
      'sale_id': saleId,
      'tenant_id': tenantId,
      'payment_id': paymentId,
      'amount': amount,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'notes': notes,
      'allow_overpayment': allowOverpayment,
    });
    _log.i('Payment of \$amount recorded server-side for sale: \$saleId');
  }

  /// Updates a pending invoice header and items server-side.
  Future<Map<String, dynamic>> updateDraftInvoice({
    required String saleId,
    required String tenantId,
    required String customerId,
    required List<SaleItem> items,
    String? salespersonId,
    String? notes,
    String? dueDate,
  }) async {
    return _manageSale('update_draft', {
      'sale_id': saleId,
      'tenant_id': tenantId,
      'customer_id': customerId,
      'salesperson_id': salespersonId,
      'notes': notes,
      'due_date': dueDate,
      'items': items
          .map(
            (item) => {
              'id': item.id,
              'product_id': item.productId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'cost_price': item.costPrice,
              'tax_amount': item.taxAmount,
              'discount': item.discount,
              'total': item.total,
              'product_name': item.productName,
            },
          )
          .toList(),
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SALE MANAGEMENT (approve, reject, void, submit for approval)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitForApproval(
    String saleId, {
    required String tenantId,
  }) async {
    return _manageSale('submit_for_approval', {
      'sale_id': saleId,
      'tenant_id': tenantId,
    });
  }

  Future<Map<String, dynamic>> cloneInvoice(
    String saleId, {
    required String tenantId,
  }) async {
    return _manageSale('clone_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
    });
  }

  Future<Map<String, dynamic>> approveSale(
    String saleId, {
    required String tenantId,
  }) async {
    return _manageSale('approve_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
    });
  }

  /// Fulfill an active sale (non-voided / non-rejected)
  Future<Map<String, dynamic>> fulfillSale(
    String saleId, {
    required String tenantId,
  }) async {
    return _manageSale('fulfill_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
    });
  }

  Future<Map<String, dynamic>> rejectSale(
    String saleId, {
    required String tenantId,
    String? reason,
  }) async {
    return _manageSale('reject_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
      'reason': reason,
    });
  }

  /// Reverts an approved invoice back to pending_approval.
  /// Reverses stock (if fulfilled) and deletes all recorded payments.
  /// Available to anyone with the approve_invoices permission.
  Future<Map<String, dynamic>> unapproveSale(
    String saleId, {
    required String tenantId,
  }) async {
    return _manageSale('unapprove_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
    });
  }

  /// Fast-track approves a pending invoice, bypassing the dual-approval requirement.
  /// Available to anyone with the approve_invoices permission.
  Future<Map<String, dynamic>> finalApproveSale(
    String saleId, {
    required String tenantId,
  }) async {
    return _manageSale('final_approve_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
    });
  }

  Future<Map<String, dynamic>> voidSale(
    String saleId, {
    required String tenantId,
    String? reason,
  }) async {
    return _manageSale('void_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
      'reason': reason,
    });
  }

  /// Delete a payment from a sale (admin only).
  /// Recalculates amount_paid and may reverse fulfillment.
  Future<Map<String, dynamic>> deletePayment({
    required String saleId,
    required String paymentId,
    required String tenantId,
  }) async {
    return _manageSale('delete_payment', {
      'sale_id': saleId,
      'payment_id': paymentId,
      'tenant_id': tenantId,
    });
  }

  /// Delete a sale entirely (admin only).
  /// Reverses stock if fulfilled, removes all child records.
  Future<Map<String, dynamic>> deleteSale({
    required String saleId,
    required String tenantId,
  }) async {
    return _manageSale('delete_sale', {
      'sale_id': saleId,
      'tenant_id': tenantId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREDIT NOTES
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createCreditNote({
    required String tenantId,
    String? branchId,
    required String originalSaleId,
    required String reason,
    required List<CreditNoteItem> items,
    bool restockItems = false,
  }) async {
    return _manageSale('create_credit_note', {
      'tenant_id': tenantId,
      'branch_id': branchId,
      'sale_id': originalSaleId,
      'original_sale_id': originalSaleId,
      'reason': reason,
      'items': items.map((i) => i.toMap()).toList(),
      'restock_items': restockItems,
    });
  }

  Future<Map<String, dynamic>> approveCreditNote(String creditNoteId) async {
    return _manageSale('approve_credit_note', {'credit_note_id': creditNoteId});
  }

  Future<Map<String, dynamic>> applyCreditToSale({
    required String creditNoteId,
    required String targetSaleId,
  }) async {
    return _manageSale('apply_credit', {
      'credit_note_id': creditNoteId,
      'target_sale_id': targetSaleId,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PRIVATE HELPER
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _manageSale(
    String action,
    Map<String, dynamic> params,
  ) async {
    final response = await _invokeEdgeFunction(
      'manage-sale',
      body: {'action': action, ...params},
    );

    if (response.status != 200) {
      _log.e('$action failed: ${response.data}');
      _throwAuthAwareError(
        status: response.status,
        data: response.data,
        action: action,
      );
    }

    _log.i('$action success: ${response.data}');
    return response.data as Map<String, dynamic>;
  }
}
