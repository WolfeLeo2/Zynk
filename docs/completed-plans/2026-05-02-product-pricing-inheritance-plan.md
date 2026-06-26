# Item Group Pricing + Group CSV Import Implementation Plan (Revised)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enable tenant-wide item group defaults for selling/buying prices and fixed commissions, allow product-level price overrides, and support automated group creation via CSV imports.

**Architecture:** 
- Pricing defaults and fixed commissions are stored in `item_groups`.
- Products inherit group prices if their own `base_price` is null.
- A central `ProductPricingService` handles resolution of "effective" prices at runtime.
- CSV imports automatically map items to groups, creating groups on-the-fly if necessary.

**Tech Stack:** Flutter, Riverpod, PowerSync, Supabase, `json_serializable`.

---

### Task 1: Client-Side Schema Alignment
**Files:**
- Modify: `lib/core/config/powersync.dart`
- Modify: `lib/core/models/schema_models.dart`
- Modify: `lib/data/local/repository.dart`

**Step 1: Update PowerSync Schema**
Update `item_groups` and `products` table definitions in `powersync.dart` to match the current Supabase schema.
- Remove `default_commission_type` from `item_groups`.
- Add `default_selling_price` (real), `default_buying_price` (real) to `item_groups`.
- Ensure `base_price` and `cost_price` in `products` are mapped as nullable.

**Step 2: Update Dart Models**
Update `ItemGroup` and `Product` in `schema_models.dart`.
- Include `attributes` (String?) in `ItemGroup`.
- Add `defaultSellingPrice` and `defaultBuyingPrice` to `ItemGroup`.
- Make `basePrice` nullable in `Product`.
- Ensure `uomId` and `parentId` are correctly typed in `Product`.
- Run `dart run build_runner build --delete-conflicting-outputs`.

**Step 3: Fix Repository SQL**
Update `createItemGroup`, `updateItemGroup`, `createProduct`, and `updateProduct` in `repository.dart` to use the new column set and remove the deleted ones.

**Step 4: Verify with Analyzer**
Run: `dart analyze`
Expected: No errors related to missing/renamed fields in the modified files.

---

### Task 2: Pricing Resolution Service
**Files:**
- [NEW] Create: `lib/core/models/product_pricing.dart`

**Step 1: Write Unit Tests**
Create `test/core/models/product_pricing_test.dart` to test resolution logic:
- Product has price -> return product price.
- Product price is null, Group has price -> return group price.
- Both null -> return 0.0.

**Step 2: Implement Logic**
```dart
class ProductPricing {
  static double resolveSellingPrice(Product product, ItemGroup? group) {
    return product.basePrice ?? group?.defaultSellingPrice ?? 0.0;
  }
  static double resolveBuyingPrice(Product product, ItemGroup? group) {
    return product.costPrice ?? group?.defaultBuyingPrice ?? 0.0;
  }
}
```

---

### Task 3: Item Group UI Overhaul
**Files:**
- Modify: `lib/features/products/presentation/add_product_screen.dart` (Add Group BottomSheet)

**Step 1: Remove Commission Type Selection**
In `_showAddGroupBottomSheet`, remove the `DropdownButtonFormField` for commission type. Default all commissions to "Fixed".

**Step 2: Add Price Defaults**
Add text fields for `Default Selling Price` and `Default Buying Price` to the "New Item Group" form.

---

### Task 4: Product UI Inheritance & Overrides
**Files:**
- Modify: `lib/features/products/presentation/add_product_screen.dart`

**Step 1: Support Nullable Price Input**
Allow the "Base Price" field to be empty. If empty, it should be saved as `null`.

**Step 2: Show "Inherited" Hint**
When an Item Group is selected, if the Price field is empty, show the group's default price as a label or helper text (e.g., "Inherited: 500.00").

---

### Task 5: CSV Import with Auto-Grouping
**Files:**
- Modify: `lib/features/products/data/csv_import_service.dart`

**Step 1: Add Group Resolution Logic**
Update the parser to check for an "Item Group" column.
- If the group name doesn't exist in the local DB, create it with default prices (if provided in CSV) or as a basic group.
- Link the product to the resolved `item_group_id`.

---

### Task 6: Final Verification & Cleanup
**Step 1: Global Search for Stale Fields**
Search the entire project for `default_commission_type` and `commission_type` (on products) and remove any remaining UI or logic references.

**Step 2: Run Suite**
Run: `flutter test`
Run: `dart analyze`
