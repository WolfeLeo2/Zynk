class Customer {
  final String id;
  final String tenantId;
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
    required this.name,
    this.phone,
    this.email,
    this.loyaltyPoints = 0,
    this.creditLimit = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      loyaltyPoints: (map['loyalty_points'] as num?)?.toInt() ?? 0,
      creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'phone': phone,
      'email': email,
      'loyalty_points': loyaltyPoints,
      'credit_limit': creditLimit,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
