// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Customer _$CustomerFromJson(Map<String, dynamic> json) => Customer(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  name: json['name'] as String,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
  creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$CustomerToJson(Customer instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'name': instance.name,
  'phone': instance.phone,
  'email': instance.email,
  'loyalty_points': instance.loyaltyPoints,
  'credit_limit': instance.creditLimit,
  'created_at': instance.createdAt?.toIso8601String(),
  'updated_at': instance.updatedAt?.toIso8601String(),
};
