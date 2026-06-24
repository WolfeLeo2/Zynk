import 'package:json_annotation/json_annotation.dart';

part 'expense.g.dart';

DateTime? _dateFromAny(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _dateToIso(DateTime? value) => value?.toIso8601String();

@JsonSerializable(fieldRename: FieldRename.snake)
class Expense {
  final String id;
  final String tenantId;
  final String branchId;
  final String categoryId;
  final String? staffMemberId;
  final double amount;
  final String? description;
  final String? paymentMethod;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? expenseDate;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? updatedAt;

  // Join fields (UI only)
  final String? branchName;
  @JsonKey(name: 'staff_name', includeToJson: false)
  final String? staffName;
  @JsonKey(name: 'category_name', includeToJson: false)
  final String? categoryName;

  Expense({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.categoryId,
    this.staffMemberId,
    required this.amount,
    this.description,
    this.paymentMethod,
    this.expenseDate,
    this.createdAt,
    this.updatedAt,
    this.branchName,
    this.staffName,
    this.categoryName,
  });

  factory Expense.fromMap(Map<String, dynamic> map) => _$ExpenseFromJson(map);

  Map<String, dynamic> toMap() => _$ExpenseToJson(this);
}
