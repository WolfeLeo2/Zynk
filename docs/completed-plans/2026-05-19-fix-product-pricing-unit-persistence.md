# Fix Product Pricing Unit Persistence Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure that products and item groups saved with pricing units (e.g. 'sqm') and coverage values are correctly persisted to the local database.

**Architecture:** Update SQLite/PowerSync SQL statements and argument binds in `repository.dart` for products and item groups to store `pricing_unit`/`default_pricing_unit` and `coverage_per_box`/`default_coverage_per_box`.

**Tech Stack:** Dart, Flutter, SQLite, PowerSync

---

### Task 1: Update SQL insertion and update queries for Products in repository.dart

**Files:**
- Modify: `lib/data/local/repository.dart`

**Step 1: Write SQL changes for `createProduct`**
Update the insert query in `createProduct` to include `pricing_unit` and `coverage_per_box` fields and parameters.

Lines 418-447:
```dart
      await tx.execute(
        '''INSERT INTO products (
          id, tenant_id, branch_id, item_group_id, category_id, uom_id, name, sku, barcode,
          description, image_url, base_price, cost_price, tax_category, is_service,
          commission_type, commission_value, parent_id,
          pricing_unit, coverage_per_box,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
          product.commissionType,
          product.commissionValue,
          product.parentId,
          product.pricingUnit,
          product.coveragePerBox,
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );
```

**Step 2: Write SQL changes for `updateProduct`**
Update the update query in `updateProduct` to include `pricing_unit` and `coverage_per_box` updates.

Lines 480-506:
```dart
    await _db.writeTransaction((tx) async {
      await tx.execute(
        '''UPDATE products SET
          branch_id = ?, item_group_id = ?, category_id = ?, uom_id = ?, name = ?, sku = ?, barcode = ?,
          description = ?, image_url = ?, base_price = ?, cost_price = ?, tax_category = ?,
          is_service = ?, commission_type = ?, commission_value = ?, parent_id = ?,
          pricing_unit = ?, coverage_per_box = ?,
          updated_at = ?
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
          product.commissionType,
          product.commissionValue,
          product.parentId,
          product.pricingUnit,
          product.coveragePerBox,
          DateTime.now().toIso8601String(),
          product.id,
        ],
      );
```

**Step 3: Write SQL changes for `createCompositeProduct`**
Update the insert query in `createCompositeProduct` to include `pricing_unit` and `coverage_per_box` fields and parameters.

Lines 1288-1313:
```dart
      // 1. Create the product
      await tx.execute(
        '''INSERT INTO products (
          id, tenant_id, branch_id, item_group_id, category_id, uom_id, name, sku, barcode, 
          description, image_url, base_price, cost_price, tax_category, is_service, 
          pricing_unit, coverage_per_box,
          created_at, updated_at
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
          product.pricingUnit,
          product.coveragePerBox,
          DateTime.now().toIso8601String(),
          DateTime.now().toIso8601String(),
        ],
      );
```

**Step 4: Verify Compilation**
Run `dart analyze` to ensure there are no compilation errors introduced in `repository.dart`.

---

### Task 2: Update SQL insertion and update queries for Item Groups in repository.dart

**Files:**
- Modify: `lib/data/local/repository.dart`

**Step 1: Write SQL changes for `createItemGroup`**
Update `createItemGroup` to insert `default_pricing_unit` and `default_coverage_per_box`.

Lines 1043-1066:
```dart
  Future<void> createItemGroup(ItemGroup group) async {
    await _db.execute(
      '''INSERT INTO item_groups (
        id, tenant_id, branch_id, name, description, 
        default_commission_type, default_commission_value,
        default_selling_price, default_buying_price, attributes,
        default_pricing_unit, default_coverage_per_box,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        group.id,
        group.tenantId,
        group.branchId,
        group.name,
        group.description,
        group.defaultCommissionType,
        group.defaultCommissionValue,
        group.defaultSellingPrice,
        group.defaultBuyingPrice,
        group.attributes,
        group.defaultPricingUnit,
        group.defaultCoveragePerBox,
        DateTime.now().toIso8601String(),
        DateTime.now().toIso8601String(),
      ],
    );
  }
```

**Step 2: Write SQL changes for `updateItemGroup`**
Update `updateItemGroup` to modify `default_pricing_unit` and `default_coverage_per_box`.

Lines 1068-1088:
```dart
  Future<void> updateItemGroup(ItemGroup group) async {
    await _db.execute(
      '''UPDATE item_groups SET 
        name = ?, description = ?, 
        default_commission_type = ?, default_commission_value = ?, 
        default_selling_price = ?, default_buying_price = ?, attributes = ?,
        default_pricing_unit = ?, default_coverage_per_box = ?,
        updated_at = ? 
      WHERE id = ?''',
      [
        group.name,
        group.description,
        group.defaultCommissionType,
        group.defaultCommissionValue,
        group.defaultSellingPrice,
        group.defaultBuyingPrice,
        group.attributes,
        group.defaultPricingUnit,
        group.defaultCoveragePerBox,
        DateTime.now().toIso8601String(),
        group.id,
      ],
    );
  }
```

**Step 3: Write SQL changes for `batchUpdatePricingAndGroup`**
Update `batchUpdatePricingAndGroup` to include `default_pricing_unit` and `default_coverage_per_box`.

Lines 1114-1135:
```dart
      // 3. Update the group itself if provided
      if (updatedGroup != null) {
        await tx.execute(
          '''UPDATE item_groups SET 
            name = ?, description = ?, 
            default_commission_type = ?, default_commission_value = ?, 
            default_selling_price = ?, default_buying_price = ?, attributes = ?,
            default_pricing_unit = ?, default_coverage_per_box = ?,
            updated_at = ? 
          WHERE id = ?''',
          [
            updatedGroup.name,
            updatedGroup.description,
            updatedGroup.defaultCommissionType,
            updatedGroup.defaultCommissionValue,
            updatedGroup.defaultSellingPrice,
            updatedGroup.defaultBuyingPrice,
            updatedGroup.attributes,
            updatedGroup.defaultPricingUnit,
            updatedGroup.defaultCoveragePerBox,
            now,
            updatedGroup.id,
          ],
        );
      }
```

**Step 4: Verify Compilation**
Run `dart analyze` to ensure compilation remains clean.

---

## Verification Plan

### Automated/Compilation Verification
- Run `dart analyze` on the workspace to verify there are no compilation errors or syntax issues.

### Manual Verification
- Re-run the application / flow where the product is saved as "sqm" to confirm it is successfully written to the local database and loads back as "sqm" rather than defaulting to "piece".
