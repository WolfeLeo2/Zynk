// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StaffMember _$StaffMemberFromJson(Map<String, dynamic> json) => StaffMember(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  name: json['name'] as String,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  profilePictureUrl: json['profile_picture_url'] as String?,
  status:
      $enumDecodeNullable(_$StaffStatusEnumMap, json['status']) ??
      StaffStatus.active,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
);

Map<String, dynamic> _$StaffMemberToJson(StaffMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'branch_id': instance.branchId,
      'name': instance.name,
      'phone': instance.phone,
      'email': instance.email,
      'profile_picture_url': instance.profilePictureUrl,
      'status': _$StaffStatusEnumMap[instance.status]!,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$StaffStatusEnumMap = {
  StaffStatus.active: 'active',
  StaffStatus.inactive: 'inactive',
  StaffStatus.blocked: 'blocked',
  StaffStatus.deleted: 'deleted',
};
