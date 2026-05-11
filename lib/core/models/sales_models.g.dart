// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Sale _$SaleFromJson(Map<String, dynamic> json) => Sale(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String,
  customerId: json['customer_id'] as String?,
  invoiceNumber: json['invoice_number'] as String?,
  saleType: json['sale_type'] as String? ?? 'sale',
  createdBy: json['created_by'] as String?,
  salespersonId: json['salesperson_id'] as String?,
  approvedBy: json['approved_by'] as String?,
  totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
  subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
  taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
  discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
  grandTotal: (json['grand_total'] as num?)?.toDouble() ?? 0,
  amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0,
  paymentMethod: json['payment_method'] as String?,
  status: json['status'] == null
      ? InvoiceStatus.pendingApproval
      : _invoiceStatusFromJson(json['status'] as String?),
  requiredApprovals: (json['required_approvals'] as num?)?.toInt() ?? 2,
  approvalCount: (json['approval_count'] as num?)?.toInt() ?? 0,
  paymentStatus: json['payment_status'] == null
      ? PaymentStatus.unpaid
      : _paymentStatusFromJson(json['payment_status'] as String?),
  fulfillmentStatus: json['fulfillment_status'] == null
      ? FulfillmentStatus.unreleased
      : _fulfillmentStatusFromJson(json['fulfillment_status'] as String?),
  notes: json['notes'] as String?,
  dueDate: _parseDate(json['due_date']),
  completedAt: _parseDate(json['completed_at']),
  voidedAt: _parseDate(json['voided_at']),
  voidReason: json['void_reason'] as String?,
  externalRef: json['external_ref'] as String?,
  createdAt: _parseDate(json['created_at']),
  updatedAt: _parseDate(json['updated_at']),
);

Map<String, dynamic> _$SaleToJson(Sale instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'customer_id': instance.customerId,
  'invoice_number': instance.invoiceNumber,
  'sale_type': instance.saleType,
  'created_by': instance.createdBy,
  'salesperson_id': instance.salespersonId,
  'approved_by': instance.approvedBy,
  'total_amount': instance.totalAmount,
  'subtotal': instance.subtotal,
  'tax_amount': instance.taxAmount,
  'discount_amount': instance.discountAmount,
  'grand_total': instance.grandTotal,
  'amount_paid': instance.amountPaid,
  'payment_method': instance.paymentMethod,
  'status': _invoiceStatusToJson(instance.status),
  'required_approvals': instance.requiredApprovals,
  'approval_count': instance.approvalCount,
  'payment_status': _paymentStatusToJson(instance.paymentStatus),
  'fulfillment_status': _fulfillmentStatusToJson(instance.fulfillmentStatus),
  'notes': instance.notes,
  'due_date': _dateToIso(instance.dueDate),
  'completed_at': _dateToIso(instance.completedAt),
  'voided_at': _dateToIso(instance.voidedAt),
  'void_reason': instance.voidReason,
  'external_ref': instance.externalRef,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

SaleItem _$SaleItemFromJson(Map<String, dynamic> json) => SaleItem(
  id: json['id'] as String,
  saleId: json['sale_id'] as String,
  productId: json['product_id'] as String,
  tenantId: json['tenant_id'] as String?,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: (json['unit_price'] as num).toDouble(),
  costPrice: (json['cost_price'] as num?)?.toDouble() ?? 0,
  taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
  discount: (json['discount'] as num?)?.toDouble() ?? 0,
  total: (json['total'] as num).toDouble(),
  createdAt: _parseDate(json['created_at']),
  updatedAt: _parseDate(json['updated_at']),
  productName: json['product_name'] as String?,
  productImageUrl: json['product_image_url'] as String?,
);

Map<String, dynamic> _$SaleItemToJson(SaleItem instance) => <String, dynamic>{
  'id': instance.id,
  'sale_id': instance.saleId,
  'product_id': instance.productId,
  'tenant_id': instance.tenantId,
  'quantity': instance.quantity,
  'unit_price': instance.unitPrice,
  'cost_price': instance.costPrice,
  'tax_amount': instance.taxAmount,
  'discount': instance.discount,
  'total': instance.total,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

Payment _$PaymentFromJson(Map<String, dynamic> json) => Payment(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  saleId: json['sale_id'] as String,
  amount: (json['amount'] as num).toDouble(),
  paymentMethod: _paymentMethodFromJson(json['payment_method'] as String?),
  referenceNumber: json['reference_number'] as String?,
  recordedBy: json['recorded_by'] as String?,
  notes: json['notes'] as String?,
  createdAt: _parseDate(json['created_at']),
);

Map<String, dynamic> _$PaymentToJson(Payment instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'sale_id': instance.saleId,
  'amount': instance.amount,
  'payment_method': _paymentMethodToJson(instance.paymentMethod),
  'reference_number': instance.referenceNumber,
  'recorded_by': instance.recordedBy,
  'notes': instance.notes,
  'created_at': _dateToIso(instance.createdAt),
};

SaleApproval _$SaleApprovalFromJson(Map<String, dynamic> json) => SaleApproval(
  id: json['id'] as String,
  saleId: json['sale_id'] as String,
  tenantId: json['tenant_id'] as String,
  approverUserId: json['approver_user_id'] as String,
  decision: json['decision'] == null
      ? SaleApprovalDecision.approved
      : _saleApprovalDecisionFromJson(json['decision'] as String?),
  notes: json['notes'] as String?,
  createdAt: _parseDate(json['created_at']),
  approverDisplayName: json['approver_display_name'] as String?,
  approverRole: json['approver_role'] as String?,
);

Map<String, dynamic> _$SaleApprovalToJson(SaleApproval instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sale_id': instance.saleId,
      'tenant_id': instance.tenantId,
      'approver_user_id': instance.approverUserId,
      'decision': _saleApprovalDecisionToJson(instance.decision),
      'notes': instance.notes,
      'created_at': _dateToIso(instance.createdAt),
    };

CreditNoteItem _$CreditNoteItemFromJson(Map<String, dynamic> json) =>
    CreditNoteItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
    );

Map<String, dynamic> _$CreditNoteItemToJson(CreditNoteItem instance) =>
    <String, dynamic>{
      'product_id': instance.productId,
      'product_name': instance.productName,
      'quantity': instance.quantity,
      'unit_price': instance.unitPrice,
      'tax_amount': instance.taxAmount,
      'total': instance.total,
    };

CreditNote _$CreditNoteFromJson(Map<String, dynamic> json) => CreditNote(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  originalSaleId: json['original_sale_id'] as String,
  creditNumber: json['credit_number'] as String?,
  status: json['status'] == null
      ? CreditNoteStatus.draft
      : _creditNoteStatusFromJson(json['status'] as String?),
  restockItems: json['restock_items'] == null
      ? false
      : _boolFromIntOrBool(json['restock_items']),
  reason: json['reason'] as String,
  items: (json['items'] as List<dynamic>)
      .map((e) => CreditNoteItem.fromJson(e as Map<String, dynamic>))
      .toList(),
  subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
  taxAmount: (json['tax_amount'] as num?)?.toDouble() ?? 0,
  total: (json['total'] as num?)?.toDouble() ?? 0,
  appliedToSaleId: json['applied_to_sale_id'] as String?,
  createdBy: json['created_by'] as String?,
  approvedBy: json['approved_by'] as String?,
  createdAt: _parseDate(json['created_at']),
  updatedAt: _parseDate(json['updated_at']),
);

Map<String, dynamic> _$CreditNoteToJson(CreditNote instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'branch_id': instance.branchId,
      'original_sale_id': instance.originalSaleId,
      'credit_number': instance.creditNumber,
      'status': _creditNoteStatusToJson(instance.status),
      'restock_items': _boolToInt(instance.restockItems),
      'reason': instance.reason,
      'subtotal': instance.subtotal,
      'tax_amount': instance.taxAmount,
      'total': instance.total,
      'applied_to_sale_id': instance.appliedToSaleId,
      'created_by': instance.createdBy,
      'approved_by': instance.approvedBy,
      'created_at': _dateToIso(instance.createdAt),
      'updated_at': _dateToIso(instance.updatedAt),
    };
