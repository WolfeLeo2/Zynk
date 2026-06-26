import 'package:json_annotation/json_annotation.dart';

part 'customer_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Customer {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final String? phone;
  final String? email;
  final int loyaltyPoints;
  final double creditLimit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Customer({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.name,
    this.phone,
    this.email,
    this.loyaltyPoints = 0,
    this.creditLimit = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) => _$CustomerFromJson(map);

  Map<String, dynamic> toMap() => _$CustomerToJson(this);
}
