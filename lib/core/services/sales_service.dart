import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/config/powersync.dart';
import 'package:zynk/core/services/app_logger.dart';
import 'package:zynk/features/pos/domain/pos_cart_item.dart';

final _log = AppLogger('SalesService');

/// Thin client service that delegates heavy operations to Supabase edge functions.
///
/// **Client-side:** Draft creation (offline-capable via PowerSync), data reads.
/// **Server-side (edge):** complete-sale, record-payment, manage-sale (approve/void/credit).
class SalesService {
  final SupabaseClient _supabase;

  SalesService(this._supabase);

  /// Ensures the session is fresh before making edge function calls.
  Future<void> _ensureSession() async {
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        throw Exception('Not authenticated. Please sign in again.');
      }
      // Refresh if token expires within the next 60 seconds
      final expiresAt = session.expiresAt;
      if (expiresAt != null) {
        final expiryTime = DateTime.fromMillisecondsSinceEpoch(
          expiresAt * 1000,
        );
        if (expiryTime.difference(DateTime.now()).inSeconds < 60) {
          _log.i('Session expiring soon, refreshing...');
          await _supabase.auth.refreshSession();
        }
      }
    } catch (e) {
      _log.e('Session refresh failed: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // POS: COMPLETE A WALK-IN SALE (one-tap, auto-flows all states)
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a completed sale with payment and stock decrement in one atomic
  /// server-side operation. Called when the cashier taps "Charge".
  Future<Map<String, dynamic>> completePOSSale({
    required String tenantId,
    required String branchId,
    String? customerId,
    required List<PosCartItem> cartItems,
    required String paymentMethod,
    String? paymentReference,
    String? notes,
  }) async {
    // Calculate totals client-side for the request
    double subtotal = 0;
    double taxAmount = 0;
    double discountAmount = 0;

    final items = cartItems.map((item) {
      final lineTotal = item.product.basePrice * item.quantity;
      subtotal += lineTotal;

      return {
        'product_id': item.product.id,
        'quantity': item.quantity,
        'unit_price': item.product.basePrice,
        'cost_price': item.product.costPrice ?? 0,
        'tax_amount': 0.0, // TODO: calculate from tax_category
        'discount': 0.0,
        'total': lineTotal,
      };
    }).toList();

    final grandTotal = subtotal + taxAmount - discountAmount;

    await _ensureSession();

    final payload = {
      'tenant_id': tenantId,
      'branch_id': branchId,
      'customer_id': customerId,
      'items': items,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'notes': notes,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'grand_total': grandTotal,
    };

    _log.i('Invoking complete-sale Edge Function...');
    _log.d('Payload: branch_id=$branchId, items_count=${items.length}');
    for (final i in items) {
      _log.d(' - Product: ${i['product_id']}, Qty: ${i['quantity']}');
    }

    final response = await _supabase.functions.invoke(
      'complete-sale',
      body: payload,
    );

    if (response.status >= 400) {
      final error = response.data is Map
          ? (response.data['error'] ?? 'Unknown error')
          : response.data?.toString() ?? 'Unknown error';
      _log.e('completePOSSale failed (${response.status}): $error');
      throw Exception('Sale failed: $error');
    }

    _log.i(
      'Sale completed: ${response.data['invoice_number']} '
      '(${response.data['sale_id']})',
    );

    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // B2B: CREATE AN INVOICE (draft, no payment, no stock decrement)
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a draft invoice LOCAL-FIRST via PowerSync.
  /// Does NOT decrement stock or record payment.
  Future<void> createDraftInvoiceLocal({
    required final String tenantId,
    required final String branchId,
    required final String customerId,
    required final List<PosCartItem> cartItems,
    final String? notes,
    final String? dueDate,
  }) async {
    // 1. Calculate totals
    double subtotal = 0;
    for (final item in cartItems) {
      subtotal += (item.product.basePrice * item.quantity);
    }
    // Hardcoded tax & discount mappings for now
    final double taxAmount = 0.0;
    final double discountAmount = 0.0;
    final double grandTotal = subtotal + taxAmount - discountAmount;

    // 2. Generate UUIDv7 for the Sale ID
    final saleId = const Uuid().v7();

    // We cannot reliably generate a sequential INV-xxx offline without conflicts,
    // so we set a temporary ID. The user expects it to start with INV-.
    final tempInvoiceNumber =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    // 3. Write locally
    final userId = _supabase.auth.currentUser!.id;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.writeTransaction((tx) async {
      // Insert Sale
      await tx.execute(
        '''
        INSERT INTO sales (
          id, tenant_id, branch_id, customer_id, invoice_number, sale_type, 
          created_by, total_amount, subtotal, tax_amount, discount_amount, 
          grand_total, amount_paid, payment_method, status, notes, due_date, 
          created_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
        ''',
        [
          saleId,
          tenantId,
          branchId,
          customerId,
          tempInvoiceNumber,
          'invoice',
          userId,
          grandTotal,
          subtotal,
          taxAmount,
          discountAmount,
          grandTotal,
          0.0,
          null,
          'draft',
          notes,
          dueDate,
          now,
          now,
        ],
      );

      // Insert Sale Items
      for (final item in cartItems) {
        final itemId = Uuid().v7();
        final unitPrice = item.product.basePrice;
        final costPrice = item.product.costPrice ?? 0.0;
        final lineTotal = unitPrice * item.quantity;

        // Skip items with quantity 0 just in case
        if (item.quantity <= 0) continue;

        await tx.execute(
          '''
          INSERT INTO sale_items (
            id, sale_id, product_id, tenant_id, quantity, unit_price, 
            cost_price, tax_amount, discount, total, created_at, updated_at
          ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
          )
          ''',
          [
            itemId,
            saleId,
            item.product.id,
            tenantId,
            item.quantity,
            unitPrice,
            costPrice,
            0.0,
            0.0,
            lineTotal,
            now,
            now,
          ],
        );
      }
    });

    _log.i('Draft invoice created offline: $saleId');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECORD PAYMENT (routed through manage-sale for permission checks)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> recordPayment({
    required String saleId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    return _manageSale('record_payment', {
      'sale_id': saleId,
      'amount': amount,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'notes': notes,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SALE MANAGEMENT (approve, reject, void, submit for approval)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> submitForApproval(String saleId) async {
    return _manageSale('submit_for_approval', {'sale_id': saleId});
  }

  Future<Map<String, dynamic>> approveSale(String saleId) async {
    return _manageSale('approve_sale', {'sale_id': saleId});
  }

  /// Fulfill an approved sale
  Future<Map<String, dynamic>> fulfillSale(String saleId) async {
    return _manageSale('fulfill_sale', {'sale_id': saleId});
  }

  Future<Map<String, dynamic>> rejectSale(
    String saleId, {
    String? reason,
  }) async {
    return _manageSale('reject_sale', {'sale_id': saleId, 'reason': reason});
  }

  Future<Map<String, dynamic>> voidSale(String saleId, {String? reason}) async {
    return _manageSale('void_sale', {'sale_id': saleId, 'reason': reason});
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
    await _ensureSession();

    final response = await _supabase.functions.invoke(
      'manage-sale',
      body: {'action': action, ...params},
    );

    if (response.status != 200) {
      final error = response.data?['error'] ?? 'Unknown error';
      _log.e('$action failed: $error');
      throw Exception('$action failed: $error');
    }

    _log.i('$action success: ${response.data}');
    return response.data as Map<String, dynamic>;
  }
}
