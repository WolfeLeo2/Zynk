# Item Groups, Variants & Logistics Implementation Plan

> **For AI Agents:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enhance the product creation flow by deeply integrating item groups with commissions, introducing product variants, adding physical logistics (weight/dimensions) controlled by a global setting, and handling variant selection seamlessly in the POS.

**Architecture:** 
- The schema will be updated via Supabase MCP to support `weight`, `length`, `width`, and `height` in the products table.
- A new global setting provider will manage the Preferred Unit System (Metric vs Imperial).
- The `AddProductScreen` will be significantly upgraded to include a full BottomSheet for Item Group creation (with commission fields), a dynamic UI for variant option definitions, and a section for physical dimensions.
- The POS Screen will intercept taps on items with variants to display a selection BottomSheet before adding them to the ticket.

**Tech Stack:** Flutter, Riverpod, Supabase (PowerSync), Phosphor Icons

---

### Task 1: Update UI & Logic for Item Group Creation

**Files:**
- Modify: `lib/features/products/presentation/add_product_screen.dart`

**Step 1: Write UI for Item Group Bottom Sheet**
Replace the simple `AlertDialog` in `_showAddGroupDialog` with a full `showModalBottomSheet`. It must include:
- `TextFormField` for Name
- `TextFormField` for Description (optional)
- `DropdownButtonFormField` for `defaultCommissionType` ('none', 'fixed', 'percent')
- `TextFormField` for `defaultCommissionValue` (enabled if type != 'none')

**Step 2: Update Validation Logic**
In `_saveProduct`, add validation to ensure `_selectedItemGroupId` is not null. If it is null, show a `SnackBar` and return early, preventing saving without an item group.

**Step 3: Run analysis to verify**
Run: `dart analyze`
Expected: No issues.

**Step 4: Commit**
```bash
git add lib/features/products/presentation/add_product_screen.dart
git commit -m "feat: complete item group bottomsheet and make group selection mandatory"
```

---

### Task 2: Global Settings for Measurement Units

**Files:**
- Create: `lib/core/providers/preferences_provider.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Step 1: Create Preferences Provider**
Create a `StateNotifier` for 'measurement_system' resting on `SharedPreferences` (or a simple Riverpod provider for now if SharedPrefs isn't fully integrated, but ideally use standard local storage). It should toggle between `metric` (kg, cm) and `imperial` (lb, in).

**Step 2: Add to Settings Screen**
In `SettingsScreen`, add an option card or dropdown in the "Business Settings" or "App Settings" area to select the "Measurement System". 

**Step 3: Run analysis**
Run: `dart analyze`
Expected: No issues.

**Step 4: Commit**
```bash
git add lib/core/providers/preferences_provider.dart lib/features/settings/presentation/settings_screen.dart
git commit -m "feat: add global preference for measurement units"
```

---

### Task 3: Product Dimensions & Weight Schema

**Files:**
- Modify: `lib/core/models/schema_models.dart`
- Modify: `lib/data/local/repository.dart`

**Step 1: Update MCP SQLite / Supabase (Manual Step)**
Use Supabase MCP to add `weight` (real), `length` (real), `width` (real), and `height` (real) to the `products` table.

**Step 2: Update Dart Models & Repository**
- Update `Product.fromMap`, `Product.toMap`, and `Product.copyWith` adding the 4 new double fields.
- Ensure the `repository.dart` handles syncing these if they require explicit query mapping (usually PowerSync handles `*` but explicit reads mapping needs updates).

**Step 3: Run analysis**
Run: `dart analyze`
Expected: No issues.

**Step 4: Commit**
```bash
git add lib/core/models/schema_models.dart lib/data/local/repository.dart
git commit -m "feat: add logistics fields to product schema"
```

---

### Task 4: UI for Dimensions and Variants in Add Product

**Files:**
- Modify: `lib/features/products/presentation/add_product_screen.dart`
- Modify: `lib/features/products/presentation/providers/add_product_controller.dart`

**Step 1: Add Dimensions Fields**
Below the Basic Info, add an "Inventory & Logistics" section (if not there yet) containing 4 `TextFormField`s for Length, Width, Height, and Weight. The labels must react to the global state from Task 2 (e.g. `Weight (kg)` vs `Weight (lb)`).

**Step 2: Add Variants Definition UI**
Create a dynamic UI block allowing the user to add an attribute name (e.g. "Size") and a comma-separated list of values (e.g. "Small, Medium, Large"). Store this in a temporary map inside the state class.

**Step 3: Update `add_product_controller.dart`**
Update `saveProduct` to accept the new dimension parameters and the `variantOptions` map, passing them cleanly to the repository.

**Step 4: Run analysis**
Run: `dart analyze`
Expected: No issues.

**Step 5: Commit**
```bash
git add lib/features/products/presentation/add_product_screen.dart lib/features/products/presentation/providers/add_product_controller.dart
git commit -m "feat: add UI fields for variants and physical dimensions"
```

---

### Task 5: POS Variant Selection BottomSheet

**Files:**
- Create: `lib/features/pos/presentation/widgets/variant_selection_bottom_sheet.dart`
- Modify: `lib/features/pos/presentation/pos_screen.dart`

**Step 1: Create the Selection UI**
When a product with `variantOptions` (where it's not null and not empty) is tapped, open a BottomSheet. The sheet iterates through the keys of `variantOptions` creating a dropdown or chip-selector for each. Finally, an "Add to Ticket" button confirms the selected variant combination string (e.g., `Shirt - Size: S, Color: Red`).

**Step 2: Intercept Product Tap in POS**
In `PosScreen` (or `ProductsGrid` depending on structure), inside the `onTap` for a standard product, check if `product.variantOptions?.isNotEmpty == true`. If so, call the new bottom sheet. If not, add directly to ticket as before. The added ticket line item should record the variant selections (possibly appending to note or a new `variant_selections` JSON field on the order line if needed).

**Step 3: Run analysis**
Run: `dart analyze`
Expected: No issues.

**Step 4: Commit**
```bash
git add lib/features/pos/presentation/widgets/variant_selection_bottom_sheet.dart lib/features/pos/presentation/pos_screen.dart
git commit -m "feat: intercept variant selection in POS"
```
