import 'dart:convert';
import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:zynk/core/models/adjustment_reason.dart';
import 'package:zynk/core/models/schema_models.dart';
import 'package:zynk/core/models/sales_models.dart';
import 'package:zynk/core/models/customer_model.dart';
import 'package:zynk/core/models/staff_model.dart';


class PowerSyncRepository {
  final PowerSyncDatabase _db;

  PowerSyncRepository(this._db);

  PowerSyncDatabase get db => _db;

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
  Stream<List<StaffMember>> watchStaffMembers(String tenantId) {
    return _db
        .watch(
          "SELECT * FROM staff_members WHERE tenant_id = ? ORDER BY name ASC",
          parameters: [tenantId],
        )
        .map(
          (results) =>
              results.map((row) => StaffMember.fromJson(Map<String, dynamic>.from(row))).toList(),
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
        member.status,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateStaffMember(StaffMember member) async {
    await _db.execute(
      '''UPDATE staff_members
        SET name = ?, phone = ?, email = ?, profile_picture_url = ?, status = ?, updated_at = ?
        WHERE id = ?''',
      [
        member.name,
        member.phone,
        member.email,
        member.profilePictureUrl,
        member.status,
        DateTime.now().toIso8601String(),
        member.id,
      ],
    );
  }

  Future<void> deleteStaffMember(String memberId) async {
    // Soft delete by setting status to inactive
    await _db.execute(
      'UPDATE staff_members SET status = ?, updated_at = ? WHERE id = ?',
      ['inactive', DateTime.now().toIso8601String(), memberId],
    );
  }

  // --- Products ---
  Stream<List<Product>> watchProducts({String? branchId}) {
    var sql = 'SELECT * FROM products';
    final params = <dynamic>[];

    if (branchId != null && branchId != 'all') {
      sql += ' WHERE branch_id = ?';
      params.add(branchId);
    }
    sql += ' ORDER BY name ASC';

    return _db
        .watch(sql, parameters: params)
        .map((results) => results.map((row) => Product.fromMap(row)).toList());
  }

  Future<void> createProduct(Product product) async {
    await _db.execute(
      '''INSERT INTO products (
        id, tenant_id, branch_id, item_group_id, category_id, uom_id, name, sku, barcode, 
        description, image_url, base_price, cost_price, tax_category, is_service, 
        product_type, variant_options, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
        product.productType,
        product.variantOptions != null ? jsonEncode(product.variantOptions) : null,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateProduct(Product product) async {
    await _db.execute(
      '''UPDATE products SET 
        branch_id = ?, item_group_id = ?, category_id = ?, uom_id = ?, name = ?, sku = ?, barcode = ?, 
        description = ?, image_url = ?, base_price = ?, cost_price = ?, tax_category = ?, 
        is_service = ?, product_type = ?, variant_options = ?, updated_at = ?
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
        product.productType,
        product.variantOptions != null ? jsonEncode(product.variantOptions) : null,
        DateTime.now().toIso8601String(),
        product.id,
      ],
    );
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
  Stream<Stock?> watchProductStock(String productId) {
    return _db
        .watch(
          'SELECT * FROM stock WHERE product_id = ?',
          parameters: [productId],
        )
        .map((rows) => rows.isEmpty ? null : Stock.fromMap(rows.first));
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
          (rows) =>
              rows.map((row) => StockAdjustment.fromMap(row)).toList(),
        );
  }

  Future<void> adjustStock({
    required String tenantId,
    required String branchId,
    required String productId,
    required String
    adjustmentType, // 'addition', 'reduction', 'initial', 'damage'
    required int quantityChange,
    required String createdBy,
    String? referenceNumber,
    String? notes,
  }) async {
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
  }) async {
    final now = DateTime.now().toIso8601String();

    // 1. Get current stock
    final stockResult = await tx.getAll(
      'SELECT quantity FROM stock WHERE product_id = ?',
      [productId],
    );

    if (stockResult.isEmpty) {
      // Interacting with uuid from dart requires import 'package:uuid/uuid.dart', or we can use the built in uuid() function of powersync sqlite
      await tx.execute(
        '''INSERT INTO stock (
          id, tenant_id, branch_id, product_id, quantity, reorder_level, 
          last_updated
        ) VALUES (uuid(), ?, ?, ?, ?, 0, ?)''',
        [tenantId, branchId, productId, quantityChange, now],
      );
    } else {
      await tx.execute(
        'UPDATE stock SET quantity = quantity + ?, last_updated = ? WHERE product_id = ?',
        [quantityChange, now, productId],
      );
    }

    // 2. Insert stock adjustment log
    await tx.execute(
      '''INSERT INTO stock_adjustments (
        id, tenant_id, branch_id, product_id, adjustment_type, quantity, 
        reference_number, notes, created_by, created_at
      ) VALUES (uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        tenantId,
        branchId,
        productId,
        adjustmentType,
        quantityChange,
        referenceNumber,
        notes,
        createdBy,
        now,
      ],
    );
  }

  Future<void> batchAdjustStock({
    required String tenantId,
    required String branchId,
    required List<BatchAdjustmentItem> items,
    required String createdBy,
    String? reasonId,
    String? referenceNumber,
  }) async {
    await _db.writeTransaction((tx) async {
      final now = DateTime.now().toUtc().toIso8601String();

      for (final item in items) {
        // 1. Get current stock
        final stockResult = await tx.getAll(
          'SELECT quantity FROM stock WHERE product_id = ?',
          [item.productId],
        );

        if (stockResult.isEmpty) {
          await tx.execute(
            '''INSERT INTO stock (
              id, tenant_id, branch_id, product_id, quantity, reorder_level, 
              last_updated
            ) VALUES (uuid(), ?, ?, ?, ?, 0, ?)''',
            [tenantId, branchId, item.productId, item.quantityChange, now],
          );
        } else {
          await tx.execute(
            'UPDATE stock SET quantity = quantity + ?, last_updated = ? WHERE product_id = ?',
            [item.quantityChange, now, item.productId],
          );
        }

        // 2. Insert stock adjustment log
        await tx.execute(
          '''INSERT INTO stock_adjustments (
            id, tenant_id, branch_id, product_id, quantity, 
            reference_number, notes, created_by, reason_id, created_at
          ) VALUES (uuid(), ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            tenantId,
            branchId,
            item.productId,
            item.quantityChange,
            referenceNumber,
            item.notes,
            createdBy,
            reasonId,
            now,
          ],
        );
      }
    });
  }

  // --- Adjustment Reasons ---
  Stream<List<AdjustmentReason>> watchAdjustmentReasons(String tenantId) {
    return _db
        .watch(
          'SELECT * FROM stock_adjustment_reasons WHERE tenant_id = ? ORDER BY label ASC',
          parameters: [tenantId],
        )
        .map(
          (rows) =>
              rows.map((r) => AdjustmentReason.fromMap(r)).toList(),
        );
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
    await _db.execute(
      'DELETE FROM stock_adjustment_reasons WHERE id = ?',
      [id],
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
      'INSERT INTO item_groups (id, tenant_id, branch_id, name, description, default_commission_type, default_commission_value, attributes, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        group.id,
        group.tenantId,
        group.branchId,
        group.name,
        group.description,
        group.defaultCommissionType,
        group.defaultCommissionValue,
        jsonEncode(group.attributes),
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> updateItemGroup(ItemGroup group) async {
    await _db.execute(
      'UPDATE item_groups SET name = ?, description = ?, default_commission_type = ?, default_commission_value = ?, attributes = ?, updated_at = ? WHERE id = ?',
      [
        group.name,
        group.description,
        group.defaultCommissionType,
        group.defaultCommissionValue,
        jsonEncode(group.attributes),
        DateTime.now().toIso8601String(),
        group.id,
      ],
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
          (results) =>
              results.map((row) => CompositeItemComponent.fromMap(row)).toList(),
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
          product_type, variant_options, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
          'composite',
          product.variantOptions != null ? jsonEncode(product.variantOptions) : null,
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
      'UPDATE customers SET name = ?, phone = ?, email = ?, updated_at = ? WHERE id = ?',
      [
        customer.name,
        customer.phone,
        customer.email,
        DateTime.now().toIso8601String(),
        customer.id,
      ],
    );
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
        [customerId, salespersonId, subtotal, grandTotal, grandTotal, notes, dueDate, now, saleId],
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
      final saleRow =
          await tx.getOptional('SELECT * FROM sales WHERE id = ?', [saleId]);
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

      String? completedAtStr = sale.completedAt?.toIso8601String();
      var newStatus = sale.status;

      // Auto-complete logic
      var newFulfillmentStatus = sale.fulfillmentStatus;
      if (newPaymentStatus == PaymentStatus.paid) {
        if (sale.status == InvoiceStatus.approved) {
           newStatus = InvoiceStatus.completed;
           completedAtStr = now;
        } else if (sale.status == InvoiceStatus.draft) {
           // Should technically not happen as draft -> pending_approval on save
           // but if a retail cashier completes a draft immediately, it bypasses approval
           newStatus = InvoiceStatus.completed;
           completedAtStr = now;
        }
        // If it was pendingApproval, it remains pendingApproval (until explicitly approved)
      }

      // Auto-fulfill on first payment
      bool newlyFulfilled = false;
      if (sale.fulfillmentStatus != FulfillmentStatus.released) {
        newFulfillmentStatus = FulfillmentStatus.released;
        newlyFulfilled = true;
      }

      await tx.execute(
        'UPDATE sales SET amount_paid = ?, status = ?, payment_status = ?, fulfillment_status = ?, payment_method = ?, updated_at = ?, completed_at = ? WHERE id = ?',
        [
          newAmountPaid,
          newStatus.value,
          newPaymentStatus.value,
          newFulfillmentStatus.value,
          paymentMethod,
          now,
          completedAtStr,
          sale.id,
        ],
      );
      
      // Since it's fulfilled, decrement stock
      if (newlyFulfilled) {
        final items = await tx.getAll('SELECT product_id, quantity FROM sale_items WHERE sale_id = ?', [sale.id]);
        for (final item in items) {
          final productId = item['product_id'] as String;
          final quantity = (item['quantity'] as num).toInt();
          
          await _adjustStockInTx(
            tx, 
            productId: productId, 
            branchId: sale.branchId, 
            quantityChange: -quantity, 
            tenantId: sale.tenantId, 
            adjustmentType: 'reduction',
            createdBy: 'system',
            notes: 'Sale fulfilled via payment', 
            referenceNumber: sale.id,
          );
        }
      }
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

    var sql = 'SELECT COUNT(*) as count FROM stock_adjustments WHERE created_at >= ?';
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
         WHERE s.status = 'completed'$branchFilter
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

  Stream<SyncStatus> get syncStatus => _db.statusStream;
}
