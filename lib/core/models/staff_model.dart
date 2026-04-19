import 'package:json_annotation/json_annotation.dart';

part 'staff_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class StaffMember {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final String? phone;
  final String? email;
  final String? profilePictureUrl;
  @JsonKey(defaultValue: 'active')
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StaffMember({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.name,
    this.phone,
    this.email,
    this.profilePictureUrl,
    this.status = 'active',
    this.createdAt,
    this.updatedAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) =>
      _$StaffMemberFromJson(json);

  Map<String, dynamic> toJson() => _$StaffMemberToJson(this);
}
