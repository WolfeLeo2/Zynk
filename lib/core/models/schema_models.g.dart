// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schema_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tenant _$TenantFromJson(Map<String, dynamic> json) => Tenant(
  id: json['id'] as String,
  name: json['name'] as String,
  planType: json['plan_type'] as String?,
  address: json['address'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  logoUrl: json['logo_url'] as String?,
  createdAt: _dateFromAny(json['created_at']),
  updatedAt: _dateFromAny(json['updated_at']),
);

Map<String, dynamic> _$TenantToJson(Tenant instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'plan_type': instance.planType,
  'address': instance.address,
  'phone': instance.phone,
  'email': instance.email,
  'logo_url': instance.logoUrl,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  id: json['id'] as String,
  userId: json['user_id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  role: _roleFromJson(json['role'] as String?),
  permissions: _permissionsFromJson(json['permissions']),
  status:
      $enumDecodeNullable(_$ProfileStatusEnumMap, json['status']) ??
      ProfileStatus.active,
  displayName: json['display_name'] as String?,
  profilePictureUrl: json['profile_picture_url'] as String?,
  phone: json['phone'] as String?,
  address: json['address'] as String?,
  createdAt: _dateFromAny(json['created_at']),
  updatedAt: _dateFromAny(json['updated_at']),
);

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'id': instance.id,
  'user_id': instance.userId,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'role': _roleToJson(instance.role),
  'permissions': _permissionsToJson(instance.permissions),
  'display_name': instance.displayName,
  'profile_picture_url': instance.profilePictureUrl,
  'phone': instance.phone,
  'address': instance.address,
  'status': _$ProfileStatusEnumMap[instance.status]!,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

const _$ProfileStatusEnumMap = {
  ProfileStatus.active: 'active',
  ProfileStatus.inactive: 'inactive',
  ProfileStatus.blocked: 'blocked',
  ProfileStatus.deleted: 'deleted',
};

Branch _$BranchFromJson(Map<String, dynamic> json) => Branch(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  locationId: json['location_id'] as String?,
  name: json['name'] as String,
  address: json['address'] as String?,
  phone: json['phone'] as String?,
  createdAt: _dateFromAny(json['created_at']),
  updatedAt: _dateFromAny(json['updated_at']),
);

Map<String, dynamic> _$BranchToJson(Branch instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'location_id': instance.locationId,
  'name': instance.name,
  'address': instance.address,
  'phone': instance.phone,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

Category _$CategoryFromJson(Map<String, dynamic> json) => Category(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  name: json['name'] as String,
  createdAt: _dateFromAny(json['created_at']),
  updatedAt: _dateFromAny(json['updated_at']),
);

Map<String, dynamic> _$CategoryToJson(Category instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'name': instance.name,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

ItemGroup _$ItemGroupFromJson(Map<String, dynamic> json) => ItemGroup(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  name: json['name'] as String,
  description: json['description'] as String?,
  defaultCommissionType: json['default_commission_type'] as String?,
  defaultCommissionValue: (json['default_commission_value'] as num?)
      ?.toDouble(),
  defaultSellingPrice: (json['default_selling_price'] as num?)?.toDouble(),
  defaultBuyingPrice: (json['default_buying_price'] as num?)?.toDouble(),
  defaultPricingUnit: json['default_pricing_unit'] as String?,
  defaultCoveragePerBox: (json['default_coverage_per_box'] as num?)?.toDouble(),
  attributes: json['attributes'] as String?,
  createdAt: _dateFromAny(json['created_at']),
  updatedAt: _dateFromAny(json['updated_at']),
);

Map<String, dynamic> _$ItemGroupToJson(ItemGroup instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'name': instance.name,
  'description': instance.description,
  'default_commission_type': instance.defaultCommissionType,
  'default_commission_value': instance.defaultCommissionValue,
  'default_selling_price': instance.defaultSellingPrice,
  'default_buying_price': instance.defaultBuyingPrice,
  'default_pricing_unit': instance.defaultPricingUnit,
  'default_coverage_per_box': instance.defaultCoveragePerBox,
  'attributes': instance.attributes,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

Product _$ProductFromJson(Map<String, dynamic> json) => Product(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String?,
  itemGroupId: json['item_group_id'] as String?,
  categoryId: json['category_id'] as String?,
  name: json['name'] as String,
  sku: json['sku'] as String?,
  barcode: json['barcode'] as String?,
  description: json['description'] as String?,
  imageUrl: json['image_url'] as String?,
  basePrice: (json['base_price'] as num?)?.toDouble(),
  costPrice: (json['cost_price'] as num?)?.toDouble(),
  weight: (json['weight'] as num?)?.toDouble(),
  length: (json['length'] as num?)?.toDouble(),
  width: (json['width'] as num?)?.toDouble(),
  height: (json['height'] as num?)?.toDouble(),
  taxCategory: json['tax_category'] as String?,
  isService: json['is_service'] == null
      ? false
      : _boolFromSqlite(json['is_service']),
  uomId: json['uom_id'] as String?,
  commissionType: json['commission_type'] as String?,
  commissionValue: (json['commission_value'] as num?)?.toDouble(),
  pricingUnit: json['pricing_unit'] as String?,
  coveragePerBox: (json['coverage_per_box'] as num?)?.toDouble(),
  parentId: json['parent_id'] as String?,
  createdAt: _dateFromAny(json['created_at']),
  updatedAt: _dateFromAny(json['updated_at']),
);

Map<String, dynamic> _$ProductToJson(Product instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'item_group_id': instance.itemGroupId,
  'category_id': instance.categoryId,
  'name': instance.name,
  'sku': instance.sku,
  'barcode': instance.barcode,
  'description': instance.description,
  'image_url': instance.imageUrl,
  'base_price': instance.basePrice,
  'cost_price': instance.costPrice,
  'weight': instance.weight,
  'length': instance.length,
  'width': instance.width,
  'height': instance.height,
  'tax_category': instance.taxCategory,
  'is_service': _boolToSqlite(instance.isService),
  'uom_id': instance.uomId,
  'commission_type': instance.commissionType,
  'commission_value': instance.commissionValue,
  'pricing_unit': instance.pricingUnit,
  'coverage_per_box': instance.coveragePerBox,
  'parent_id': instance.parentId,
  'created_at': _dateToIso(instance.createdAt),
  'updated_at': _dateToIso(instance.updatedAt),
};

Stock _$StockFromJson(Map<String, dynamic> json) => Stock(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  branchId: json['branch_id'] as String,
  productId: json['product_id'] as String,
  quantity: (json['quantity'] as num).toInt(),
  reorderLevel: (json['reorder_level'] as num?)?.toInt(),
  lastUpdated: _dateFromAny(json['last_updated']),
);

Map<String, dynamic> _$StockToJson(Stock instance) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'product_id': instance.productId,
  'quantity': instance.quantity,
  'reorder_level': instance.reorderLevel,
  'last_updated': _dateToIso(instance.lastUpdated),
};

StockAdjustment _$StockAdjustmentFromJson(Map<String, dynamic> json) =>
    StockAdjustment(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      productId: json['product_id'] as String,
      adjustmentType: json['adjustment_type'] as String?,
      quantity: (json['quantity'] as num).toInt(),
      referenceNumber: json['reference_number'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      salespersonId: json['salesperson_id'] as String?,
      reasonId: json['reason_id'] as String?,
      createdAt: _dateFromAny(json['created_at']),
      status:
          $enumDecodeNullable(_$StockAdjustmentStatusEnumMap, json['status']) ??
          StockAdjustmentStatus.pending,
      bundleId: json['bundle_id'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: _dateFromAny(json['approved_at']),
      rejectionReason: json['rejection_reason'] as String?,
      previousQuantity: (json['previous_quantity'] as num?)?.toInt(),
      adjusterName: json['adjuster_display_name'] as String?,
      reasonLabel: json['reason_label'] as String?,
      productName: json['product_name'] as String?,
      uomAbbreviation: json['uom_abbreviation'] as String?,
      staffName: json['staff_name'] as String?,
    );

Map<String, dynamic> _$StockAdjustmentToJson(StockAdjustment instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'branch_id': instance.branchId,
      'product_id': instance.productId,
      'adjustment_type': instance.adjustmentType,
      'quantity': instance.quantity,
      'reference_number': instance.referenceNumber,
      'notes': instance.notes,
      'created_by': instance.createdBy,
      'salesperson_id': instance.salespersonId,
      'reason_id': instance.reasonId,
      'created_at': _dateToIso(instance.createdAt),
      'status': _$StockAdjustmentStatusEnumMap[instance.status]!,
      'bundle_id': instance.bundleId,
      'approved_by': instance.approvedBy,
      'approved_at': _dateToIso(instance.approvedAt),
      'rejection_reason': instance.rejectionReason,
      'previous_quantity': instance.previousQuantity,
    };

const _$StockAdjustmentStatusEnumMap = {
  StockAdjustmentStatus.pending: 'pending',
  StockAdjustmentStatus.approved: 'approved',
  StockAdjustmentStatus.rejected: 'rejected',
};

StockItemGroup _$StockItemGroupFromJson(Map<String, dynamic> json) =>
    StockItemGroup(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      attributes: json['attributes'] as String?,
    );

Map<String, dynamic> _$StockItemGroupToJson(StockItemGroup instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'name': instance.name,
      'description': instance.description,
      'attributes': instance.attributes,
    };

CompositeItemComponent _$CompositeItemComponentFromJson(
  Map<String, dynamic> json,
) => CompositeItemComponent(
  id: _stringOrEmpty(json['id']),
  tenantId: json['tenant_id'] as String,
  branchId: _stringOrEmpty(json['branch_id']),
  compositeProductId: json['composite_product_id'] as String,
  componentProductId: json['component_product_id'] as String,
  quantity: (json['quantity'] as num).toInt(),
);

Map<String, dynamic> _$CompositeItemComponentToJson(
  CompositeItemComponent instance,
) => <String, dynamic>{
  'id': instance.id,
  'tenant_id': instance.tenantId,
  'branch_id': instance.branchId,
  'composite_product_id': instance.compositeProductId,
  'component_product_id': instance.componentProductId,
  'quantity': instance.quantity,
};

UnitOfMeasurement _$UnitOfMeasurementFromJson(Map<String, dynamic> json) =>
    UnitOfMeasurement(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      label: json['label'] as String,
      abbreviation: json['abbreviation'] as String?,
      baseUnitId: json['base_unit_id'] as String?,
      conversionFactor: (json['conversion_factor'] as num?)?.toDouble() ?? 1.0,
      createdAt: _dateFromAny(json['created_at']),
    );

Map<String, dynamic> _$UnitOfMeasurementToJson(UnitOfMeasurement instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'label': instance.label,
      'abbreviation': instance.abbreviation,
      'base_unit_id': instance.baseUnitId,
      'conversion_factor': instance.conversionFactor,
      'created_at': _dateToIso(instance.createdAt),
    };

Commission _$CommissionFromJson(Map<String, dynamic> json) => Commission(
  id: json['id'] as String,
  tenantId: json['tenant_id'] as String,
  salespersonId: json['salesperson_id'] as String,
  saleId: json['sale_id'] as String,
  amount: (json['amount'] as num).toDouble(),
  status: json['status'] as String? ?? 'pending',
  createdAt: _dateFromAny(json['created_at']),
);

Map<String, dynamic> _$CommissionToJson(Commission instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'salesperson_id': instance.salespersonId,
      'sale_id': instance.saleId,
      'amount': instance.amount,
      'status': instance.status,
      'created_at': _dateToIso(instance.createdAt),
    };
