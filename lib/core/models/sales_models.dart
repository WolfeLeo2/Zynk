// NOTE: 'dart:convert' no longer needed — credit note items use a junction table.

import 'package:json_annotation/json_annotation.dart';

part 'sales_models.g.dart';

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
  pendingApproval,
  approved,
  rejected,
  partiallyPaid, // Legacy value, no longer used for new lifecycle writes
  paid, // Legacy value, no longer used for new lifecycle writes
  completed, // Legacy value, no longer used for new lifecycle writes
  voided;

  String get value {
    switch (this) {
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

  static InvoiceStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return InvoiceStatus.pendingApproval;
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
        return InvoiceStatus.pendingApproval;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE MODEL (Invoice)
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(fieldRename: FieldRename.snake)
class Sale {
  final String id;
  final String tenantId;
  final String branchId;
  final String? customerId;
  final String? invoiceNumber;
  final String saleType;
  final String? createdBy;
  final String? salespersonId;
  final String? approvedBy;
  final double totalAmount;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double grandTotal;
  final double amountPaid;
  final String? paymentMethod;
  @JsonKey(fromJson: _invoiceStatusFromJson, toJson: _invoiceStatusToJson)
  final InvoiceStatus status;
  final int requiredApprovals;
  final int approvalCount;
  @JsonKey(fromJson: _paymentStatusFromJson, toJson: _paymentStatusToJson)
  final PaymentStatus paymentStatus;
  @JsonKey(
    fromJson: _fulfillmentStatusFromJson,
    toJson: _fulfillmentStatusToJson,
  )
  final FulfillmentStatus fulfillmentStatus;
  final String? notes;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? dueDate;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? completedAt;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? voidedAt;
  final String? voidReason;
  final String? externalRef;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? updatedAt;

  Sale({
    required this.id,
    required this.tenantId,
    required this.branchId,
    this.customerId,
    this.invoiceNumber,
    this.saleType = 'sale',
    this.createdBy,
    this.salespersonId,
    this.approvedBy,
    this.totalAmount = 0,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.grandTotal = 0,
    this.amountPaid = 0,
    this.paymentMethod,
    this.status = InvoiceStatus.pendingApproval,
    this.requiredApprovals = 2,
    this.approvalCount = 0,
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

  /// Payments are accepted for active invoices and blocked only when terminal.
  bool get canAcceptPayment =>
      paymentStatus != PaymentStatus.paid &&
      status != InvoiceStatus.voided &&
      status != InvoiceStatus.rejected;

  /// Voiding is blocked once any payment is recorded.
  bool get canBeVoided =>
      status != InvoiceStatus.voided &&
      status != InvoiceStatus.rejected &&
      amountPaid <= 0;

  /// Goods release is independent from payment state.
  bool get canBeReleased =>
      status != InvoiceStatus.voided &&
      status != InvoiceStatus.rejected &&
      fulfillmentStatus == FulfillmentStatus.unreleased;

  /// Derived business completion: paid + released while still active.
  bool get isOperationallyCompleted =>
      paymentStatus == PaymentStatus.paid &&
      fulfillmentStatus == FulfillmentStatus.released &&
      status != InvoiceStatus.voided &&
      status != InvoiceStatus.rejected;

  factory Sale.fromMap(Map<String, dynamic> map) => _$SaleFromJson(map);

  Map<String, dynamic> toMap() => _$SaleToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE ITEM
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(fieldRename: FieldRename.snake)
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
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? updatedAt;

  // Joined fields (not stored, populated by queries)
  @JsonKey(includeToJson: false)
  final String? productName;
  @JsonKey(includeToJson: false)
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

  factory SaleItem.fromMap(Map<String, dynamic> map) => _$SaleItemFromJson(map);

  Map<String, dynamic> toMap() => _$SaleItemToJson(this);
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

@JsonSerializable(fieldRename: FieldRename.snake)
class Payment {
  final String id;
  final String tenantId;
  final String? branchId;
  final String saleId;
  final double amount;
  @JsonKey(fromJson: _paymentMethodFromJson, toJson: _paymentMethodToJson)
  final PaymentMethod paymentMethod;
  final String? referenceNumber;
  final String? recordedBy;
  final String? notes;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
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

  factory Payment.fromMap(Map<String, dynamic> map) => _$PaymentFromJson(map);

  Map<String, dynamic> toMap() => _$PaymentToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// SALE APPROVALS
// ─────────────────────────────────────────────────────────────────────────────

enum SaleApprovalDecision {
  approved,
  rejected;

  String get value {
    switch (this) {
      case SaleApprovalDecision.approved:
        return 'approved';
      case SaleApprovalDecision.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case SaleApprovalDecision.approved:
        return 'Approved';
      case SaleApprovalDecision.rejected:
        return 'Rejected';
    }
  }

  static SaleApprovalDecision fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'rejected':
        return SaleApprovalDecision.rejected;
      case 'approved':
      default:
        return SaleApprovalDecision.approved;
    }
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class SaleApproval {
  final String id;
  final String saleId;
  final String tenantId;
  final String approverUserId;
  @JsonKey(
    fromJson: _saleApprovalDecisionFromJson,
    toJson: _saleApprovalDecisionToJson,
  )
  final SaleApprovalDecision decision;
  final String? notes;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(includeToJson: false)
  final String? approverDisplayName;
  @JsonKey(includeToJson: false)
  final String? approverRole;

  SaleApproval({
    required this.id,
    required this.saleId,
    required this.tenantId,
    required this.approverUserId,
    this.decision = SaleApprovalDecision.approved,
    this.notes,
    this.createdAt,
    this.approverDisplayName,
    this.approverRole,
  });

  factory SaleApproval.fromMap(Map<String, dynamic> map) =>
      _$SaleApprovalFromJson(map);

  Map<String, dynamic> toMap() => _$SaleApprovalToJson(this);
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

@JsonSerializable(fieldRename: FieldRename.snake)
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

  factory CreditNoteItem.fromJson(Map<String, dynamic> json) =>
      _$CreditNoteItemFromJson(json);

  factory CreditNoteItem.fromMap(Map<String, dynamic> map) =>
      _$CreditNoteItemFromJson(map);

  Map<String, dynamic> toMap() => _$CreditNoteItemToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CreditNote {
  final String id;
  final String tenantId;
  final String? branchId;
  final String originalSaleId;
  final String? creditNumber;
  @JsonKey(fromJson: _creditNoteStatusFromJson, toJson: _creditNoteStatusToJson)
  final CreditNoteStatus status;
  @JsonKey(fromJson: _boolFromIntOrBool, toJson: _boolToInt)
  final bool restockItems;
  final String reason;
  @JsonKey(includeToJson: false)
  final List<CreditNoteItem> items;
  final double subtotal;
  final double taxAmount;
  final double total;
  final String? appliedToSaleId;
  final String? createdBy;
  final String? approvedBy;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _parseDate, toJson: _dateToIso)
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

  factory CreditNote.fromMap(Map<String, dynamic> map) =>
      _$CreditNoteFromJson(map);

  Map<String, dynamic> toMap() => _$CreditNoteToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER
// ─────────────────────────────────────────────────────────────────────────────

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _dateToIso(DateTime? value) => value?.toIso8601String();

InvoiceStatus _invoiceStatusFromJson(String? value) =>
    InvoiceStatus.fromString(value);

String _invoiceStatusToJson(InvoiceStatus value) => value.value;

PaymentStatus _paymentStatusFromJson(String? value) =>
    PaymentStatus.fromString(value);

String _paymentStatusToJson(PaymentStatus value) => value.value;

FulfillmentStatus _fulfillmentStatusFromJson(String? value) =>
    FulfillmentStatus.fromString(value);

String _fulfillmentStatusToJson(FulfillmentStatus value) => value.value;

PaymentMethod _paymentMethodFromJson(String? value) =>
    PaymentMethod.fromString(value);

String _paymentMethodToJson(PaymentMethod value) => value.value;

SaleApprovalDecision _saleApprovalDecisionFromJson(String? value) =>
    SaleApprovalDecision.fromString(value);

String _saleApprovalDecisionToJson(SaleApprovalDecision value) => value.value;

CreditNoteStatus _creditNoteStatusFromJson(String? value) =>
    CreditNoteStatus.fromString(value);

String _creditNoteStatusToJson(CreditNoteStatus value) => value.value;

bool _boolFromIntOrBool(dynamic value) =>
    value == true || value == 1 || value == '1';

int _boolToInt(bool value) => value ? 1 : 0;
