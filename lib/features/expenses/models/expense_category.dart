import 'package:json_annotation/json_annotation.dart';

part 'expense_category.g.dart';

DateTime? _dateFromAny(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _dateToIso(DateTime? value) => value?.toIso8601String();

@JsonSerializable(fieldRename: FieldRename.snake)
class ExpenseCategory {
  final String id;
  final String tenantId;
  final String name;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? updatedAt;

  ExpenseCategory({
    required this.id,
    required this.tenantId,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) => _$ExpenseCategoryFromJson(map);

  Map<String, dynamic> toMap() => _$ExpenseCategoryToJson(this);
}
