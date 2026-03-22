class StaffMember {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final String? phone;
  final String? email;
  final String? profilePictureUrl;
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

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String?,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'name': name,
      'phone': phone,
      'email': email,
      'profile_picture_url': profilePictureUrl,
      'status': status,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
