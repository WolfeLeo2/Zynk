import 'dart:convert';
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
  final List<String> attributes; // Ordered attribute names this group defines
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
    this.attributes = const [],
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
      attributes: () {
        final raw = map['attributes'];
        if (raw == null) return <String>[];
        if (raw is List) return raw.map((e) => e.toString()).toList();
        if (raw is String) {
          try {
            final decoded = jsonDecode(raw);
            if (decoded is List) return decoded.map((e) => e.toString()).toList();
          } catch (_) {}
        }
        return <String>[];
      }(),
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
      'attributes': attributes,
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
  final double? weight;
  final double? length;
  final double? width;
  final double? height;
  final String? taxCategory;
  final bool isService;
  final String? groupId;
  final String? uomId;
  final String? parentId; // Added for Parent-Child variants
  final Map<String, dynamic>? variantOptions;
  final Map<String, dynamic>? variantImages; // {"Red": "https://...", ...}
  final String productType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isComposite => productType == 'composite';
  bool get isGroup => productType == 'group';

  Product copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    String? itemGroupId,
    String? categoryId,
    String? name,
    String? sku,
    String? barcode,
    String? description,
    String? imageUrl,
    double? basePrice,
    double? costPrice,
    double? weight,
    double? length,
    double? width,
    double? height,
    String? taxCategory,
    bool? isService,
    String? groupId,
    String? uomId,
    String? parentId,
    Map<String, dynamic>? variantOptions,
    Map<String, dynamic>? variantImages,
    String? productType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      itemGroupId: itemGroupId ?? this.itemGroupId,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      basePrice: basePrice ?? this.basePrice,
      costPrice: costPrice ?? this.costPrice,
      weight: weight ?? this.weight,
      length: length ?? this.length,
      width: width ?? this.width,
      height: height ?? this.height,
      taxCategory: taxCategory ?? this.taxCategory,
      isService: isService ?? this.isService,
      groupId: groupId ?? this.groupId,
      uomId: uomId ?? this.uomId,
      parentId: parentId ?? this.parentId,
      variantOptions: variantOptions ?? this.variantOptions,
      variantImages: variantImages ?? this.variantImages,
      productType: productType ?? this.productType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
    this.weight,
    this.length,
    this.width,
    this.height,
    this.taxCategory,
    this.isService = false,
    this.groupId,
    this.uomId,
    this.parentId,
    this.variantOptions,
    this.variantImages,
    this.productType = 'standard',
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
      groupId: map['group_id'] as String?,
      uomId: map['uom_id'] as String?,
      parentId: map['parent_id'] as String?,
      variantOptions: () {
        final val = map['variant_options'];
        if (val == null) return null;
        if (val is Map<String, dynamic>) return val;
        if (val is String) {
          try {
            final decoded = jsonDecode(val);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {}
        }
        return null;
      }(),
      variantImages: () {
        final val = map['variant_images'];
        if (val == null) return null;
        if (val is Map<String, dynamic>) return val;
        if (val is String) {
          try {
            final decoded = jsonDecode(val);
            if (decoded is Map<String, dynamic>) return decoded;
          } catch (_) {}
        }
        return null;
      }(),
      productType: map['product_type'] as String? ?? 'standard',
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
      'weight': weight,
      'length': length,
      'width': width,
      'height': height,
      'tax_category': taxCategory,
      'is_service': isService ? 1 : 0,
      'group_id': groupId,
      'uom_id': uomId,
      'parent_id': parentId,
      'variant_options': variantOptions != null ? jsonEncode(variantOptions) : null,
      'variant_images': variantImages != null ? jsonEncode(variantImages) : null,
      'product_type': productType,
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
  final String? adjustmentType;
  final int quantity;
  final String? referenceNumber;
  final String? notes;
  final String? createdBy;
  final String? reasonId;
  final DateTime? createdAt;
  // Populated from JOIN queries — not stored:
  final String? adjusterName;
  final String? reasonLabel;

  StockAdjustment({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.productId,
    this.adjustmentType,
    required this.quantity,
    this.referenceNumber,
    this.notes,
    this.createdBy,
    this.reasonId,
    this.createdAt,
    this.adjusterName,
    this.reasonLabel,
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> map) {
    return StockAdjustment(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String,
      productId: map['product_id'] as String,
      adjustmentType: map['adjustment_type'] as String?,
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      referenceNumber: map['reference_number'] as String?,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as String?,
      reasonId: map['reason_id'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      adjusterName: map['adjuster_display_name'] as String?,
      reasonLabel: map['reason_label'] as String?,
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
      'reason_id': reasonId,
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

class StockItemGroup {
  final String id;
  final String tenantId;
  final String name;
  final String? description;
  final String? attributes; // Store as raw string from sqlite

  StockItemGroup({
    required this.id,
    required this.tenantId,
    required this.name,
    this.description,
    this.attributes,
  });

  factory StockItemGroup.fromMap(Map<String, dynamic> map) {
    return StockItemGroup(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      attributes: map['attributes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'description': description,
      'attributes': attributes,
    };
  }
}

class CompositeItemComponent {
  final String id;
  final String tenantId;
  final String branchId;
  final String compositeProductId;
  final String componentProductId;
  final int quantity;

  CompositeItemComponent({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.compositeProductId,
    required this.componentProductId,
    required this.quantity,
  });

  factory CompositeItemComponent.fromMap(Map<String, dynamic> map) {
    return CompositeItemComponent(
      id: map['id'] as String? ?? '', // PowerSync might omit ID in certain local joins if not selected
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String? ?? '',
      compositeProductId: map['composite_product_id'] as String,
      componentProductId: map['component_product_id'] as String,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'composite_product_id': compositeProductId,
      'component_product_id': componentProductId,
      'quantity': quantity,
    };
  }

  CompositeItemComponent copyWith({
    String? id,
    String? tenantId,
    String? branchId,
    String? compositeProductId,
    String? componentProductId,
    int? quantity,
  }) {
    return CompositeItemComponent(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      branchId: branchId ?? this.branchId,
      compositeProductId: compositeProductId ?? this.compositeProductId,
      componentProductId: componentProductId ?? this.componentProductId,
      quantity: quantity ?? this.quantity,
    );
  }
}

class UnitOfMeasurement {
  final String id;
  final String tenantId;
  final String label;
  final String? abbreviation;
  final String? baseUnitId;
  final double conversionFactor;
  final DateTime? createdAt;

  UnitOfMeasurement({
    required this.id,
    required this.tenantId,
    required this.label,
    this.abbreviation,
    this.baseUnitId,
    this.conversionFactor = 1.0,
    this.createdAt,
  });

  factory UnitOfMeasurement.fromMap(Map<String, dynamic> map) {
    return UnitOfMeasurement(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      label: map['label'] as String,
      abbreviation: map['abbreviation'] as String?,
      baseUnitId: map['base_unit_id'] as String?,
      conversionFactor: (map['conversion_factor'] as num?)?.toDouble() ?? 1.0,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'label': label,
      'abbreviation': abbreviation,
      'base_unit_id': baseUnitId,
      'conversion_factor': conversionFactor,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
