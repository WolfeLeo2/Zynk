// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Expense _$ExpenseFromJson(Map<String, dynamic> json) => Expense(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String,
  categoryId: json['category_id'] as String,
  staffMemberId: json['staff_member_id'] as String?,
  amount: (json['amount'] as num).toDouble(),
  description: json['description'] as String?,
  paymentMethod: json['payment_method'] as String?,
  expenseDate: _dateFromAny(json['expense_date']),
  createdAt: _dateFromAny(json['created_at']),
  updatedAt: _dateFromAny(json['updated_at']),
);

Map<String, dynamic> _$ExpenseToJson(Expense instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'category_id': instance.categoryId,
  'staff_member_id': instance.staffMemberId,
  'amount': instance.amount,
  'description': instance.description,
  'payment_method': instance.paymentMethod,
  'expense_date': _dateToIso(instance.expenseDate),
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};
