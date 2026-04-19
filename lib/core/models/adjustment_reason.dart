import 'package:json_annotation/json_annotation.dart';

part 'adjustment_reason.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADJUSTMENT REASON MODEL
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(fieldRename: FieldRename.snake)
class AdjustmentReason {
  final String id;
  final String tenantId;
  final String label;
  @JsonKey(fromJson: _dateTimeFromJson, toJson: _dateTimeToJson)
  final DateTime? createdAt;

  const AdjustmentReason({
    required this.id,
    required this.tenantId,
    required this.label,
    this.createdAt,
  });

  factory AdjustmentReason.fromMap(Map<String, dynamic> map) =>
      _$AdjustmentReasonFromJson(map);

  Map<String, dynamic> toMap() => _$AdjustmentReasonToJson(this);

  static DateTime? _dateTimeFromJson(String? value) =>
      value == null ? null : DateTime.tryParse(value);

  static String? _dateTimeToJson(DateTime? value) =>
      value?.toUtc().toIso8601String();
}
