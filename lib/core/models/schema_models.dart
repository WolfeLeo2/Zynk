import 'package:json_annotation/json_annotation.dart';
import 'package:zynk/core/models/user_role.dart';

part 'schema_models.g.dart';

DateTime? _dateFromAny(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String? _dateToIso(DateTime? value) => value?.toIso8601String();

UserRole _roleFromJson(String? value) =>
    UserRole.fromString(value ?? 'Cashier');

String _roleToJson(UserRole role) => role.toShortString();

Set<Permission> _permissionsFromJson(dynamic value) {
  if (value == null) return {};
  if (value is String) return Permission.fromJsonList(value);
  if (value is List) {
    return value
        .map((e) => Permission.fromString(e?.toString() ?? ''))
        .whereType<Permission>()
        .toSet();
  }
  return {};
}

String _permissionsToJson(Set<Permission>? permissions) {
  return Permission.toJsonList(permissions ?? <Permission>{});
}

bool _boolFromSqlite(dynamic value) =>
    value == true || value == 1 || value == '1';

int _boolToSqlite(bool value) => value ? 1 : 0;

String _stringOrEmpty(dynamic value) => (value as String?) ?? '';

@JsonSerializable(fieldRename: FieldRename.snake)
class Tenant {
  final String id;
  final String name;
  final String? planType;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoUrl;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
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

  factory Tenant.fromMap(Map<String, dynamic> map) => _$TenantFromJson(map);

  Map<String, dynamic> toMap() => _$TenantToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Profile {
  final String id;
  final String userId;
  final String tenantId;
  final String? branchId;
  @JsonKey(fromJson: _roleFromJson, toJson: _roleToJson)
  final UserRole role;
  @JsonKey(fromJson: _permissionsFromJson, toJson: _permissionsToJson)
  final Set<Permission> permissions;
  final String? displayName;
  final String? profilePictureUrl;
  final String? phone;
  final String? address;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
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
    this.phone,
    this.address,
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
    final parsed = _$ProfileFromJson(map);
    if (!parsed.role.isOwner) return parsed;

    return Profile(
      id: parsed.id,
      userId: parsed.userId,
      tenantId: parsed.tenantId,
      branchId: parsed.branchId,
      role: parsed.role,
      permissions: Permission.values.toSet(),
      displayName: parsed.displayName,
      profilePictureUrl: parsed.profilePictureUrl,
      phone: parsed.phone,
      address: parsed.address,
      createdAt: parsed.createdAt,
      updatedAt: parsed.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => _$ProfileToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Branch {
  final String id;
  final String tenantId;
  final String? locationId;
  final String name;
  final String? address;
  final String? phone;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
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

  factory Branch.fromMap(Map<String, dynamic> map) => _$BranchFromJson(map);

  Map<String, dynamic> toMap() => _$BranchToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Category {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? updatedAt;

  Category({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  factory Category.fromMap(Map<String, dynamic> map) => _$CategoryFromJson(map);

  Map<String, dynamic> toMap() => _$CategoryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class ItemGroup {
  final String id;
  final String tenantId;
  final String? branchId;
  final String name;
  final String? description;
  final String? defaultCommissionType;
  final double? defaultCommissionValue;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
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

  factory ItemGroup.fromMap(Map<String, dynamic> map) =>
      _$ItemGroupFromJson(map);

  Map<String, dynamic> toMap() => _$ItemGroupToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
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
  final double? costPrice;
  final double? weight;
  final double? length;
  final double? width;
  final double? height;
  final String? taxCategory;
  @JsonKey(fromJson: _boolFromSqlite, toJson: _boolToSqlite)
  final bool isService;
  final String? uomId;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? updatedAt;

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
    String? uomId,
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
      uomId: uomId ?? this.uomId,
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
    this.costPrice,
    this.weight,
    this.length,
    this.width,
    this.height,
    this.taxCategory,
    this.isService = false,
    this.uomId,
    this.createdAt,
    this.updatedAt,
  });

  factory Product.fromMap(Map<String, dynamic> map) => _$ProductFromJson(map);

  Map<String, dynamic> toMap() => _$ProductToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Stock {
  final String id;
  final String tenantId;
  final String branchId;
  final String productId;
  final int quantity;
  final int? reorderLevel;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
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

  factory Stock.fromMap(Map<String, dynamic> map) => _$StockFromJson(map);

  Map<String, dynamic> toMap() => _$StockToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
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
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;
  final String status; // 'pending', 'approved', 'rejected'
  // Populated from JOIN queries — not stored:
  @JsonKey(name: 'adjuster_display_name', includeToJson: false)
  final String? adjusterName;
  @JsonKey(includeToJson: false)
  final String? reasonLabel;
  @JsonKey(includeToJson: false)
  final String? productName;

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
    this.status = 'approved',
    this.adjusterName,
    this.reasonLabel,
    this.productName,
  });

  factory StockAdjustment.fromMap(Map<String, dynamic> map) =>
      _$StockAdjustmentFromJson(map);

  Map<String, dynamic> toMap() => _$StockAdjustmentToJson(this);
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

@JsonSerializable(fieldRename: FieldRename.snake)
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

  factory StockItemGroup.fromMap(Map<String, dynamic> map) =>
      _$StockItemGroupFromJson(map);

  Map<String, dynamic> toMap() => _$StockItemGroupToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class CompositeItemComponent {
  @JsonKey(fromJson: _stringOrEmpty)
  final String id;
  final String tenantId;
  @JsonKey(fromJson: _stringOrEmpty)
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

  factory CompositeItemComponent.fromMap(Map<String, dynamic> map) =>
      _$CompositeItemComponentFromJson(map);

  Map<String, dynamic> toMap() => _$CompositeItemComponentToJson(this);

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

@JsonSerializable(fieldRename: FieldRename.snake)
class UnitOfMeasurement {
  final String id;
  final String tenantId;
  final String label;
  final String? abbreviation;
  final String? baseUnitId;
  final double conversionFactor;
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
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

  factory UnitOfMeasurement.fromMap(Map<String, dynamic> map) =>
      _$UnitOfMeasurementFromJson(map);

  Map<String, dynamic> toMap() => _$UnitOfMeasurementToJson(this);
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMISSION
// ─────────────────────────────────────────────────────────────────────────────

@JsonSerializable(fieldRename: FieldRename.snake)
class Commission {
  final String id;
  final String tenantId;
  final String salespersonId;
  final String saleId;
  final double amount;
  final String status; // 'pending', 'paid'
  @JsonKey(fromJson: _dateFromAny, toJson: _dateToIso)
  final DateTime? createdAt;

  Commission({
    required this.id,
    required this.tenantId,
    required this.salespersonId,
    required this.saleId,
    required this.amount,
    this.status = 'pending',
    this.createdAt,
  });

  factory Commission.fromMap(Map<String, dynamic> map) =>
      _$CommissionFromJson(map);

  Map<String, dynamic> toMap() => _$CommissionToJson(this);
}

// Aggregated commission data per salesperson (used in report screen)
class SalespersonCommissionSummary {
  final String salespersonId;
  final String salespersonName;
  final double totalPending;
  final double totalPaid;
  final int transactionCount;
  final double totalSalesAmount;
  final int salesCount;

  SalespersonCommissionSummary({
    required this.salespersonId,
    required this.salespersonName,
    required this.totalPending,
    required this.totalPaid,
    required this.transactionCount,
    this.totalSalesAmount = 0.0,
    this.salesCount = 0,
  });

  double get totalEarned => totalPending + totalPaid;
}
