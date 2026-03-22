# Inventory Enhancements Implementation Plan

> **For AI Agents:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the database schema, models, and local sync layer for Zoho-style Item Groups and Composite Items.

**Architecture:** A fully normalized relational schema synced via PowerSync. A new `stock_item_groups` table will be created. The `products` table will gain `group_id`, `variant_options`, and `product_type`. A `composite_item_components` table will link composite products to component products.

**Tech Stack:** Supabase (Migrations via MCP), PowerSync (Local SQLite synced via `sync_rules.yaml`), Dart Models (json_serializable).

---
### Task 1: Database Migrations
**Files:**
- Use: Supabase MCP tool `apply_migration`

**Step 1: Execute Migration for Item Groups**
Execute the following SQL with migration name `add_stock_item_groups`:
```sql
CREATE TABLE public.stock_item_groups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    attributes JSONB
);
ALTER TABLE public.stock_item_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Tenant Isolation" ON public.stock_item_groups FOR ALL USING (tenant_id = (SELECT auth.jwt() ->> 'tenant_id')::uuid);
```

**Step 2: Execute Migration for Products modifications**
Execute the following SQL with migration name `update_products_for_groups`:
```sql
ALTER TABLE public.products ADD COLUMN group_id UUID REFERENCES public.stock_item_groups(id) ON DELETE SET NULL;
ALTER TABLE public.products ADD COLUMN variant_options JSONB;
ALTER TABLE public.products ADD COLUMN product_type TEXT NOT NULL DEFAULT 'standard';
```

**Step 3: Execute Migration for Composite Items**
Execute the following SQL with migration name `add_composite_item_components`:
```sql
CREATE TABLE public.composite_item_components (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    composite_product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    component_product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL
);
ALTER TABLE public.composite_item_components ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Tenant Isolation" ON public.composite_item_components FOR ALL USING (tenant_id = (SELECT auth.jwt() ->> 'tenant_id')::uuid);
```

### Task 2: PowerSync Schema & Sync Rules
**Files:**
- Modify: `sync_rules.yaml`
- Modify: `lib/core/config/powersync.dart`

**Step 1: Update Sync Rules**
Add `stock_item_groups` and `composite_item_components` to `sync_rules.yaml` under the tenant bucket.

**Step 2: Update PowerSync Schema**
Add the new tables to `lib/core/config/powersync.dart`. Update the `products` definition to include `group_id`, `variant_options`, and `product_type`. Ensure you match the SQLite types correctly (e.g., TEXT for UUID and JSONB).

### Task 3: Dart Models
**Files:**
- Create: `lib/core/models/item_group.dart`
- Create: `lib/core/models/composite_component.dart`
- Modify: `lib/core/models/schema_models.dart`

**Step 1: Create ItemGroup and CompositeComponent models**
Implement `json_serializable` classes matching the table definitions.

**Step 2: Update Product model**
Add `groupId`, `variantOptions`, and `productType` to the `Product` model in `schema_models.dart`. Update `fromMap` factory methods to parse the JSONB maps exactly.
