// NOTE: 'dart:convert' no longer needed — credit note items use a junction table.

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

enum FulfillmentStatus {
  unreleased,
  released;

  /// DB value — kept stable (do NOT change these)
  String get value =>
      this == FulfillmentStatus.unreleased ? 'unfulfilled' : 'fulfilled';

  String get displayName =>
      this == FulfillmentStatus.released ? 'Released' : 'Unreleased';

  static FulfillmentStatus fromString(String? status) {
    if (status?.toLowerCase() == 'fulfilled') {
      return FulfillmentStatus.released;
    }
    return FulfillmentStatus.unreleased;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT STATUS
// ─────────────────────────────────────────────────────────────────────────────

enum PaymentStatus {
  unpaid,
  partiallyPaid,
  paid;

  String get value {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'unpaid';
      case PaymentStatus.partiallyPaid:
        return 'partially_paid';
      case PaymentStatus.paid:
        return 'paid';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.paid:
        return 'Paid';
    }
  }

  static PaymentStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'partially_paid':
        return PaymentStatus.partiallyPaid;
      case 'paid':
        return PaymentStatus.paid;
      case 'unpaid':
      default:
        return PaymentStatus.unpaid;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INVOICE STATUS
// ─────────────────────────────────────────────────────────────────────────────

enum InvoiceStatus {
  draft,
  pendingApproval,
  approved,
  rejected,
  partiallyPaid, // Legacy, kept for safe parsing
  paid,          // Legacy, kept for safe parsing
  completed,
  voided;

  String get value {
    switch (this) {
      case InvoiceStatus.draft:
        return 'draft';
      case InvoiceStatus.pendingApproval:
        return 'pending_approval';
      case InvoiceStatus.approved:
        return 'approved';
      case InvoiceStatus.rejected:
        return 'rejected';
      case InvoiceStatus.partiallyPaid:
        return 'partially_paid';
      case InvoiceStatus.paid:
        return 'paid';
      case InvoiceStatus.completed:
        return 'completed';
      case InvoiceStatus.voided:
        return 'voided';
    }
  }

  String get displayName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.pendingApproval:
        return 'Pending Approval';
      case InvoiceStatus.approved:
        return 'Approved';
      case InvoiceStatus.rejected:
        return 'Rejected';
      case InvoiceStatus.partiallyPaid:
        return 'Partially Paid (Legacy)';
      case InvoiceStatus.paid:
        return 'Paid (Legacy)';
      case InvoiceStatus.completed:
        return 'Completed';
      case InvoiceStatus.voided:
        return 'Voided';
    }
  }

  bool get isTerminal =>
      this == InvoiceStatus.completed || this == InvoiceStatus.voided;

  bool get canBeApproved => this == InvoiceStatus.pendingApproval;

  /// Paid and completed invoices cannot be voided.
  /// Admin must delete payments first to unlock voiding.
  bool get canBeVoided =>
      this != InvoiceStatus.paid &&
      this != InvoiceStatus.completed &&
      this != InvoiceStatus.voided;

  static InvoiceStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return InvoiceStatus.draft;
      case 'pending_approval':
        return InvoiceStatus.pendingApproval;
      case 'approved':
        return InvoiceStatus.approved;
      case 'rejected':
        return InvoiceStatus.rejected;
      case 'partially_paid':
        return InvoiceStatus.partiallyPaid;
      case 'paid':
        return InvoiceStatus.paid;
      case 'completed':
        return InvoiceStatus.completed;
      case 'voided':
        return InvoiceStatus.voided;
      default:
        return InvoiceStatus.draft;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE MODEL (Invoice)
// ─────────────────────────────────────────────────────────────────────────────

class Sale {
  final String id;
  final String tenantId;
  final String branchId;
  final String? customerId;
  final String? invoiceNumber;
  final String saleType;
  final String? createdBy;
  final String? salespersonName;
  final String? approvedBy;
  final double totalAmount;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;
  final double amountPaid;
  final String? paymentMethod;
  final InvoiceStatus status;
  final PaymentStatus paymentStatus;
  final FulfillmentStatus fulfillmentStatus;
  final String? notes;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime? voidedAt;
  final String? voidReason;
  final String? externalRef;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Sale({
    required this.id,
    required this.tenantId,
    required this.branchId,
    this.customerId,
    this.invoiceNumber,
    this.saleType = 'sale',
    this.createdBy,
    this.salespersonName,
    this.approvedBy,
    this.totalAmount = 0,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.grandTotal = 0,
    this.amountPaid = 0,
    this.paymentMethod,
    this.status = InvoiceStatus.draft,
    this.paymentStatus = PaymentStatus.unpaid,
    this.fulfillmentStatus = FulfillmentStatus.unreleased,
    this.notes,
    this.dueDate,
    this.completedAt,
    this.voidedAt,
    this.voidReason,
    this.externalRef,
    this.createdAt,
    this.updatedAt,
  });

  double get remainingBalance => grandTotal - amountPaid;
  bool get isFullyPaid => amountPaid >= grandTotal;
  
  // Can only accept payment if it's not fully paid and not voided.
  bool get canAcceptPayment => paymentStatus != PaymentStatus.paid && status != InvoiceStatus.voided && status != InvoiceStatus.rejected;

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String,
      customerId: map['customer_id'] as String?,
      invoiceNumber: map['invoice_number'] as String?,
      saleType: map['sale_type'] as String? ?? 'sale',
      createdBy: map['created_by'] as String?,
      salespersonName: map['salesperson'] as String?,
      approvedBy: map['approved_by'] as String?,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['payment_method'] as String?,
      status: InvoiceStatus.fromString(map['status'] as String?),
      paymentStatus: PaymentStatus.fromString(map['payment_status'] as String?),
      fulfillmentStatus: FulfillmentStatus.fromString(
        map['fulfillment_status'] as String?,
      ),
      notes: map['notes'] as String?,
      dueDate: _parseDate(map['due_date']),
      completedAt: _parseDate(map['completed_at']),
      voidedAt: _parseDate(map['voided_at']),
      voidReason: map['void_reason'] as String?,
      externalRef: map['external_ref'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'customer_id': customerId,
      'invoice_number': invoiceNumber,
      'sale_type': saleType,
      'created_by': createdBy,
      'salesperson': salespersonName,
      'approved_by': approvedBy,
      'total_amount': totalAmount,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'discount_amount': discountAmount,
      'grand_total': grandTotal,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'status': status.value,
      'payment_status': paymentStatus.value,
      'fulfillment_status': fulfillmentStatus.value,
      'notes': notes,
      'due_date': dueDate?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'voided_at': voidedAt?.toIso8601String(),
      'void_reason': voidReason,
      'external_ref': externalRef,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE ITEM
// ─────────────────────────────────────────────────────────────────────────────

class SaleItem {
  final String id;
  final String saleId;
  final String productId;
  final String? tenantId;
  final int quantity;
  final double unitPrice;
  final double costPrice;
  final double taxAmount;
  final double discount;
  final double total;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields (not stored, populated by queries)
  final String? productName;
  final String? productImageUrl;

  SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    this.tenantId,
    required this.quantity,
    required this.unitPrice,
    this.costPrice = 0,
    this.taxAmount = 0,
    this.discount = 0,
    required this.total,
    this.createdAt,
    this.updatedAt,
    this.productName,
    this.productImageUrl,
  });

  double get lineProfit => (unitPrice - costPrice) * quantity;

  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      id: map['id'] as String,
      saleId: map['sale_id'] as String,
      productId: map['product_id'] as String,
      tenantId: map['tenant_id'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      costPrice: (map['cost_price'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      productName: map['product_name'] as String?,
      productImageUrl: map['product_image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'tenant_id': tenantId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'cost_price': costPrice,
      'tax_amount': taxAmount,
      'discount': discount,
      'total': total,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT
// ─────────────────────────────────────────────────────────────────────────────

enum PaymentMethod {
  cash,
  mpesa,
  card,
  bankTransfer,
  creditNote;

  String get value {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.mpesa:
        return 'mpesa';
      case PaymentMethod.card:
        return 'card';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
      case PaymentMethod.creditNote:
        return 'credit_note';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.mpesa:
        return 'M-Pesa';
      case PaymentMethod.card:
        return 'Card';
      case PaymentMethod.bankTransfer:
        return 'Bank Transfer';
      case PaymentMethod.creditNote:
        return 'Credit Note';
    }
  }

  static PaymentMethod fromString(String? method) {
    switch (method?.toLowerCase()) {
      case 'cash':
        return PaymentMethod.cash;
      case 'mpesa':
      case 'm-pesa':
        return PaymentMethod.mpesa;
      case 'card':
        return PaymentMethod.card;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      case 'credit_note':
        return PaymentMethod.creditNote;
      default:
        return PaymentMethod.cash;
    }
  }
}

class Payment {
  final String id;
  final String tenantId;
  final String? branchId;
  final String saleId;
  final double amount;
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? recordedBy;
  final String? notes;
  final DateTime? createdAt;

  Payment({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.saleId,
    required this.amount,
    required this.paymentMethod,
    this.referenceNumber,
    this.recordedBy,
    this.notes,
    this.createdAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      saleId: map['sale_id'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: PaymentMethod.fromString(map['payment_method'] as String?),
      referenceNumber: map['reference_number'] as String?,
      recordedBy: map['recorded_by'] as String?,
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'sale_id': saleId,
      'amount': amount,
      'payment_method': paymentMethod.value,
      'reference_number': referenceNumber,
      'recorded_by': recordedBy,
      'notes': notes,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREDIT NOTE
// ─────────────────────────────────────────────────────────────────────────────

enum CreditNoteStatus {
  draft,
  pendingApproval,
  approved,
  applied,
  voided;

  String get value {
    switch (this) {
      case CreditNoteStatus.draft:
        return 'draft';
      case CreditNoteStatus.pendingApproval:
        return 'pending_approval';
      case CreditNoteStatus.approved:
        return 'approved';
      case CreditNoteStatus.applied:
        return 'applied';
      case CreditNoteStatus.voided:
        return 'voided';
    }
  }

  String get displayName {
    switch (this) {
      case CreditNoteStatus.draft:
        return 'Draft';
      case CreditNoteStatus.pendingApproval:
        return 'Pending Approval';
      case CreditNoteStatus.approved:
        return 'Approved';
      case CreditNoteStatus.applied:
        return 'Applied';
      case CreditNoteStatus.voided:
        return 'Voided';
    }
  }

  static CreditNoteStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return CreditNoteStatus.draft;
      case 'pending_approval':
        return CreditNoteStatus.pendingApproval;
      case 'approved':
        return CreditNoteStatus.approved;
      case 'applied':
        return CreditNoteStatus.applied;
      case 'voided':
        return CreditNoteStatus.voided;
      default:
        return CreditNoteStatus.draft;
    }
  }
}

class CreditNoteItem {
  final String productId;
  final String? productName;
  final int quantity;
  final double unitPrice;
  final double taxAmount;
  final double total;

  CreditNoteItem({
    required this.productId,
    this.productName,
    required this.quantity,
    required this.unitPrice,
    this.taxAmount = 0,
    required this.total,
  });

  factory CreditNoteItem.fromMap(Map<String, dynamic> map) {
    return CreditNoteItem(
      productId: map['product_id'] as String,
      productName: map['product_name'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'tax_amount': taxAmount,
      'total': total,
    };
  }
}

class CreditNote {
  final String id;
  final String tenantId;
  final String? branchId;
  final String originalSaleId;
  final String? creditNumber;
  final CreditNoteStatus status;
  final bool restockItems;
  final String reason;
  final List<CreditNoteItem> items;
  final double subtotal;
  final double taxAmount;
  final double total;
  final String? appliedToSaleId;
  final String? createdBy;
  final String? approvedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CreditNote({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.originalSaleId,
    this.creditNumber,
    this.status = CreditNoteStatus.draft,
    this.restockItems = false,
    required this.reason,
    required this.items,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.total = 0,
    this.appliedToSaleId,
    this.createdBy,
    this.approvedBy,
    this.createdAt,
    this.updatedAt,
  });

  factory CreditNote.fromMap(Map<String, dynamic> map) {
    // Items are now loaded separately from credit_note_items table.
    // When building a CreditNote via a direct DB query that joins items,
    // call fromMap with an explicit items list.
    return CreditNote(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      originalSaleId: map['original_sale_id'] as String,
      creditNumber: map['credit_number'] as String?,
      status: CreditNoteStatus.fromString(map['status'] as String?),
      restockItems: map['restock_items'] == 1 || map['restock_items'] == true,
      reason: map['reason'] as String? ?? '',
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => CreditNoteItem.fromMap(e as Map<String, dynamic>))
          .toList(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      appliedToSaleId: map['applied_to_sale_id'] as String?,
      createdBy: map['created_by'] as String?,
      approvedBy: map['approved_by'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'original_sale_id': originalSaleId,
      'credit_number': creditNumber,
      'status': status.value,
      'restock_items': restockItems ? 1 : 0,
      'reason': reason,
      // 'items' is now a junction table; do not serialize here
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'applied_to_sale_id': appliedToSaleId,
      'created_by': createdBy,
      'approved_by': approvedBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}
