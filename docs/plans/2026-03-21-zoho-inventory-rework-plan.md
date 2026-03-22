# Zoho Inventory Rework Implementation Plan

> **For AI Agents:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Revamp the inventory UI to decouple item groups and composite items into standalone screens, implementing Zoho-inspired Variant Matrix generation and Assembly vs Kit distinctions.

**Architecture:** 
- `AddItemGroupScreen` will feature a Variant Matrix Generator that takes attributes (e.g. Size, Color) and auto-generates rows for individual variants, saving them in bulk to the database linked to a `StockItemGroup`.
- `AddCompositeItemScreen` will include a toggle for `Assembly` vs `Kit` and an Associated Items list that auto-sums component costs.
- Global navigation is updated to link directly to these standalone pages.

**Tech Stack:** Flutter, Riverpod, PowerSync, Supabase

---

### Task 1: Navigation & Routing Decoupling

**Files:**
- Modify: `lib/core/routes.dart`
- Modify: `lib/features/products/presentation/products_screen.dart`
- Modify: `lib/core/widgets/app_drawer.dart`

**Step 1:** In `ProductsScreen`, remove the `DefaultTabController` and the `Item Groups` tab. Make it a single responsive screen displaying all standard products.

**Step 2:** Ensure `AppDrawer` has clear, working links for "Products", "Item Groups", and "Composite Items".

**Step 3:** In `routes.dart`, ensure `/products/groups` points to a new `ItemGroupsScreen` (which will wrap the existing `ItemGroupsView` in a Scaffold) and `/products/composite` points to a new `CompositeItemsScreen`.

---

### Task 2: Implement "Item Groups" Screen & Variant UI

**Files:**
- Create: `lib/features/products/presentation/item_groups_screen.dart`
- Create: `lib/features/products/presentation/add_item_group_screen.dart`
- Modify: `lib/data/local/repository.dart`
- Modify: `lib/core/models/schema_models.dart`

**Step 1:** Create `ItemGroupsScreen` that lists all groups, with an "Add Group" FAB pointing to `/products/groups/add`.

**Step 2:** Address data layer map. Ensure `StockItemGroup` is the active model for groups with variants (has the `attributes` field) in `schema_models.dart`. Write a repository method `createItemGroupWithVariants(StockItemGroup group, List<Product> variants)`.

**Step 3:** Implement `AddItemGroupScreen` UI.
- Top section: Group Name, Description, Category, Base UOM.
- **Attributes Section**: User adds an attribute (e.g. "Size") and options ("S, M, L").
- **Variant Matrix Generator**: A dynamically built table/list showing all permutations (e.g. Size: S, Size: M, Size: L). Each row has fields for SKU, Cost Price, Selling Price.
- Add "Copy to All" buttons for rapid data entry.

**Step 4:** On save, trigger the bulk insertion transaction.

---

### Task 3: Implement Composite Items Flow & Assembly/Kit Toggle

**Files:**
- Create: `lib/features/products/presentation/composite_items_screen.dart`
- Create: `lib/features/products/presentation/add_composite_item_screen.dart`
- Modify: `lib/features/products/presentation/providers/product_providers.dart`
- Modify: `lib/data/local/repository.dart`

**Step 1:** Create `compositeProductsProvider` filtering for `productType == 'composite'`.

**Step 2:** Create `CompositeItemsScreen` leveraging the provider, with an "Add Composite" FAB.

**Step 3:** Implement `AddCompositeItemScreen` UI.
- Implement an **Item Type Selection Toggle** (Assembly Item vs Kit Item). Save this context in the DB (either via extending the `product_type` enum or saving it in `variant_options` JSON).
- Add the **Associated Items** section (searchable dropdown adding to a list, with quantity inputs).
- Auto-calculate and display the **Total Cost Price** by summing up component costs.

**Step 4:** Save logic uses `createCompositeProduct` repository method.

---

### Task 4: Cleanup & UOM Refinement

**Files:**
- Delete: `lib/features/products/presentation/widgets/product_type_bottom_sheet.dart`
- Modify: `lib/features/products/presentation/add_product_screen.dart`
- Modify: `docs/completed-plans/`

**Step 1:** Audit `AddProductScreen` to ensure the UOM Searchable Dropdown matches the Zoho pattern entirely (already largely done, just verify spacing and labels). Remove composite-specific conditional UI (`_buildCompositeSection()`) from this standard product screen.

**Step 2:** Delete `ProductTypeBottomSheet` as all types now have independent navigation flows.

**Step 3:** Move obsolete/completed plans to `docs/completed-plans`.
