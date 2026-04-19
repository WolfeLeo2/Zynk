// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'adjustment_reason.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AdjustmentReason _$AdjustmentReasonFromJson(Map<String, dynamic> json) =>
    AdjustmentReason(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      label: json['label'] as String,
      createdAt: AdjustmentReason._dateTimeFromJson(
        json['created_at'] as String?,
      ),
    );

Map<String, dynamic> _$AdjustmentReasonToJson(AdjustmentReason instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'label': instance.label,
      'created_at': AdjustmentReason._dateTimeToJson(instance.createdAt),
    };
