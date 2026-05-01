import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/adjustment_reason.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/staff_model.dart';

class PowerSyncRepository {
  final PowerSyncDatabase _db;

  static const Set<String> _allowedStockAdjustmentTypes = {
    'addition',
    'reduction',
    'initial',
    'damage',
  };

  PowerSyncRepository(this._db);

  PowerSyncDatabase get db => _db;

  void _ensureSpecificBranchId(String branchId) {
    if (branchId.isEmpty || branchId == 'all') {
      throw Exception(
        'Please select a specific branch before adjusting stock.',
      );
    }
  }

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
      'INSERT INTO profiles (id, user_id, tenant_id, role, display_name, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        profile.id,
        profile.userId,
        profile.tenantId,
        profile.role.toShortString(),
        profile.displayName,
        profile.status.name,
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

  /// Updates a user profile's status (active, inactive, deleted).
  /// This also invokes the 'manage-user-status' Edge Function to ban/unban the user in Supabase Auth.
  Future<void> updateProfileStatus({
    required String userId,
    required ProfileStatus status,
  }) async {
    final statusStr = status.name;
    // 1. Invoke Edge Function for Auth-level ban/unban
    final response = await Supabase.instance.client.functions.invoke(
      'manage-user-status',
      body: {'userId': userId, 'status': statusStr},
    );

    if (response.status != 200) {
      throw Exception(response.data?['error'] ?? 'Failed to update user auth status');
    }

    // 2. Update local DB status (PowerSync will sync this)
    await _db.execute(
      'UPDATE profiles SET status = ?, updated_at = ? WHERE user_id = ?',
      [statusStr, DateTime.now().toIso8601String(), userId],
    );
  }

  Stream<List<String>> watchProfileBranchIds(String profileId) {
    return _db.watch(
      'SELECT branch_id FROM profile_branches WHERE profile_id = ?',
      parameters: [profileId],
    ).map((results) => results.map((row) => row['branch_id'] as String).toList());
  }

  Future<void> deleteProfile(String userId) async {
    // Soft delete via status
    await updateProfileStatus(userId: userId, status: ProfileStatus.deleted);
  }

  Future<void> updateStaffMemberStatus({
    required String memberId,
    required StaffStatus status,
  }) async {
    await _db.execute(
      'UPDATE staff_members SET status = ?, updated_at = ? WHERE id = ?',
      [status.name, DateTime.now().toIso8601String(), memberId],
    );
  }

  /// Updates a staff member's profile fields and replaces their branch assignments.
  Future<void> updateStaffProfile({
    required String profileId,
    required String userId,
    required String tenantId,
    required String displayName,
    required String role,
    required String permissions,
    required String primaryBranchId,
    required List<String> branchIds,
    String? phone,
    String? address,
  }) async {
    await _db.writeTransaction((tx) async {
      // 1. Update the profiles row
      await tx.execute(
        '''UPDATE profiles SET
            display_name = ?,
            role = ?,
            permissions = ?,
            branch_id = ?,
            phone = ?,
            address = ?,
            updated_at = ?
           WHERE user_id = ?''',
        [
          displayName,
          role,
          permissions,
          primaryBranchId,
          phone,
          address,
          DateTime.now().toIso8601String(),
          userId,
        ],
      );

      // 2. Clear old branch assignments then re-insert
      await tx.execute(
        'DELETE FROM profile_branches WHERE profile_id = ?',
        [profileId],
      );

      for (final branchId in branchIds) {
        await tx.execute(
          '''INSERT INTO profile_branches (id, tenant_id, profile_id, branch_id, created_at)
             VALUES (?, ?, ?, ?, ?)''',
          [
            const Uuid().v4(),
            tenantId,
            profileId,
            branchId,
            DateTime.now().toIso8601String(),
          ],
        );
      }
    });
  }

  /// Invokes the 'update-staff-user' Edge Function to sync Auth metadata and permissions.
  Future<void> updateStaffRemote({
    required String userId,
    required String name,
    required String role,
    required String primaryBranchId,
    required List<String> branchIds,
    required List<String> permissions,
    String? phone,
    String? address,
  }) async {
    final response = await Supabase.instance.client.functions.invoke(
      'update-staff-user',
      body: {
        'user_id': userId,
        'name': name,
        'role': role,
        'branch_id': primaryBranchId,
        'branch_ids': branchIds,
        'permissions': permissions,
        'phone': phone,
        'address': address,
      },
    );

    if (response.status != 200) {
      throw Exception(
          response.data?['error'] ?? 'Failed to update staff auth metadata');
    }
  }

  Future<void> updateTenant(
    String tenantId,
    Map<String, dynamic> updates,
  ) async {
    final keys = updates.keys.toList();
    final values = updates.values.toList();
    final setClause = keys.map((k) => '$k = ?').join(', ');

    await _db.execute('UPDATE tenants SET $setClause WHERE id = ?', [
      ...values,
      tenantId,
    ]);
  }

  // --- Staff Members ---
  Stream<List<StaffMember>> watchStaffMembers(
    String tenantId, {
    String? branchId,
  }) {
    String sql =
        "SELECT * FROM staff_members WHERE tenant_id = ? AND status != 'deleted'";
    final params = <dynamic>[tenantId];

    if (branchId != null && branchId != 'all') {
      sql += " AND (branch_id = ? OR branch_id IS NULL)";
      params.add(branchId);
    }

    sql += " ORDER BY name ASC";

    return _db.watch(sql, parameters: params).map(
      (results) => results
          .map((row) => StaffMember.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
    );
  }

  Future<void> createStaffMember(StaffMember member) async {
    await _db.execute(
      '''INSERT INTO staff_members
        (id, tenant_id, branch_id, name, phone, email, profile_picture_url, status, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        member.id,
        member.tenantId,
        member.branchId,
        member.name,
        member.phone,
        member.email,
        member.profilePictureUrl,
        member.status.name,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateStaffMember(StaffMember member) async {
    await _db.execute(
      '''UPDATE staff_members
        SET name = ?, phone = ?, email = ?, profile_picture_url = ?, status = ?, branch_id = ?, updated_at = ?
        WHERE id = ?''',
        [
          member.name,
          member.phone,
          member.email,
          member.profilePictureUrl,
          member.status.name,
          member.branchId,
          DateTime.now().toIso8601String(),
          member.id,
        ],
    );
  }

  Future<void> deleteStaffMember(String memberId) async {
    // Soft delete by setting status to inactive
    await _db.execute(
      'UPDATE staff_members SET status = ?, updated_at = ? WHERE id = ?',
      [StaffStatus.inactive.name, DateTime.now().toIso8601String(), memberId],
    );
  }

  // --- Products ---
  Stream<List<Product>> watchProducts({String? branchId}) {
    String sql;
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      // Primary model: product_branches controls branch visibility.
      // Fallback model: legacy products.branch_id and stock presence.
      sql = '''
        SELECT DISTINCT p.*
        FROM products p
        LEFT JOIN product_branches pb
          ON pb.product_id = p.id
        WHERE pb.branch_id = ?
           OR p.branch_id = ?
           OR (
                p.branch_id IS NULL
                AND NOT EXISTS (
                  SELECT 1
                  FROM product_branches pb2
                  WHERE pb2.product_id = p.id
                )
              )
           OR EXISTS (
                SELECT 1
                FROM stock st
                WHERE st.product_id = p.id
                  AND st.branch_id = ?
              )
        ORDER BY p.name ASC
      ''';
      params.add(branchId);
      params.add(branchId);
      params.add(branchId);
    } else {
      sql = 'SELECT * FROM products ORDER BY name ASC';
    }

    return _db
        .watch(sql, parameters: params)
        .map((results) => results.map((row) => Product.fromMap(row)).toList());
  }

  Future<void> replaceProductBranches({
    required String tenantId,
    required String productId,
    required List<String> branchIds,
  }) async {
    final normalizedBranchIds = branchIds
        .where((id) => id.isNotEmpty && id != 'all')
        .toSet()
        .toList();

    await _db.writeTransaction((tx) async {
      await tx.execute('DELETE FROM product_branches WHERE product_id = ?', [
        productId,
      ]);

      for (final branchId in normalizedBranchIds) {
        await tx.execute(
          '''INSERT INTO product_branches (
               id, tenant_id, product_id, branch_id, created_at
             ) VALUES (?, ?, ?, ?, ?)''',
          [
            const Uuid().v4(),
            tenantId,
            productId,
            branchId,
            DateTime.now().toIso8601String(),
          ],
        );
      }
    });
  }

  Future<void> createProduct(
    Product product, {
    List<String>? targetBranchIds,
  }) async {
    final effectiveBranchIds = (targetBranchIds ?? const <String>[])
        .where((id) => id.isNotEmpty && id != 'all')
        .toSet()
        .toList();

    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''INSERT INTO products (
          id, tenant_id, branch_id, item_group_id, category_id, uom_id, name, sku, barcode,
          description, image_url, base_price, cost_price, tax_category, is_service,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          product.id,
          product.tenantId,
          product.branchId,
          product.itemGroupId,
          product.categoryId,
          product.uomId,
          product.name,
          product.sku,
          product.barcode,
          product.description,
          product.imageUrl,
          product.basePrice,
          product.costPrice,
          product.taxCategory,
          product.isService ? 1 : 0,
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );

      for (final branchId in effectiveBranchIds) {
        await tx.execute(
          '''INSERT INTO product_branches (
               id, tenant_id, product_id, branch_id, created_at
             ) VALUES (?, ?, ?, ?, ?)''',
          [
            const Uuid().v4(),
            product.tenantId,
            product.id,
            branchId,
            DateTime.now().toIso8601String(),
          ],
        );
      }
    });
  }

  Future<void> updateProduct(
    Product product, {
    List<String>? targetBranchIds,
  }) async {
    final normalizedBranchIds = targetBranchIds
        ?.where((id) => id.isNotEmpty && id != 'all')
        .toSet()
        .toList();

    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''UPDATE products SET
          branch_id = ?, item_group_id = ?, category_id = ?, uom_id = ?, name = ?, sku = ?, barcode = ?,
          description = ?, image_url = ?, base_price = ?, cost_price = ?, tax_category = ?,
          is_service = ?, updated_at = ?
        WHERE id = ?''',
        [
          product.branchId,
          product.itemGroupId,
          product.categoryId,
          product.uomId,
          product.name,
          product.sku,
          product.barcode,
          product.description,
          product.imageUrl,
          product.basePrice,
          product.costPrice,
          product.taxCategory,
          product.isService ? 1 : 0,
          DateTime.now().toIso8601String(),
          product.id,
        ],
      );

      if (normalizedBranchIds != null) {
        await tx.execute('DELETE FROM product_branches WHERE product_id = ?', [
          product.id,
        ]);
        for (final branchId in normalizedBranchIds) {
          await tx.execute(
            '''INSERT INTO product_branches (
                 id, tenant_id, product_id, branch_id, created_at
               ) VALUES (?, ?, ?, ?, ?)''',
            [
              const Uuid().v4(),
              product.tenantId,
              product.id,
              branchId,
              DateTime.now().toIso8601String(),
            ],
          );
        }
      }
    });
  }

  Stream<List<Stock>> watchStockByProductIds(
    List<String> productIds, {
    String? branchId,
  }) {
    if (productIds.isEmpty) return Stream.value([]);
    final placeholders = List.filled(productIds.length, '?').join(', ');
    var sql = 'SELECT * FROM stock WHERE product_id IN ($placeholders)';
    final params = List<dynamic>.from(productIds);

    if (branchId != null) {
      sql += ' AND branch_id = ?';
      params.add(branchId);
    }

    return _db.watch(sql, parameters: params).map((rows) {
      return rows.map((row) => Stock.fromMap(row)).toList();
    });
  }

  Stream<List<Stock>> watchProductBranchStocks(String productId) {
    return _db
        .watch(
          'SELECT * FROM stock WHERE product_id = ? ORDER BY branch_id ASC',
          parameters: [productId],
        )
        .map((rows) => rows.map((row) => Stock.fromMap(row)).toList());
  }

  Future<void> batchUpdateProductGroups(
    List<String> productIds,
    String? groupId,
  ) async {
    if (productIds.isEmpty) return;
    final placeholders = List.filled(productIds.length, '?').join(', ');
    final args = <Object?>[
      groupId,
      DateTime.now().toIso8601String(),
      ...productIds,
    ];
    await _db.execute(
      'UPDATE products SET item_group_id = ?, updated_at = ? WHERE id IN ($placeholders)',
      args,
    );
  }

  // --- Stock & Inventory ---
  Stream<Stock?> watchProductStock(String productId, {String? branchId}) {
    if (branchId != null && branchId != 'all') {
      return _db
          .watch(
            'SELECT * FROM stock WHERE product_id = ? AND branch_id = ?',
            parameters: [productId, branchId],
          )
          .map((rows) => rows.isEmpty ? null : Stock.fromMap(rows.first));
    }

    return _db
        .watch(
          'SELECT * FROM stock WHERE product_id = ?',
          parameters: [productId],
        )
        .map((rows) {
          if (rows.isEmpty) return null;

          final first = rows.first;
          final quantity = rows.fold<int>(
            0,
            (sum, row) => sum + ((row['quantity'] as num?)?.toInt() ?? 0),
          );

          DateTime? latestUpdatedAt;
          for (final row in rows) {
            final raw = row['last_updated']?.toString();
            if (raw == null || raw.isEmpty) continue;
            final parsed = DateTime.tryParse(raw);
            if (parsed == null) continue;
            if (latestUpdatedAt == null || parsed.isAfter(latestUpdatedAt)) {
              latestUpdatedAt = parsed;
            }
          }

          return Stock(
            id: first['id']?.toString() ?? productId,
            tenantId: first['tenant_id']?.toString() ?? '',
            branchId: 'all',
            productId: productId,
            quantity: quantity,
            reorderLevel: (first['reorder_level'] as num?)?.toInt(),
            lastUpdated: latestUpdatedAt,
          );
        });
  }

  Stream<List<Map<String, dynamic>>> watchLowStockProducts({
    required String tenantId,
    String? branchId,
  }) {
    String branchFilter = '';
    final params = <dynamic>[tenantId];
    if (branchId != null && branchId != 'all') {
      branchFilter = ' AND st.branch_id = ?';
      params.add(branchId);
    }

    return _db.watch('''
      SELECT p.id, p.name, p.image_url, st.quantity, st.reorder_level 
      FROM products p
      JOIN stock st ON p.id = st.product_id
      WHERE st.tenant_id = ? $branchFilter
        AND st.quantity <= st.reorder_level
        AND st.quantity >= 0
      ORDER BY st.quantity ASC
      LIMIT 20
    ''', parameters: params).map((results) => results.toList());
  }

  Stream<List<StockAdjustment>> watchProductStockHistory(
    String productId, {
    String? branchId,
  }) {
    var sql = '''
      SELECT 
        sa.*,
        p.display_name AS adjuster_display_name,
        r.label AS reason_label
      FROM stock_adjustments sa
      LEFT JOIN profiles p ON p.user_id = sa.created_by
      LEFT JOIN stock_adjustment_reasons r ON r.id = sa.reason_id
      WHERE sa.product_id = ?
    ''';
    final params = <dynamic>[productId];

    if (branchId != null && branchId != 'all') {
      sql += ' AND sa.branch_id = ?';
      params.add(branchId);
    }
    sql += ' ORDER BY sa.created_at DESC';

    return _db
        .watch(sql, parameters: params)
        .map(
          (rows) => rows.map((row) => StockAdjustment.fromMap(row)).toList(),
        );
  }

  Future<void> adjustStock({
    required String tenantId,
    required String branchId,
    required String productId,
    required String adjustmentType, // 'addition', 'reduction', 'initial', 'damage'
    required int quantityChange,
    required String createdBy,
    String? referenceNumber,
    String? notes,
    String? reasonId,
    String? bundleId,
  }) async {
    _ensureSpecificBranchId(branchId);

    await _db.writeTransaction((tx) async {
      await _adjustStockInTx(
        tx,
        tenantId: tenantId,
        branchId: branchId,
        productId: productId,
        adjustmentType: adjustmentType,
        quantityChange: quantityChange,
        createdBy: createdBy,
        referenceNumber: referenceNumber,
        notes: notes,
        reasonId: reasonId,
        bundleId: bundleId,
      );
    });
  }

  Future<void> _adjustStockInTx(
    dynamic tx, {
    required String tenantId,
    required String branchId,
    required String productId,
    required String adjustmentType,
    required int quantityChange,
    required String createdBy,
    String? referenceNumber,
    String? notes,
    String? reasonId,
    String? bundleId,
  }) async {
    if (quantityChange == 0) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final resolvedAdjustmentType = _resolveStockAdjustmentType(
      adjustmentType,
      quantityChange,
    );

    // Insert stock adjustment log with status 'pending'
    // Stock movement now happens only upon Approval.
    await tx.execute(
      '''INSERT INTO stock_adjustments (
        id, tenant_id, branch_id, product_id, quantity, 
        reference_number, notes, created_by, reason_id, 
        adjustment_type, created_at, status, bundle_id
      ) VALUES (uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)''',
      [
        tenantId,
        branchId,
        productId,
        quantityChange,
        referenceNumber,
        notes,
        createdBy,
        reasonId,
        resolvedAdjustmentType,
        now,
        bundleId,
      ],
    );
  }

  Future<void> batchAdjustStock({
    required String tenantId,
    required String branchId,
    required List<BatchAdjustmentItem> items,
    required String createdBy,
    required String adjustmentType,
    String? reasonId,
    String? referenceNumber,
  }) async {
    _ensureSpecificBranchId(branchId);

    await _db.writeTransaction((tx) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final bundleId = const Uuid().v4();
      
      for (final item in items) {
        if (item.quantityChange == 0) continue;

        final resolvedAdjustmentType = _resolveStockAdjustmentType(
          adjustmentType,
          item.quantityChange,
        );

        await tx.execute(
          '''INSERT INTO stock_adjustments (
            id, tenant_id, branch_id, product_id, quantity, 
            reference_number, notes, created_by, reason_id, 
            adjustment_type, created_at, status, bundle_id
          ) VALUES (uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)''',
          [
            tenantId,
            branchId,
            item.productId,
            item.quantityChange,
            referenceNumber,
            item.notes,
            createdBy,
            reasonId,
            resolvedAdjustmentType,
            now,
            bundleId,
          ],
        );
      }
    });
  }

  String _resolveStockAdjustmentType(String rawType, int quantityChange) {
    final normalized = rawType.trim().toLowerCase();

    if (_allowedStockAdjustmentTypes.contains(normalized)) {
      if (normalized == 'addition' && quantityChange < 0) {
        return 'reduction';
      }
      if (normalized == 'reduction' && quantityChange > 0) {
        return 'addition';
      }
      return normalized;
    }

    if (quantityChange < 0) return 'reduction';
    if (quantityChange > 0) return 'addition';
    return 'initial';
  }

  // --- Adjustment Reasons ---
  Stream<List<AdjustmentReason>> watchAdjustmentReasons(String tenantId) {
    return _db
        .watch(
          'SELECT * FROM stock_adjustment_reasons WHERE tenant_id = ? ORDER BY label ASC',
          parameters: [tenantId],
        )
        .map((rows) => rows.map((r) => AdjustmentReason.fromMap(r)).toList());
  }

  Future<void> createAdjustmentReason(AdjustmentReason reason) async {
    await _db.execute(
      '''INSERT INTO stock_adjustment_reasons (id, tenant_id, label, created_at)
         VALUES (?, ?, ?, ?)''',
      [
        reason.id,
        reason.tenantId,
        reason.label,
        reason.createdAt?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<void> deleteAdjustmentReason(String id) async {
    await _db.execute('DELETE FROM stock_adjustment_reasons WHERE id = ?', [
      id,
    ]);
  }

  // --- Categories ---
  Stream<List<Category>> watchCategories() {
    return _db
        .watch('SELECT * FROM categories ORDER BY name ASC')
        .map((results) => results.map((row) => Category.fromMap(row)).toList());
  }

  Future<void> createCategory(Category category) async {
    await _db.execute(
      'INSERT INTO categories (id, tenant_id, branch_id, name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        category.id,
        category.tenantId,
        category.branchId,
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

  Stream<List<Branch>> watchAccessibleBranches({
    required String tenantId,
    required String userId,
    required bool isOwner,
  }) {
    if (isOwner) {
      return watchBranches(tenantId);
    }

    return _db
        .watch(
          '''
          SELECT b.*
          FROM branches b
          WHERE b.tenant_id = ?
            AND EXISTS (
              SELECT 1
              FROM profiles p
              LEFT JOIN profile_branches pb
                ON pb.profile_id = p.id
               AND pb.branch_id = b.id
              WHERE p.user_id = ?
                AND p.tenant_id = b.tenant_id
                AND (pb.branch_id IS NOT NULL OR p.branch_id = b.id)
            )
          ORDER BY b.created_at ASC
          ''',
          parameters: [tenantId, userId],
        )
        .map((results) => results.map((row) => Branch.fromMap(row)).toList());
  }

  Future<void> createBranch(Branch branch) async {
    await _db.execute(
      'INSERT INTO branches (id, tenant_id, location_id, name, address, phone, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        branch.id,
        branch.tenantId,
        branch.locationId,
        branch.name,
        branch.address,
        branch.phone,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateBranch(
    String branchId,
    Map<String, dynamic> updates,
  ) async {
    if (updates.isEmpty) return;

    updates['updated_at'] = DateTime.now().toIso8601String();

    final sets = updates.keys.map((k) => '$k = ?').join(', ');
    final values = updates.values.toList();
    values.add(branchId);

    await _db.execute('UPDATE branches SET $sets WHERE id = ?', values);
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
      'INSERT INTO item_groups (id, tenant_id, branch_id, name, description, default_commission_type, default_commission_value, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        group.id,
        group.tenantId,
        group.branchId,
        group.name,
        group.description,
        group.defaultCommissionType,
        group.defaultCommissionValue,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateItemGroup(ItemGroup group) async {
    await _db.execute(
      'UPDATE item_groups SET name = ?, description = ?, default_commission_type = ?, default_commission_value = ?, updated_at = ? WHERE id = ?',
      [
        group.name,
        group.description,
        group.defaultCommissionType,
        group.defaultCommissionValue,
        DateTime.now().toIso8601String(),
        group.id,
      ],
    );
  }

  /// Nullifies item_group_id for all products in a group (ungroup items)
  Future<void> ungroupProductsForGroup(String groupId) async {
    await _db.execute(
      'UPDATE products SET item_group_id = NULL, updated_at = ? WHERE item_group_id = ?',
      [DateTime.now().toIso8601String(), groupId],
    );
  }

  /// Deletes all products belonging to a group, then deletes the group
  Future<void> deleteGroupAndAllItems(String groupId) async {
    await _db.writeTransaction((tx) async {
      await tx.execute('DELETE FROM products WHERE item_group_id = ?', [
        groupId,
      ]);
      await tx.execute('DELETE FROM item_groups WHERE id = ?', [groupId]);
    });
  }

  /// Deletes the group only; items become ungrouped first
  Future<void> deleteGroupOnly(String groupId) async {
    await _db.writeTransaction((tx) async {
      await tx.execute(
        'UPDATE products SET item_group_id = NULL, updated_at = ? WHERE item_group_id = ?',
        [DateTime.now().toIso8601String(), groupId],
      );
      await tx.execute('DELETE FROM item_groups WHERE id = ?', [groupId]);
    });
  }

  /// Sets the base_price of all products in a group
  Future<void> batchSetPriceForGroup(String groupId, double newPrice) async {
    await _db.execute(
      'UPDATE products SET base_price = ?, updated_at = ? WHERE item_group_id = ?',
      [newPrice, DateTime.now().toIso8601String(), groupId],
    );
  }

  /// Adjusts stock for all products in a group with full audit trail.
  /// Delegates to [batchAdjustStock] so every change is logged in
  /// stock_adjustments with a reason, reference number, and adjuster.
  /// mode: 'add' | 'subtract' | 'set'
  Future<void> batchAdjustStockForGroup({
    required String groupId,
    required String tenantId,
    required String branchId,
    required int quantity,
    required String mode,
    required String adjusterId,
    required String adjustmentType,
    String? reasonId,
    String? referenceNumber,
  }) async {
    _ensureSpecificBranchId(branchId);

    // 1. Fetch all product IDs in the group
    final rows = await _db.getAll(
      'SELECT id FROM products WHERE item_group_id = ?',
      [groupId],
    );
    if (rows.isEmpty) return;

    final items = <BatchAdjustmentItem>[];

    for (final row in rows) {
      final productId = row['id'] as String;
      int quantityChange;

      if (mode == 'set') {
        // Compute delta: desired - current
        final stockRows = await _db.getAll(
          'SELECT quantity FROM stock WHERE product_id = ? AND branch_id = ?',
          [productId, branchId],
        );
        final current = stockRows.isNotEmpty
            ? (stockRows.first['quantity'] as num?)?.toInt() ?? 0
            : 0;
        quantityChange = quantity - current;
      } else if (mode == 'add') {
        quantityChange = quantity;
      } else {
        // subtract — store as negative delta
        quantityChange = -quantity;
      }

      items.add(
        BatchAdjustmentItem(
          productId: productId,
          quantityChange: quantityChange,
        ),
      );
    }

    await batchAdjustStock(
      tenantId: tenantId,
      branchId: branchId,
      items: items,
      createdBy: adjusterId,
      adjustmentType: adjustmentType,
      reasonId: reasonId,
      referenceNumber: referenceNumber,
    );
  }

  // --- Composite Items ---
  Stream<List<CompositeItemComponent>> watchCompositeComponents(
    String parentId,
  ) {
    return _db
        .watch(
          'SELECT * FROM composite_item_components WHERE composite_product_id = ?',
          parameters: [parentId],
        )
        .map(
          (results) => results
              .map((row) => CompositeItemComponent.fromMap(row))
              .toList(),
        );
  }

  Future<void> createCompositeProduct(
    Product product,
    List<CompositeItemComponent> components,
  ) async {
    await _db.writeTransaction((tx) async {
      // 1. Create the product
      await tx.execute(
        '''INSERT INTO products (
          id, tenant_id, branch_id, item_group_id, category_id, uom_id, name, sku, barcode, 
          description, image_url, base_price, cost_price, tax_category, is_service, 
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          product.id,
          product.tenantId,
          product.branchId,
          product.itemGroupId,
          product.categoryId,
          product.uomId,
          product.name,
          product.sku,
          product.barcode,
          product.description,
          product.imageUrl,
          product.basePrice,
          product.costPrice,
          product.taxCategory,
          product.isService ? 1 : 0,
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );

      // 2. Add components
      for (final component in components) {
        await tx.execute(
          '''INSERT INTO composite_item_components (
            id, tenant_id, branch_id, composite_product_id, component_product_id, quantity
          ) VALUES (?, ?, ?, ?, ?, ?)''',
          [
            component.id.isEmpty ? const Uuid().v4() : component.id,
            component.tenantId,
            component.branchId,
            product.id,
            component.componentProductId,
            component.quantity,
          ],
        );
      }
    });
  }

  // --- Units of Measurement ---
  Stream<List<UnitOfMeasurement>> watchUnitOfMeasurements() {
    return _db
        .watch('SELECT * FROM units_of_measurement ORDER BY label ASC')
        .map(
          (results) =>
              results.map((row) => UnitOfMeasurement.fromMap(row)).toList(),
        );
  }

  Future<void> createUnitOfMeasurement(UnitOfMeasurement uom) async {
    await _db.execute(
      '''INSERT INTO units_of_measurement (
        id, tenant_id, label, abbreviation, base_unit_id, conversion_factor, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [
        uom.id,
        uom.tenantId,
        uom.label,
        uom.abbreviation,
        uom.baseUnitId,
        uom.conversionFactor,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  // --- Customers ---
  Stream<List<Customer>> watchCustomers() {
    return _db
        .watch('SELECT * FROM customers ORDER BY name ASC')
        .map((results) => results.map((row) => Customer.fromMap(row)).toList());
  }

  Future<void> createCustomer(Customer customer) async {
    await _db.execute(
      'INSERT INTO customers (id, tenant_id, branch_id, name, phone, email, loyalty_points, credit_limit, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        customer.id,
        customer.tenantId,
        customer.branchId,
        customer.name,
        customer.phone,
        customer.email,
        customer.loyaltyPoints,
        customer.creditLimit,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateCustomer(Customer customer) async {
    await _db.execute(
      'UPDATE customers SET name = ?, phone = ?, email = ?, loyalty_points = ?, credit_limit = ?, updated_at = ? WHERE id = ?',
      [
        customer.name,
        customer.phone,
        customer.email,
        customer.loyaltyPoints,
        customer.creditLimit,
        DateTime.now().toIso8601String(),
        customer.id,
      ],
    );
  }

  Future<void> deleteCustomer(String id) async {
    await _db.execute('DELETE FROM customers WHERE id = ?', [id]);
  }

  // --- Sales / Invoices ---

  /// Watch all sales for a tenant, optionally filtered by status and/or branch
  Stream<List<Sale>> watchSales({
    String? tenantId,
    String? branchId,
    InvoiceStatus? status,
    int limit = 50,
  }) {
    var sql = 'SELECT * FROM sales WHERE 1=1';
    final params = <dynamic>[];

    if (tenantId != null) {
      sql += ' AND tenant_id = ?';
      params.add(tenantId);
    }
    if (branchId != null && branchId != 'all') {
      sql += ' AND branch_id = ?';
      params.add(branchId);
    }
    if (status != null) {
      sql += ' AND status = ?';
      params.add(status.value);
    }
    sql += ' ORDER BY created_at DESC LIMIT ?';
    params.add(limit);

    return _db
        .watch(sql, parameters: params)
        .map((rows) => rows.map((row) => Sale.fromMap(row)).toList());
  }

  /// Watch a single sale by ID
  Stream<Sale?> watchSaleById(String saleId) {
    return _db
        .watch('SELECT * FROM sales WHERE id = ?', parameters: [saleId])
        .map((rows) => rows.isEmpty ? null : Sale.fromMap(rows.first));
  }

  /// Watch sale items for a specific sale, joined with product name
  Stream<List<SaleItem>> watchSaleItems(String saleId) {
    return _db
        .watch(
          '''SELECT si.*, COALESCE(si.product_name, p.name) as product_name, p.image_url as product_image_url
         FROM sale_items si
         LEFT JOIN products p ON si.product_id = p.id
         WHERE si.sale_id = ?
         ORDER BY si.created_at ASC''',
          parameters: [saleId],
        )
        .map((rows) => rows.map((row) => SaleItem.fromMap(row)).toList());
  }

  /// Watch approval events for a specific sale, oldest first for timeline.
  Stream<List<SaleApproval>> watchSaleApprovals(String saleId) {
    return _db
        .watch(
          '''SELECT sa.*, p.display_name AS approver_display_name
             FROM sale_approvals sa
             LEFT JOIN profiles p ON p.user_id = sa.approver_user_id
             WHERE sa.sale_id = ?
             ORDER BY sa.created_at ASC''',
          parameters: [saleId],
        )
        .map((rows) => rows.map((row) => SaleApproval.fromMap(row)).toList());
  }

  /// Updates an existing draft/pending_approval invoice header and replaces its items.
  /// Only allowed on unpaid sales with no recorded payments.
  Future<void> updateSaleDraft({
    required String saleId,
    required String customerId,
    required String tenantId,
    required List<SaleItem> items,
    String? salespersonId,
    String? notes,
    String? dueDate,
  }) async {
    await _db.writeTransaction((tx) async {
      final now = DateTime.now().toIso8601String();

      // Recalculate totals from updated items
      double subtotal = 0;
      for (final item in items) {
        subtotal += item.total;
      }
      final grandTotal = subtotal;

      // Update sale header
      await tx.execute(
        '''UPDATE sales SET customer_id = ?, salesperson_id = ?, subtotal = ?, total_amount = ?, grand_total = ?, notes = ?, due_date = ?, updated_at = ? WHERE id = ?''',
        [
          customerId,
          salespersonId,
          subtotal,
          grandTotal,
          grandTotal,
          notes,
          dueDate,
          now,
          saleId,
        ],
      );

      // Delete existing items and re-insert
      await tx.execute('DELETE FROM sale_items WHERE sale_id = ?', [saleId]);
      for (final item in items) {
        await tx.execute(
          '''INSERT INTO sale_items (id, sale_id, product_id, tenant_id, quantity, unit_price, cost_price, tax_amount, discount, total, product_name, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            item.id,
            saleId,
            item.productId,
            tenantId,
            item.quantity,
            item.unitPrice,
            item.costPrice,
            item.taxAmount,
            item.discount,
            item.total,
            item.productName,
            now,
            now,
          ],
        );
      }
    });
  }

  // --- Payments ---

  /// Watch all payments for a specific sale
  Stream<List<Payment>> watchPaymentsForSale(String saleId) {
    return _db
        .watch(
          'SELECT * FROM sale_payments WHERE sale_id = ? ORDER BY created_at ASC',
          parameters: [saleId],
        )
        .map((rows) => rows.map((row) => Payment.fromMap(row)).toList());
  }

  /// Record payment offline locally and auto-update sale status / amount paid
  Future<void> recordPaymentLocally({
    required String saleId,
    required double amount,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    await _db.writeTransaction((tx) async {
      // 1. Fetch current sale
      final saleRow = await tx.getOptional('SELECT * FROM sales WHERE id = ?', [
        saleId,
      ]);
      if (saleRow == null) throw Exception('Sale not found locally');
      final sale = Sale.fromMap(saleRow);

      // 2. Insert payment
      final paymentId = uuid.v4();
      final now = DateTime.now().toIso8601String();
      await tx.execute(
        'INSERT INTO sale_payments (id, tenant_id, branch_id, sale_id, amount, payment_method, reference_number, notes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          paymentId,
          sale.tenantId,
          sale.branchId,
          sale.id,
          amount,
          paymentMethod,
          referenceNumber,
          notes,
          now,
          now,
        ],
      );

      // 3. Update sale totals & status
      final newAmountPaid = sale.amountPaid + amount;
      var newPaymentStatus = PaymentStatus.partiallyPaid;
      if (newAmountPaid >= sale.grandTotal) {
        newPaymentStatus = PaymentStatus.paid;
      }

      final completedAtStr =
          newPaymentStatus == PaymentStatus.paid &&
              sale.fulfillmentStatus == FulfillmentStatus.released
          ? now
          : sale.completedAt?.toIso8601String();

      await tx.execute(
        'UPDATE sales SET amount_paid = ?, status = ?, payment_status = ?, fulfillment_status = ?, payment_method = ?, updated_at = ?, completed_at = ? WHERE id = ?',
        [
          newAmountPaid,
          sale.status.value,
          newPaymentStatus.value,
          sale.fulfillmentStatus.value,
          paymentMethod,
          now,
          completedAtStr,
          sale.id,
        ],
      );
    });
  }

  // --- Credit Notes ---

  /// Watch all credit notes for a tenant
  Stream<List<CreditNote>> watchCreditNotes({String? tenantId}) {
    var sql = 'SELECT * FROM credit_notes';
    final params = <dynamic>[];
    if (tenantId != null) {
      sql += ' WHERE tenant_id = ?';
      params.add(tenantId);
    }
    sql += ' ORDER BY created_at DESC';
    return _db
        .watch(sql, parameters: params)
        .map((rows) => rows.map((row) => CreditNote.fromMap(row)).toList());
  }

  /// Watch credit notes for a specific sale, including items from the junction table
  Stream<List<CreditNote>> watchCreditNotesForSale(String saleId) {
    // Watch credit notes
    final notesStream = _db.watch(
      'SELECT * FROM credit_notes WHERE original_sale_id = ? ORDER BY created_at DESC',
      parameters: [saleId],
    );

    // Combine both streams — asyncMap re-fetches items on every notes change
    return notesStream.asyncMap((noteRows) async {
      // Get current items snapshot
      final itemRows = await _db.getAll(
        '''
        SELECT cni.* FROM credit_note_items cni
        INNER JOIN credit_notes cn ON cni.credit_note_id = cn.id
        WHERE cn.original_sale_id = ?
        ''',
        [saleId],
      );

      // Group items by credit_note_id
      final itemsByNote = <String, List<CreditNoteItem>>{};
      for (final row in itemRows) {
        final noteId = row['credit_note_id'] as String;
        itemsByNote.putIfAbsent(noteId, () => []);
        itemsByNote[noteId]!.add(CreditNoteItem.fromMap(row));
      }

      return noteRows.map((row) {
        final noteId = row['id'] as String;
        return CreditNote.fromMap({
          ...row,
          'items': itemsByNote[noteId]?.map((i) => i.toMap()).toList() ?? [],
        });
      }).toList();
    });
  }

  // --- Dashboard Aggregates ---

  /// Watch total revenue across both POS (payments) and invoice (sale_payments) tables
  Stream<double> watchTotalSales({String? branchId}) {
    var branchFilter = '';
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      branchFilter = ' WHERE branch_id = ?';
      params.add(branchId);
    }

    return _db
        .watch('''SELECT COALESCE(SUM(amount), 0) as total
            FROM sale_payments $branchFilter''', parameters: params)
        .map((results) {
          if (results.isEmpty || results.first['total'] == null) return 0.0;
          return (results.first['total'] as num).toDouble();
        });
  }

  /// Watch today's revenue from both POS and invoices
  Stream<double> watchTodaysRevenue({String? branchId}) {
    // Use UTC midnight — Supabase stores timestamps in UTC
    final todayUtc = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    var branchFilter = '';
    final params = <dynamic>['${todayUtc}T00:00:00'];

    if (branchId != null && branchId != 'all') {
      branchFilter = ' AND branch_id = ?';
      params.add(branchId);
    }

    return _db
        .watch(
          '''SELECT COALESCE(SUM(amount), 0) as total
            FROM sale_payments WHERE created_at >= ?$branchFilter''',
          parameters: params,
        )
        .map((results) {
          if (results.isEmpty || results.first['total'] == null) return 0.0;
          return (results.first['total'] as num).toDouble();
        });
  }

  /// Watch total inventory value (sum of quantity * cost_price)
  Stream<double> watchTotalInventoryValue({String? branchId}) {
    var sql = '''SELECT COALESCE(SUM(s.quantity * p.cost_price), 0) as total
                 FROM stock s
                 JOIN products p ON s.product_id = p.id
                 WHERE s.quantity > 0''';
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      sql += ' AND s.branch_id = ?';
      params.add(branchId);
    }

    return _db.watch(sql, parameters: params).map((results) {
      if (results.isEmpty || results.first['total'] == null) return 0.0;
      return (results.first['total'] as num).toDouble();
    });
  }

  /// Watch recent adjustments count (last 7 days by default)
  Stream<int> watchRecentAdjustmentsCount({String? branchId, int days = 7}) {
    final startDate = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();

    var sql =
        'SELECT COUNT(*) as count FROM stock_adjustments WHERE created_at >= ?';
    final params = <dynamic>[startDate];

    if (branchId != null && branchId != 'all') {
      sql += ' AND branch_id = ?';
      params.add(branchId);
    }

    return _db.watch(sql, parameters: params).map((results) {
      if (results.isEmpty) return 0;
      return (results.first['count'] as num).toInt();
    });
  }

  /// Watch today's order count (sales created today that are valid/approved)
  Stream<int> watchTodaysOrderCount({String? branchId}) {
    final todayUtc = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    var sql =
        "SELECT COUNT(*) as count FROM sales WHERE status NOT IN ('draft', 'voided', 'rejected', 'pending_approval') AND created_at >= ?";
    final params = <dynamic>['${todayUtc}T00:00:00'];

    if (branchId != null && branchId != 'all') {
      sql += ' AND branch_id = ?';
      params.add(branchId);
    }

    return _db.watch(sql, parameters: params).map((results) {
      if (results.isEmpty) return 0;
      return (results.first['count'] as num).toInt();
    });
  }

  /// Watch pending approvals count
  Stream<int> watchPendingApprovalsCount({String? branchId}) {
    var sql =
        "SELECT COUNT(*) as count FROM sales WHERE status = 'pending_approval'";
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      sql += ' AND branch_id = ?';
      params.add(branchId);
    }

    return _db.watch(sql, parameters: params).map((results) {
      if (results.isEmpty) return 0;
      return (results.first['count'] as num).toInt();
    });
  }

  /// Watch low stock item count
  Stream<int> watchLowStockCount({String? branchId}) {
    var sql =
        'SELECT COUNT(*) as count FROM stock WHERE quantity <= reorder_level AND quantity >= 0';
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      sql += ' AND branch_id = ?';
      params.add(branchId);
    }

    return _db.watch(sql, parameters: params).map((results) {
      if (results.isEmpty) return 0;
      return (results.first['count'] as num).toInt();
    });
  }

  /// Watch top selling products (by total quantity sold)
  Stream<List<Map<String, dynamic>>> watchTopProducts({
    String? branchId,
    int limit = 6,
  }) {
    var branchFilter = '';
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      branchFilter = ' AND s.branch_id = ?';
      params.add(branchId);
    }

    params.add(limit);

    return _db
        .watch('''SELECT p.name, p.image_url, p.base_price,
                SUM(si.quantity) as total_sold,
                SUM(si.total) as total_revenue
         FROM sale_items si
         JOIN products p ON si.product_id = p.id
         JOIN sales s ON si.sale_id = s.id
        WHERE s.status = 'approved'
          AND s.fulfillment_status = 'fulfilled'$branchFilter
         GROUP BY p.id, p.name, p.image_url, p.base_price
         ORDER BY total_sold DESC
         LIMIT ?''', parameters: params)
        .map((rows) => rows.toList());
  }

  /// Watch payment method breakdown across both payment tables
  Stream<List<Map<String, dynamic>>> watchPaymentMethodBreakdown({
    String? branchId,
  }) {
    var branchFilter = '';
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      branchFilter = ' WHERE branch_id = ?';
      params.add(branchId);
    }

    return _db
        .watch('''SELECT payment_method, COUNT(*) as count, SUM(amount) as total
          FROM sale_payments$branchFilter
        GROUP BY payment_method
        ORDER BY total DESC''', parameters: params)
        .map((rows) => rows.toList());
  }

  /// Report summary metrics for a trailing [days] window.
  Stream<Map<String, dynamic>> watchReportSummary({
    required String tenantId,
    String? branchId,
    int days = 30,
  }) {
    final startTs = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    if (branchId != null && branchId != 'all') {
      return _db
          .watch(
            '''
            WITH sales_scope AS (
              SELECT *
              FROM sales
              WHERE tenant_id = ?
                AND created_at >= ?
                AND branch_id = ?
            ),
            payments_scope AS (
              SELECT *
              FROM sale_payments
              WHERE tenant_id = ?
                AND created_at >= ?
                AND branch_id = ?
            ),
            stock_scope AS (
              SELECT st.quantity, st.reorder_level, p.cost_price
              FROM stock st
              LEFT JOIN products p ON p.id = st.product_id
              WHERE st.tenant_id = ?
                AND st.branch_id = ?
            )
            SELECT
              COUNT(*) FILTER (WHERE status = 'approved') AS approved_count,
              COUNT(*) FILTER (WHERE status = 'pending_approval') AS pending_approval_count,
              COUNT(*) FILTER (WHERE status = 'voided') AS voided_count,
              COUNT(*) FILTER (WHERE status = 'rejected') AS rejected_count,
              COUNT(*) FILTER (WHERE status = 'draft') AS draft_count,
              COUNT(*) FILTER (
                WHERE status = 'approved' AND fulfillment_status = 'unfulfilled'
              ) AS unreleased_count,
              COUNT(*) FILTER (
                WHERE status = 'approved' AND payment_status = 'paid'
              ) AS paid_invoice_count,
              COALESCE(
                SUM(CASE WHEN status = 'approved' THEN grand_total ELSE 0 END),
                0
              ) AS gross_sales,
              COALESCE((SELECT SUM(amount) FROM payments_scope), 0) AS payments_collected,
              COALESCE(
                AVG(CASE WHEN status = 'approved' THEN grand_total END),
                0
              ) AS average_ticket,
              COALESCE(
                (SELECT COUNT(*) FROM stock_scope WHERE quantity <= reorder_level AND quantity >= 0),
                0
              ) AS low_stock_count,
              COALESCE(
                (SELECT SUM(CASE WHEN quantity > 0 THEN quantity * COALESCE(cost_price, 0) ELSE 0 END) FROM stock_scope),
                0
              ) AS inventory_value
            FROM sales_scope
            ''',
            parameters: [
              tenantId,
              '${startTs}T00:00:00',
              branchId,
              tenantId,
              '${startTs}T00:00:00',
              branchId,
              tenantId,
              branchId,
            ],
          )
          .map((rows) => rows.isEmpty ? <String, dynamic>{} : rows.first);
    }

    return _db
        .watch(
          '''
          WITH sales_scope AS (
            SELECT *
            FROM sales
            WHERE tenant_id = ?
              AND created_at >= ?
          ),
          payments_scope AS (
            SELECT *
            FROM sale_payments
            WHERE tenant_id = ?
              AND created_at >= ?
          ),
          stock_scope AS (
            SELECT st.quantity, st.reorder_level, p.cost_price
            FROM stock st
            LEFT JOIN products p ON p.id = st.product_id
            WHERE st.tenant_id = ?
          )
          SELECT
            COUNT(*) FILTER (WHERE status = 'approved') AS approved_count,
            COUNT(*) FILTER (WHERE status = 'pending_approval') AS pending_approval_count,
            COUNT(*) FILTER (WHERE status = 'voided') AS voided_count,
            COUNT(*) FILTER (WHERE status = 'rejected') AS rejected_count,
            COUNT(*) FILTER (WHERE status = 'draft') AS draft_count,
            COUNT(*) FILTER (
              WHERE status = 'approved' AND fulfillment_status = 'unfulfilled'
            ) AS unreleased_count,
            COUNT(*) FILTER (
              WHERE status = 'approved' AND payment_status = 'paid'
            ) AS paid_invoice_count,
            COALESCE(
              SUM(CASE WHEN status = 'approved' THEN grand_total ELSE 0 END),
              0
            ) AS gross_sales,
            COALESCE((SELECT SUM(amount) FROM payments_scope), 0) AS payments_collected,
            COALESCE(
              AVG(CASE WHEN status = 'approved' THEN grand_total END),
              0
            ) AS average_ticket,
            COALESCE(
              (SELECT COUNT(*) FROM stock_scope WHERE quantity <= reorder_level AND quantity >= 0),
              0
            ) AS low_stock_count,
            COALESCE(
              (SELECT SUM(CASE WHEN quantity > 0 THEN quantity * COALESCE(cost_price, 0) ELSE 0 END) FROM stock_scope),
              0
            ) AS inventory_value
          FROM sales_scope
          ''',
          parameters: [
            tenantId,
            '${startTs}T00:00:00',
            tenantId,
            '${startTs}T00:00:00',
            tenantId,
          ],
        )
        .map((rows) => rows.isEmpty ? <String, dynamic>{} : rows.first);
  }

  /// Payment method totals for a trailing [days] window.
  Stream<List<Map<String, dynamic>>> watchPaymentMethodBreakdownInRange({
    required String tenantId,
    String? branchId,
    int days = 30,
  }) {
    final startTs = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    if (branchId != null && branchId != 'all') {
      return _db
          .watch(
            '''
            SELECT
              COALESCE(NULLIF(payment_method, ''), 'unknown') AS payment_method,
              COUNT(*) AS count,
              COALESCE(SUM(amount), 0) AS total
            FROM sale_payments
            WHERE tenant_id = ?
              AND created_at >= ?
              AND branch_id = ?
            GROUP BY COALESCE(NULLIF(payment_method, ''), 'unknown')
            ORDER BY total DESC
            ''',
            parameters: [tenantId, '${startTs}T00:00:00', branchId],
          )
          .map((rows) => rows.toList());
    }

    return _db
        .watch(
          '''
          SELECT
            COALESCE(NULLIF(payment_method, ''), 'unknown') AS payment_method,
            COUNT(*) AS count,
            COALESCE(SUM(amount), 0) AS total
          FROM sale_payments
          WHERE tenant_id = ?
            AND created_at >= ?
          GROUP BY COALESCE(NULLIF(payment_method, ''), 'unknown')
          ORDER BY total DESC
          ''',
          parameters: [tenantId, '${startTs}T00:00:00'],
        )
        .map((rows) => rows.toList());
  }

  /// Top products for a trailing [days] window.
  Stream<List<Map<String, dynamic>>> watchTopProductsInRange({
    required String tenantId,
    String? branchId,
    int days = 30,
    int limit = 8,
  }) {
    final startTs = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    final params = <dynamic>[tenantId, '${startTs}T00:00:00'];
    var branchFilter = '';
    if (branchId != null && branchId != 'all') {
      branchFilter = ' AND s.branch_id = ?';
      params.add(branchId);
    }
    params.add(limit);

    return _db
        .watch('''
          SELECT
            p.id,
            p.name,
            p.image_url,
            p.base_price,
            COALESCE(SUM(si.quantity), 0) AS total_sold,
            COALESCE(SUM(si.total), 0) AS total_revenue
          FROM sale_items si
          JOIN products p ON si.product_id = p.id
          JOIN sales s ON si.sale_id = s.id
          WHERE s.tenant_id = ?
            AND s.created_at >= ?
            AND s.status = 'approved'
            AND s.fulfillment_status = 'fulfilled'$branchFilter
          GROUP BY p.id, p.name, p.image_url, p.base_price
          ORDER BY total_sold DESC
          LIMIT ?
          ''', parameters: params)
        .map((rows) => rows.toList());
  }

  /// Invoice lifecycle status breakdown for a trailing [days] window.
  Stream<List<Map<String, dynamic>>> watchInvoiceStatusBreakdown({
    required String tenantId,
    String? branchId,
    int days = 30,
  }) {
    final startTs = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    if (branchId != null && branchId != 'all') {
      return _db
          .watch(
            '''
            SELECT status, COUNT(*) AS count
            FROM sales
            WHERE tenant_id = ?
              AND created_at >= ?
              AND branch_id = ?
            GROUP BY status
            ORDER BY count DESC
            ''',
            parameters: [tenantId, '${startTs}T00:00:00', branchId],
          )
          .map((rows) => rows.toList());
    }

    return _db
        .watch(
          '''
          SELECT status, COUNT(*) AS count
          FROM sales
          WHERE tenant_id = ?
            AND created_at >= ?
          GROUP BY status
          ORDER BY count DESC
          ''',
          parameters: [tenantId, '${startTs}T00:00:00'],
        )
        .map((rows) => rows.toList());
  }

  Stream<int> watchStaffCount() {
    return _db.watch('SELECT COUNT(*) as count FROM profiles').map((results) {
      if (results.isEmpty) return 0;
      return (results.first['count'] as num).toInt();
    });
  }

  Stream<List<Profile>> watchStaff(String tenantId, {String? branchId}) {
    String sql =
        "SELECT * FROM profiles WHERE tenant_id = ? AND role != 'Owner' AND status != 'deleted'";
    final params = <dynamic>[tenantId];

    if (branchId != null && branchId != 'all') {
      sql += " AND (branch_id = ? OR branch_id IS NULL)";
      params.add(branchId);
    }

    sql += " ORDER BY created_at ASC";

    return _db.watch(sql, parameters: params).map(
      (results) => results.map((row) => Profile.fromMap(row)).toList(),
    );
  }

  /// Watch daily sales aggregated data for charts (last [days] days)
  Stream<List<Map<String, dynamic>>> watchDailySalesData({
    String? branchId,
    int days = 7,
  }) {
    final startDate = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);

    var branchFilter = '';
    final params = <dynamic>['${startDate}T00:00:00'];

    if (branchId != null && branchId != 'all') {
      branchFilter = ' AND branch_id = ?';
      params.add(branchId);
    }

    return _db
        .watch('''SELECT substr(created_at, 1, 10) as day,
                    COALESCE(SUM(grand_total), 0)  as revenue,
                    COUNT(*)                        as order_count
             FROM sales
             WHERE status NOT IN ('draft', 'voided', 'rejected', 'pending_approval')
               AND created_at >= ?$branchFilter
             GROUP BY substr(created_at, 1, 10)
             ORDER BY day ASC''', parameters: params)
        .map((rows) => rows.toList());
  }

  /// Snapshot-aware daily chart data.
  /// Uses server-generated daily snapshots and fills any missing days from
  /// transactional sales aggregation.
  Stream<List<Map<String, dynamic>>> watchDailySalesDataSmart({
    required String tenantId,
    String? branchId,
    int days = 7,
  }) {
    final startDate = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days - 1))
        .toIso8601String()
        .substring(0, 10);
    final startTs = '${startDate}T00:00:00';

    if (branchId != null && branchId != 'all') {
      return _db
          .watch(
            '''
            WITH snapshot_data AS (
              SELECT
                snapshot_date AS day,
                COALESCE(SUM(gross_sales), 0) AS revenue,
                COALESCE(SUM(orders_count), 0) AS order_count
              FROM daily_kpi_snapshots
              WHERE tenant_id = ?
                AND snapshot_date >= ?
                AND branch_id = ?
              GROUP BY snapshot_date
            ),
            raw_range AS (
              SELECT
                substr(created_at, 1, 10) AS day,
                COALESCE(SUM(grand_total), 0) AS revenue,
                COUNT(*) AS order_count
              FROM sales
              WHERE tenant_id = ?
                AND status NOT IN ('draft', 'voided', 'rejected', 'pending_approval')
                AND created_at >= ?
                AND branch_id = ?
              GROUP BY substr(created_at, 1, 10)
            )
            SELECT day, revenue, order_count
            FROM snapshot_data
            UNION ALL
            SELECT r.day, r.revenue, r.order_count
            FROM raw_range r
            WHERE NOT EXISTS (SELECT 1 FROM snapshot_data s WHERE s.day = r.day)
            ORDER BY day ASC
            ''',
            parameters: [
              tenantId,
              startDate,
              branchId,
              tenantId,
              startTs,
              branchId,
            ],
          )
          .map((rows) => rows.toList());
    }

    return _db
        .watch(
          '''
          WITH snapshot_data AS (
            SELECT
              snapshot_date AS day,
              COALESCE(SUM(gross_sales), 0) AS revenue,
              COALESCE(SUM(orders_count), 0) AS order_count
            FROM daily_kpi_snapshots
            WHERE tenant_id = ?
              AND snapshot_date >= ?
            GROUP BY snapshot_date
          ),
          raw_range AS (
            SELECT
              substr(created_at, 1, 10) AS day,
              COALESCE(SUM(grand_total), 0) AS revenue,
              COUNT(*) AS order_count
            FROM sales
            WHERE tenant_id = ?
              AND status NOT IN ('draft', 'voided', 'rejected', 'pending_approval')
              AND created_at >= ?
            GROUP BY substr(created_at, 1, 10)
          )
          SELECT day, revenue, order_count
          FROM snapshot_data
          UNION ALL
          SELECT r.day, r.revenue, r.order_count
          FROM raw_range r
          WHERE NOT EXISTS (SELECT 1 FROM snapshot_data s WHERE s.day = r.day)
          ORDER BY day ASC
          ''',
          parameters: [tenantId, startDate, tenantId, startTs],
        )
        .map((rows) => rows.toList());
  }

  /// Snapshot-aware KPI row for today's dashboard metrics.
  /// If today's snapshot does not exist, this falls back to transactional data.
  Stream<Map<String, dynamic>> watchTodayKpiSnapshotSmart({
    required String tenantId,
    String? branchId,
  }) {
    final todayDate = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final todayStartTs = '${todayDate}T00:00:00';

    if (branchId != null && branchId != 'all') {
      return _db
          .watch(
            '''
            WITH snap AS (
              SELECT
                COALESCE(SUM(orders_count), 0) AS orders_count,
                COALESCE(SUM(gross_sales), 0) AS gross_sales,
                COALESCE(SUM(payments_collected), 0) AS payments_collected,
                COALESCE(SUM(pending_approval_count), 0) AS pending_approval_count,
                COALESCE(SUM(low_stock_count), 0) AS low_stock_count,
                COALESCE(SUM(inventory_value), 0) AS inventory_value,
                COUNT(*) AS row_count
              FROM daily_kpi_snapshots
              WHERE tenant_id = ?
                AND branch_id = ?
                AND snapshot_date = ?
            ),
            raw_sales AS (
              SELECT
                COUNT(*) FILTER (
                  WHERE status NOT IN ('draft', 'voided', 'rejected', 'pending_approval')
                ) AS orders_count,
                COALESCE(
                  SUM(CASE WHEN status NOT IN ('draft', 'voided', 'rejected') THEN grand_total ELSE 0 END),
                  0
                ) AS gross_sales,
                COUNT(*) FILTER (WHERE status = 'pending_approval') AS pending_approval_count
              FROM sales
              WHERE tenant_id = ?
                AND branch_id = ?
                AND created_at >= ?
            ),
            raw_payments AS (
              SELECT COALESCE(SUM(amount), 0) AS payments_collected
              FROM sale_payments
              WHERE tenant_id = ?
                AND branch_id = ?
                AND created_at >= ?
            ),
            raw_stock AS (
              SELECT
                COUNT(*) FILTER (WHERE quantity <= reorder_level AND quantity >= 0) AS low_stock_count,
                COALESCE(
                  SUM(CASE WHEN st.quantity > 0 THEN st.quantity * COALESCE(p.cost_price, 0) ELSE 0 END),
                  0
                ) AS inventory_value
              FROM stock st
              LEFT JOIN products p ON p.id = st.product_id
              WHERE st.tenant_id = ?
                AND st.branch_id = ?
            )
            SELECT
              CASE WHEN snap.row_count > 0 THEN snap.orders_count ELSE raw_sales.orders_count END AS orders_count,
              CASE WHEN snap.row_count > 0 THEN snap.gross_sales ELSE raw_sales.gross_sales END AS gross_sales,
              CASE WHEN snap.row_count > 0 THEN snap.payments_collected ELSE raw_payments.payments_collected END AS payments_collected,
              CASE WHEN snap.row_count > 0 THEN snap.pending_approval_count ELSE raw_sales.pending_approval_count END AS pending_approval_count,
              CASE WHEN snap.row_count > 0 THEN snap.low_stock_count ELSE raw_stock.low_stock_count END AS low_stock_count,
              CASE WHEN snap.row_count > 0 THEN snap.inventory_value ELSE raw_stock.inventory_value END AS inventory_value
            FROM snap, raw_sales, raw_payments, raw_stock
            ''',
            parameters: [
              tenantId,
              branchId,
              todayDate,
              tenantId,
              branchId,
              todayStartTs,
              tenantId,
              branchId,
              todayStartTs,
              tenantId,
              branchId,
            ],
          )
          .map((rows) => rows.isEmpty ? <String, dynamic>{} : rows.first);
    }

    return _db
        .watch(
          '''
          WITH snap AS (
            SELECT
              COALESCE(SUM(orders_count), 0) AS orders_count,
              COALESCE(SUM(gross_sales), 0) AS gross_sales,
              COALESCE(SUM(payments_collected), 0) AS payments_collected,
              COALESCE(SUM(pending_approval_count), 0) AS pending_approval_count,
              COALESCE(SUM(low_stock_count), 0) AS low_stock_count,
              COALESCE(SUM(inventory_value), 0) AS inventory_value,
              COUNT(*) AS row_count
            FROM daily_kpi_snapshots
            WHERE tenant_id = ?
              AND snapshot_date = ?
          ),
          raw_sales AS (
            SELECT
              COUNT(*) FILTER (
                WHERE status NOT IN ('draft', 'voided', 'rejected', 'pending_approval')
              ) AS orders_count,
              COALESCE(
                SUM(CASE WHEN status NOT IN ('draft', 'voided', 'rejected') THEN grand_total ELSE 0 END),
                0
              ) AS gross_sales,
              COUNT(*) FILTER (WHERE status = 'pending_approval') AS pending_approval_count
            FROM sales
            WHERE tenant_id = ?
              AND created_at >= ?
          ),
          raw_payments AS (
            SELECT COALESCE(SUM(amount), 0) AS payments_collected
            FROM sale_payments
            WHERE tenant_id = ?
              AND created_at >= ?
          ),
          raw_stock AS (
            SELECT
              COUNT(*) FILTER (WHERE quantity <= reorder_level AND quantity >= 0) AS low_stock_count,
              COALESCE(
                SUM(CASE WHEN st.quantity > 0 THEN st.quantity * COALESCE(p.cost_price, 0) ELSE 0 END),
                0
              ) AS inventory_value
            FROM stock st
            LEFT JOIN products p ON p.id = st.product_id
            WHERE st.tenant_id = ?
          )
          SELECT
            CASE WHEN snap.row_count > 0 THEN snap.orders_count ELSE raw_sales.orders_count END AS orders_count,
            CASE WHEN snap.row_count > 0 THEN snap.gross_sales ELSE raw_sales.gross_sales END AS gross_sales,
            CASE WHEN snap.row_count > 0 THEN snap.payments_collected ELSE raw_payments.payments_collected END AS payments_collected,
            CASE WHEN snap.row_count > 0 THEN snap.pending_approval_count ELSE raw_sales.pending_approval_count END AS pending_approval_count,
            CASE WHEN snap.row_count > 0 THEN snap.low_stock_count ELSE raw_stock.low_stock_count END AS low_stock_count,
            CASE WHEN snap.row_count > 0 THEN snap.inventory_value ELSE raw_stock.inventory_value END AS inventory_value
          FROM snap, raw_sales, raw_payments, raw_stock
          ''',
          parameters: [
            tenantId,
            todayDate,
            tenantId,
            todayStartTs,
            tenantId,
            todayStartTs,
            tenantId,
          ],
        )
        .map((rows) => rows.isEmpty ? <String, dynamic>{} : rows.first);
  }

  Stream<SyncStatus> get syncStatus => _db.statusStream;

  // --- Stock Adjustments (all, with status filter) ---

  /// Watch all stock adjustments for a tenant/branch, optionally filtered
  /// by [status] ('pending', 'approved', 'rejected').
  Stream<List<StockAdjustment>> watchAllStockAdjustments({
    required String tenantId,
    String? branchId,
    String? status,
  }) {
    var sql = '''
      SELECT 
        sa.*,
        p.display_name AS adjuster_display_name,
        sm.name AS staff_name,
        r.label AS reason_label,
        prod.name AS product_name,
        uom.abbreviation AS uom_abbreviation
      FROM stock_adjustments sa
      LEFT JOIN profiles p ON p.user_id = sa.created_by
      LEFT JOIN staff_members sm ON sm.id = sa.created_by
      LEFT JOIN stock_adjustment_reasons r ON r.id = sa.reason_id
      LEFT JOIN products prod ON prod.id = sa.product_id
      LEFT JOIN units_of_measurement uom ON uom.id = prod.uom_id
      WHERE sa.tenant_id = ?
    ''';
    final params = <dynamic>[tenantId];

    if (branchId != null && branchId != 'all') {
      sql += ' AND sa.branch_id = ?';
      params.add(branchId);
    }
    sql += ' ORDER BY sa.created_at DESC';

    return _db.watch(sql, parameters: params).map((rows) {
      final adjustments = rows
          .map((row) => StockAdjustment.fromMap(row))
          .toList();

      if (status == null) return adjustments;

      final normalizedStatus = status.toLowerCase();
      return adjustments
          .where((adj) => adj.status.name == normalizedStatus)
          .toList();
    });
  }

  Stream<List<StockAdjustment>> watchStockAdjustmentsByBundle(String bundleId) {
    const sql = '''
      SELECT 
        sa.*,
        p.display_name AS adjuster_display_name,
        sm.name AS staff_name,
        r.label AS reason_label,
        prod.name AS product_name,
        uom.abbreviation AS uom_abbreviation
      FROM stock_adjustments sa
      LEFT JOIN profiles p ON p.user_id = sa.created_by
      LEFT JOIN staff_members sm ON sm.id = sa.created_by
      LEFT JOIN stock_adjustment_reasons r ON r.id = sa.reason_id
      LEFT JOIN products prod ON prod.id = sa.product_id
      LEFT JOIN units_of_measurement uom ON uom.id = prod.uom_id
      WHERE sa.bundle_id = ? OR sa.id = ?
      ORDER BY sa.created_at DESC
    ''';
    return _db.watch(sql, parameters: [bundleId, bundleId]).map((rows) {
      return rows.map((row) => StockAdjustment.fromMap(row)).toList();
    });
  }

  /// Approve a pending stock adjustment and apply the quantity change to stock.
  /// This can approve a single adjustment or a whole bundle.
  Future<void> approveAdjustment({
    String? adjustmentId,
    String? bundleId,
    required String approverId,
  }) async {
    await _db.writeTransaction((tx) async {
      final now = DateTime.now().toUtc().toIso8601String();

      // 1. Find pending adjustments to approve
      final String whereClause =
          bundleId != null ? 'bundle_id = ?' : 'id = ?';
      final dynamic filterVal = bundleId ?? adjustmentId;

      final rows = await tx.getAll(
        'SELECT * FROM stock_adjustments WHERE $whereClause AND status = ?',
        [filterVal, 'pending'],
      );

      for (final row in rows) {
        final adjId = row['id'];
        final productId = row['product_id'];
        final branchId = row['branch_id'];
        final tenantId = row['tenant_id'];
        final quantityChange = row['quantity'] as int;

        // 2. Update stock
        final stockResult = await tx.getAll(
          'SELECT quantity FROM stock WHERE product_id = ? AND branch_id = ?',
          [productId, branchId],
        );

        if (stockResult.isEmpty) {
          await tx.execute(
            '''INSERT INTO stock (
              id, tenant_id, branch_id, product_id, quantity, reorder_level, 
              last_updated
            ) VALUES (uuid(), ?, ?, ?, ?, 0, ?)''',
            [tenantId, branchId, productId, quantityChange, now],
          );
        } else {
          await tx.execute(
            'UPDATE stock SET quantity = quantity + ?, last_updated = ? WHERE product_id = ? AND branch_id = ?',
            [quantityChange, now, productId, branchId],
          );
        }

        // 3. Update adjustment status
        await tx.execute(
          '''UPDATE stock_adjustments 
             SET status = ?, approved_by = ?, approved_at = ? 
             WHERE id = ?''',
          ['approved', approverId, now, adjId],
        );
      }
    });
  }

  /// Reject a pending stock adjustment.
  Future<void> rejectAdjustment({
    String? adjustmentId,
    String? bundleId,
    required String rejectorId,
    String? reason,
  }) async {
    await _db.writeTransaction((tx) async {
      final now = DateTime.now().toUtc().toIso8601String();
      final String whereClause =
          bundleId != null ? 'bundle_id = ?' : 'id = ?';
      final dynamic filterVal = bundleId ?? adjustmentId;

      await tx.execute(
        '''UPDATE stock_adjustments 
           SET status = ?, approved_by = ?, approved_at = ?, rejection_reason = ? 
           WHERE $whereClause AND status = ?''',
        ['rejected', rejectorId, now, reason, filterVal, 'pending'],
      );
    });
  }

  // --- Commissions ---

  /// Watch all commissions for a tenant, optionally filtered by salesperson or status.
  Stream<List<Commission>> watchCommissions({
    required String tenantId,
    String? salespersonId,
    String? branchId,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var sql = 'SELECT * FROM commissions WHERE tenant_id = ?';
    final params = <dynamic>[tenantId];

    if (salespersonId != null) {
      sql += ' AND salesperson_id = ?';
      params.add(salespersonId);
    }
    if (status != null) {
      sql += ' AND status = ?';
      params.add(status);
    }
    if (branchId != null && branchId != 'all') {
      sql +=
          ' AND sale_id IN (SELECT id FROM sales WHERE tenant_id = ? AND branch_id = ?)';
      params.add(tenantId);
      params.add(branchId);
    }
    if (startDate != null) {
      sql += ' AND created_at >= ?';
      params.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      sql += ' AND created_at <= ?';
      params.add(endDate.toIso8601String());
    }
    sql += ' ORDER BY created_at DESC';

    return _db
        .watch(sql, parameters: params)
        .map((rows) => rows.map((r) => Commission.fromMap(r)).toList());
  }

  /// Watch aggregated commission totals grouped by salesperson.
  /// Returns one row per salesperson with total pending and total paid amounts.
  Stream<List<Map<String, dynamic>>> watchCommissionSummaryRaw({
    required String tenantId,
    String? branchId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    String dateFilterComm = '';
    String dateFilterSales = '';
    String branchFilterComm = '';
    String branchFilterSales = '';
    List<Object?> paramsComm = [tenantId];
    List<Object?> paramsSales = [tenantId];

    if (startDate != null) {
      dateFilterComm += ' AND created_at >= ?';
      dateFilterSales += ' AND created_at >= ?';
      paramsComm.add(startDate.toIso8601String());
      paramsSales.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      dateFilterComm += ' AND created_at <= ?';
      dateFilterSales += ' AND created_at <= ?';
      paramsComm.add(endDate.toIso8601String());
      paramsSales.add(endDate.toIso8601String());
    }

    if (branchId != null && branchId != 'all') {
      branchFilterComm =
          ' AND sale_id IN (SELECT id FROM sales WHERE tenant_id = ? AND branch_id = ?)';
      paramsComm.add(tenantId);
      paramsComm.add(branchId);

      branchFilterSales = ' AND branch_id = ?';
      paramsSales.add(branchId);
    }

    final params = [...paramsComm, ...paramsSales];

    // Using UNION to simulate FULL OUTER JOIN
    return _db.watch('''
      WITH CommAgg AS (
        SELECT salesperson_id,
               SUM(CASE WHEN status = 'pending' THEN amount ELSE 0 END) AS total_pending,
               SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END) AS total_paid,
               COUNT(id) AS transaction_count
        FROM commissions
         WHERE tenant_id = ? $dateFilterComm $branchFilterComm
        GROUP BY salesperson_id
      ),
      SalesAgg AS (
        SELECT salesperson_id,
               SUM(grand_total) AS total_sales,
               COUNT(id) AS sales_count
        FROM sales
         WHERE tenant_id = ? AND status != 'voided' AND salesperson_id IS NOT NULL $dateFilterSales $branchFilterSales
        GROUP BY salesperson_id
      )
      SELECT 
        COALESCE(c.salesperson_id, s.salesperson_id) AS salesperson_id,
        sm.name AS salesperson_name,
        COALESCE(c.total_pending, 0) AS total_pending,
        COALESCE(c.total_paid, 0) AS total_paid,
        COALESCE(c.transaction_count, 0) AS transaction_count,
        COALESCE(s.total_sales, 0) AS total_sales_amount,
        COALESCE(s.sales_count, 0) AS sales_count
      FROM CommAgg c
      LEFT JOIN SalesAgg s ON c.salesperson_id = s.salesperson_id
      LEFT JOIN staff_members sm ON sm.id = COALESCE(c.salesperson_id, s.salesperson_id)
      UNION
      SELECT 
        COALESCE(c.salesperson_id, s.salesperson_id) AS salesperson_id,
        sm.name AS salesperson_name,
        COALESCE(c.total_pending, 0) AS total_pending,
        COALESCE(c.total_paid, 0) AS total_paid,
        COALESCE(c.transaction_count, 0) AS transaction_count,
        COALESCE(s.total_sales, 0) AS total_sales_amount,
        COALESCE(s.sales_count, 0) AS sales_count
      FROM SalesAgg s
      LEFT JOIN CommAgg c ON s.salesperson_id = c.salesperson_id
      LEFT JOIN staff_members sm ON sm.id = COALESCE(c.salesperson_id, s.salesperson_id)
      ORDER BY total_sales_amount DESC, total_pending DESC
      ''', parameters: params);
  }

  /// Mark a commission as paid.
  Future<void> markCommissionPaid(String commissionId) async {
    await _db.execute('UPDATE commissions SET status = ? WHERE id = ?', [
      'paid',
      commissionId,
    ]);
  }

  /// Mark ALL pending commissions for a salesperson as paid.
  Future<void> markAllCommissionsPaid({
    required String tenantId,
    required String salespersonId,
    String? branchId,
  }) async {
    if (branchId != null && branchId != 'all') {
      await _db.execute(
        "UPDATE commissions SET status = 'paid' WHERE tenant_id = ? AND salesperson_id = ? AND status = 'pending' AND sale_id IN (SELECT id FROM sales WHERE tenant_id = ? AND branch_id = ?)",
        [tenantId, salespersonId, tenantId, branchId],
      );
      return;
    }

    await _db.execute(
      "UPDATE commissions SET status = 'paid' WHERE tenant_id = ? AND salesperson_id = ? AND status = 'pending'",
      [tenantId, salespersonId],
    );
  }

  Future<void> updateStockAdjustmentQuantity({
    required String adjustmentId,
    required int newQuantity,
  }) async {
    await _db.execute(
      'UPDATE stock_adjustments SET quantity = ? WHERE id = ?',
      [newQuantity, adjustmentId],
    );
  }
}
