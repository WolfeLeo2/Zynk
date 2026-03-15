import 'package:zynk/core/models/user_role.dart';

class Tenant {
  final String id;
  final String name;
  final String? planType;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Tenant({
    required this.id,
    required this.name,
    this.planType,
    this.address,
    this.phone,
    this.email,
    this.logoUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as String,
      name: map['name'] as String,
      planType: map['plan_type'] as String?,
      address: map['address'] as String?,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      logoUrl: map['logo_url'] as String?,
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
      'address': address,
      'phone': phone,
      'email': email,
      'logo_url': logoUrl,
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
  final UserRole role;
  final Set<Permission> permissions;
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
    Set<Permission>? permissions,
    this.displayName,
    this.profilePictureUrl,
    this.createdAt,
    this.updatedAt,
  }) : permissions = permissions ?? role.defaultPermissions;

  /// Returns true if this profile has the given permission.
  /// Owner always returns true.
  bool hasPermission(Permission permission) {
    if (role.hasAllPermissions) return true;
    return permissions.contains(permission);
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    final role = UserRole.fromString(map['role'] as String? ?? 'Cashier');
    return Profile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      role: role,
      permissions: role.isOwner
          ? Permission.values.toSet()
          : Permission.fromJsonList(map['permissions'] as String?),
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
      'permissions': Permission.toJsonList(permissions),
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
  final String? phone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Branch({
    required this.id,
    required this.tenantId,
    this.locationId,
    required this.name,
    this.address,
    this.phone,
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
      phone: map['phone'] as String?,
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
      'phone': phone,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Category {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Category({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
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
      'branch_id': branchId,
      'name': name,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class ItemGroup {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final String? description;
  final String? defaultCommissionType;
  final double? defaultCommissionValue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ItemGroup({
    required this.id,
    required this.tenantId,
    this.branchId,
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
      branchId: map['branch_id'] as String?,
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
      'branch_id': branchId,
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
  final String? branchId;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Product({
    required this.id,
    required this.tenantId,
    this.branchId,
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
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
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
      'branch_id': branchId,
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
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

class Stock {
  final String id;
  final String tenantId;
  final String branchId;
  final String productId;
  final int quantity;
  final int? reorderLevel;
  final DateTime? lastUpdated;

  Stock({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.quantity,
    this.reorderLevel,
    this.lastUpdated,
  });

  factory Stock.fromMap(Map<String, dynamic> map) {
    return Stock(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String,
      productId: map['product_id'] as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      reorderLevel: (map['reorder_level'] as num?)?.toInt(),
      lastUpdated: map['last_updated'] != null
          ? DateTime.parse(map['last_updated'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'product_id': productId,
      'quantity': quantity,
      'reorder_level': reorderLevel,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }
}

class StockAdjustment {
  final String id;
  final String tenantId;
  final String branchId;
  final String productId;
  final String adjustmentType;
  final int quantity;
  final String? referenceNumber;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  StockAdjustment({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    required this.adjustmentType,
    required this.quantity,
    this.referenceNumber,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String,
      productId: map['product_id'] as String,
      adjustmentType: map['adjustment_type'] as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'product_id': productId,
      'adjustment_type': adjustmentType,
      'quantity': quantity,
      'reference_number': referenceNumber,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class BatchAdjustmentItem {
  final String productId;
  final int quantityChange;
  final String? notes;

  BatchAdjustmentItem({
    required this.productId,
    required this.quantityChange,
    this.notes,
  });
}
