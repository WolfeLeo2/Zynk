import 'package:json_annotation/json_annotation.dart';

part 'staff_model.g.dart';

enum StaffStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
  @JsonValue('blocked')
  blocked,
  @JsonValue('deleted')
  deleted;

  String get displayName {
    switch (this) {
      case StaffStatus.active:
        return 'Active';
      case StaffStatus.inactive:
        return 'Inactive';
      case StaffStatus.blocked:
        return 'Blocked';
      case StaffStatus.deleted:
        return 'Deleted';
    }
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class StaffMember {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final String? phone;
  final String? email;
  final String? profilePictureUrl;
  @JsonKey(defaultValue: StaffStatus.active)
  final StaffStatus status;
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
    this.status = StaffStatus.active,
    this.createdAt,
    this.updatedAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) =>
      _$StaffMemberFromJson(json);
  Map<String, dynamic> toJson() => _$StaffMemberToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffMember &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
