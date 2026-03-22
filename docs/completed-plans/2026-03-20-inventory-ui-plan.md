# Inventory UI Implementation Plan

> **For AI Agents:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create the presentation layer (UI) for managing Standard Products, Item Groups, and Composite Items using the "Approach B" bottom-sheet selector and incorporating Unit of Measurements (UOM).

---
### Preliminary Task: Data Layer for UOM
**Files:**
- Supabase MCP Tool (Apply Migration)
- Modify: `sync_rules.yaml`
- Modify: `lib/core/config/powersync.dart`
- Modify: `lib/core/models/schema_models.dart`, `lib/data/local/repository.dart`

**Step 1:** Introduce `public.units_of_measurement` table (Columns: `id`, `tenant_id`, `label`).
**Step 2:** Add `uom_id` column to `public.products`.
**Step 3:** Hook into PowerSync, update the `Product` schema/model, and create repository CRUD endpoints.

---
### Task 1: Add Product Entry Flow (Approach B)
**Files:**
- Modify: `lib/features/products/presentation/products_screen.dart`
- Create: `lib/features/products/presentation/components/add_item_type_sheet.dart`

**Step 1:** The primary `+` button opens a clean, well-spaced Bottom Sheet (`AddItemTypeSheet`).
**Step 2:** The sheet gives 3 distinct, clearly explained options:
1. **Single Item:** A standalone physical or service product.
2. **Item Group:** A collection of variants (e.g., a T-Shirt in S, M, L).
3. **Composite Item:** A bundle or kit made of other single items.
Tapping an option pushes to its respective dedicated screen.

### Task 2: Standard "Single Item" Form
**Files:**
- Modify: `lib/features/products/presentation/add_product_screen.dart`

**Step 1:** Refactor the UI into segmented cards (Basic Info, Pricing, Inventory) leveraging the soft-minimal card theme.
**Step 2:** Add "Unit of Measurement" (UOM) Selector.
- Like Categories, it features a Searchable Dropdown.
- Includes a "plus" button that opens a bottom sheet to create new UOM labels.
**Step 3:** Add an **Attributes** section. A user can define `variant_options` JSON manually here (e.g., `{"Color": "Red", "Size": "10"}`) even if not part of a bulk-generated group.
**Step 4:** Allow the user to select an existing **Item Group** reference to link it.

### Task 3: Item Groups Form
**Files:**
- Create: `lib/features/products/presentation/add_item_group_screen.dart`

**Step 1:** Form for `GroupName` and `Description`.
**Step 2:** **Variant Matrix Generator:** Users input Attributes. They add options (S, L). It auto-generates a grid where each row represents a distinct variant.
**Step 3:** Submitting creates the `stock_item_group` and bulk-inserts standard products linked to the group.

### Task 4: Composite Items Form & Bundle Action
**Files:**
- Create: `lib/features/products/presentation/add_composite_item_screen.dart`
- Create: `lib/features/products/presentation/components/bundle_action_sheet.dart`

**Step 1:** **Add Screen:** Standard details (Name, Price). In the "Components" section, a selector to add multiple existing standard items and define requisite quantities.
**Step 2:** **Bundle Action:** On the details view of a Composite Item, an action "Create Bundle" allows the user to enter a quantity (e.g., "5 Kits"). A local repository command executes, mathematically decrementing the component stocks and incrementing the composite stock.
