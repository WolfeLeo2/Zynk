import 'package:powersync/powersync.dart';
import 'package:zynk/core/models/schema_models.dart';

class PowerSyncRepository {
  final PowerSyncDatabase _db;

  PowerSyncRepository(this._db);

  // --- Database Management ---
  Future<void> clearDatabase() async {
    await _db.disconnectAndClear();
  }

  // --- Profiles ---
  Stream<Profile?> watchProfile(String userId) {
    return _db
        .watch('SELECT * FROM profiles WHERE user_id = ?', parameters: [userId])
        .map((results) {
          if (results.isEmpty) return null;
          return Profile.fromMap(results.first);
        });
  }

  Stream<Tenant?> watchTenant(String tenantId) {
    return _db
        .watch('SELECT * FROM tenants WHERE id = ?', parameters: [tenantId])
        .map((results) {
          if (results.isEmpty) return null;
          return Tenant.fromMap(results.first);
        });
  }

  Future<void> createProfile(Profile profile) async {
    await _db.execute(
      'INSERT INTO profiles (id, user_id, tenant_id, role, display_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        profile.id,
        profile.userId,
        profile.tenantId,
        profile.role.toShortString(),
        profile.displayName,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    // Construct dynamic update query
    final keys = updates.keys.toList();
    final values = updates.values.toList();
    final setClause = keys.map((k) => '$k = ?').join(', ');

    await _db.execute('UPDATE profiles SET $setClause WHERE user_id = ?', [
      ...values,
      userId,
    ]);
  }

  // --- Products ---
  Stream<List<Product>> watchProducts() {
    return _db
        .watch('SELECT * FROM products ORDER BY name ASC')
        .map((results) => results.map((row) => Product.fromMap(row)).toList());
  }

  Future<void> createProduct(Product product) async {
    await _db.execute(
      '''INSERT INTO products (
        id, tenant_id, item_group_id, category_id, name, sku, barcode, 
        description, image_url, base_price, cost_price, tax_category, is_service, 
        commission_type, commission_value, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        product.id,
        product.tenantId,
        product.itemGroupId,
        product.categoryId,
        product.name,
        product.sku,
        product.barcode,
        product.description,
        product.imageUrl,
        product.basePrice,
        product.costPrice, // Added
        product.taxCategory,
        product.isService ? 1 : 0,
        product.commissionType,
        product.commissionValue,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateProduct(Product product) async {
    await _db.execute(
      '''UPDATE products SET 
        item_group_id = ?, category_id = ?, name = ?, sku = ?, barcode = ?, 
        description = ?, image_url = ?, base_price = ?, cost_price = ?, tax_category = ?, is_service = ?, 
        commission_type = ?, commission_value = ?, updated_at = ?
      WHERE id = ?''',
      [
        product.itemGroupId,
        product.categoryId,
        product.name,
        product.sku,
        product.barcode,
        product.description,
        product.imageUrl,
        product.basePrice,
        product.costPrice,
        product.taxCategory,
        product.isService ? 1 : 0,
        product.commissionType,
        product.commissionValue,
        DateTime.now().toIso8601String(),
        product.id,
      ],
    );
  }

  // --- Categories ---
  Stream<List<Category>> watchCategories() {
    return _db
        .watch('SELECT * FROM categories ORDER BY name ASC')
        .map((results) => results.map((row) => Category.fromMap(row)).toList());
  }

  Future<void> createCategory(Category category) async {
    await _db.execute(
      'INSERT INTO categories (id, tenant_id, name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
      [
        category.id,
        category.tenantId,
        category.name,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  // --- Branches ---
  Future<List<Branch>> getBranches(String tenantId) async {
    final results = await _db.getAll(
      'SELECT * FROM branches WHERE tenant_id = ?',
      [tenantId],
    );
    return results.map((row) => Branch.fromMap(row)).toList();
  }

  Stream<List<Branch>> watchBranches(String tenantId) {
    return _db
        .watch(
          'SELECT * FROM branches WHERE tenant_id = ? ORDER BY created_at ASC',
          parameters: [tenantId],
        )
        .map((results) => results.map((row) => Branch.fromMap(row)).toList());
  }

  Future<void> createBranch(Branch branch) async {
    await _db.execute(
      'INSERT INTO branches (id, tenant_id, location_id, name, address, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [
        branch.id,
        branch.tenantId,
        branch.locationId,
        branch.name,
        branch.address,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  // --- Item Groups ---
  Stream<List<ItemGroup>> watchItemGroups() {
    return _db
        .watch('SELECT * FROM item_groups ORDER BY name ASC')
        .map(
          (results) => results.map((row) => ItemGroup.fromMap(row)).toList(),
        );
  }

  Future<void> createItemGroup(ItemGroup group) async {
    await _db.execute(
      'INSERT INTO item_groups (id, tenant_id, name, description, default_commission_type, default_commission_value, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        group.id,
        group.tenantId,
        group.name,
        group.description,
        group.defaultCommissionType,
        group.defaultCommissionValue,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  // --- Sale Items (New) ---
  // To handle invalid syntax error seen before in `AddProduct`? No that was for `ItemGroupsCompanion`
  // We need generic insert/update helpers perhaps?

  // --- Sync Status ---
  Stream<double> watchTotalSales() {
    return _db.watch('SELECT SUM(grand_total) as total FROM sales').map((
      results,
    ) {
      if (results.isEmpty || results.first['total'] == null) return 0.0;
      return (results.first['total'] as num).toDouble();
    });
  }

  Stream<int> watchStaffCount() {
    return _db.watch('SELECT COUNT(*) as count FROM profiles').map((results) {
      if (results.isEmpty) return 0;
      return (results.first['count'] as num).toInt();
    });
  }

  Stream<List<Profile>> watchStaff(String tenantId) {
    return _db
        .watch(
          'SELECT * FROM profiles WHERE tenant_id = ? ORDER BY created_at ASC',
          parameters: [tenantId],
        )
        .map((results) => results.map((row) => Profile.fromMap(row)).toList());
  }

  Stream<SyncStatus> get syncStatus => _db.statusStream;
}
