import 'package:zynk/core/models/user_role.dart';

class Tenant {
  final String id;
  final String name;
  final String? planType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tenant({
    required this.id,
    required this.name,
    this.planType,
    this.createdAt,
    this.updatedAt,
  });

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as String,
      name: map['name'] as String,
      planType: map['plan_type'] as String?,
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
      'name': name,
      'plan_type': planType,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Profile {
  final String id;
  final String userId;
  final String tenantId;
  final String? branchId;
  final UserRole role; // Using the existing UserRole enum
  final String? displayName;
  final String? profilePictureUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Profile({
    required this.id,
    required this.userId,
    required this.tenantId,
    this.branchId,
    required this.role,
    this.displayName,
    this.profilePictureUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      role: UserRole.fromString(map['role'] as String? ?? 'Cashier'),
      displayName: map['display_name'] as String?,
      profilePictureUrl: map['profile_picture_url'] as String?,
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
      'user_id': userId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'role': role.toShortString(),
      'display_name': displayName,
      'profile_picture_url': profilePictureUrl,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Branch {
  final String id;
  final String tenantId;
  final String? locationId;
  final String name;
  final String? address;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Branch({
    required this.id,
    required this.tenantId,
    this.locationId,
    required this.name,
    this.address,
    this.createdAt,
    this.updatedAt,
  });

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      locationId: map['location_id'] as String?,
      name: map['name'] as String,
      address: map['address'] as String?,
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
      'location_id': locationId,
      'name': name,
      'address': address,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Category {
  final String id;
  final String tenantId;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    required this.id,
    required this.tenantId,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class ItemGroup {
  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final String? defaultCommissionType;
  final double? defaultCommissionValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ItemGroup({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    this.defaultCommissionType,
    this.defaultCommissionValue,
    this.createdAt,
    this.updatedAt,
  });

  factory ItemGroup.fromMap(Map<String, dynamic> map) {
    return ItemGroup(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      defaultCommissionType: map['default_commission_type'] as String?,
      defaultCommissionValue: (map['default_commission_value'] as num?)
          ?.toDouble(),
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
      'description': description,
      'default_commission_type': defaultCommissionType,
      'default_commission_value': defaultCommissionValue,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Product {
  final String id;
  final String tenantId;
  final String? itemGroupId;
  final String? categoryId;
  final String name;
  final String? sku;
  final String? barcode;
  final String? description;
  final String? imageUrl;
  final double basePrice;
  final double? costPrice; // Added
  final String? taxCategory;
  final bool isService;
  final String? commissionType;
  final double? commissionValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.tenantId,
    this.itemGroupId,
    this.categoryId,
    required this.name,
    this.sku,
    this.barcode,
    this.description,
    this.imageUrl,
    required this.basePrice,
    this.costPrice, // Added
    this.taxCategory,
    this.isService = false,
    this.commissionType,
    this.commissionValue,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      itemGroupId: map['item_group_id'] as String?,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      basePrice: (map['base_price'] as num?)?.toDouble() ?? 0.0,
      costPrice: (map['cost_price'] as num?)?.toDouble(), // Added
      taxCategory: map['tax_category'] as String?,
      isService: (map['is_service'] as int?) == 1,
      commissionType: map['commission_type'] as String?,
      commissionValue: (map['commission_value'] as num?)?.toDouble(),
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
      'item_group_id': itemGroupId,
      'category_id': categoryId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'description': description,
      'image_url': imageUrl,
      'base_price': basePrice,
      'cost_price': costPrice, // Added
      'tax_category': taxCategory,
      'is_service': isService ? 1 : 0,
      'commission_type': commissionType,
      'commission_value': commissionValue,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
