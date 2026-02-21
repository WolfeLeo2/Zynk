# Database Schema (Supabase + Drift)

This document defines the core schema. All tables (except `tenants`) must have a `tenant_id` column.

## 1. Multi-Tenancy & Auth

### `public.tenants`
*   `id` (UUID, PK)
*   `name` (Text): Business Name (e.g., "Neoman Styles")
*   `plan_type` (Text): 'Basic', 'Pro', 'Enterprise'
*   `created_at` (Timestamp)

### `public.profiles`
*   `id` (UUID, PK)
*   `user_id` (UUID, FK -> auth.users): The Supabase Auth User.
*   `tenant_id` (UUID, FK -> tenants.id)
*   `branch_id` (UUID, FK -> branches.id): The specific shop they are assigned to.
    *   `role` (Text): 'Owner', 'Manager', 'Cashier'
    *   `display_name` (Text)

## 2. Inventory & Product Catalog

### `public.locations` (New)
*   `id` (UUID, PK)
*   `tenant_id` (UUID, FK)
*   `name` (Text): e.g., "Nairobi Warehouse", "Mombasa Road Shop"
*   `type` (Text): 'Region', 'Warehouse', 'Store'
*   `address` (Text)

### `public.item_groups` (New)
*   `id` (UUID, PK)
*   `tenant_id` (UUID, FK)
*   `name` (Text): e.g., "Galaxy S Series"
*   `description` (Text)
*   `default_commission_type` (Text): 'fixed' or 'percent'
*   `default_commission_value` (Real)

### `public.branches`
*   `id` (UUID, PK)
*   `tenant_id` (UUID, FK)
*   `location_id` (UUID, FK -> locations.id): Links branch to a physical location.
*   `name` (Text): e.g., "Mombasa Road Branch"
*   `address` (Text): Physical address or location description.
*   `location` (Text/JSONB): GPS or Address (Legacy, use location_id or address)

### `public.products`
*   `id` (UUID, PK)
*   `tenant_id` (UUID, FK)
*   `item_group_id` (UUID, FK -> item_groups.id): Links product to a group.
*   `name` (Text)
*   `sku` (Text): Barcode/Unique ID.
*   `description` (Text)
*   `base_price` (Decimal): Default selling price.
*   `tax_category` (Text): 'VAT_16', 'Exempt', 'Zero_Rated'
*   `is_service` (Boolean): True for products (no stock tracking).
*   `commission_type` (Text): 'fixed' or 'percent' (Overrides group default)
*   `commission_value` (Real)

### `public.stock`
*   `id` (UUID, PK)
*   `tenant_id` (UUID, FK)
*   `branch_id` (UUID, FK -> branches.id)
*   `product_id` (UUID, FK -> products.id)
*   `quantity` (Integer): Current stock level.
*   `reorder_level` (Integer): Alert threshold.
*   `last_updated` (Timestamp)

## 3. Sales & Finance

### `public.customers`
*   `id` (UUID, PK)
*   `tenant_id` (UUID, FK)
*   `name` (Text)
*   `phone` (Text): Primary identifier for loyalty.
*   `email` (Text, Nullable)
*   `loyalty_points` (Integer)
*   `credit_limit` (Decimal)

### `public.sales` (Transactions)
*   `id` (UUID, PK)
*   `tenant_id` (UUID, FK)
*   `branch_id` (UUID, FK)
*   `customer_id` (UUID, FK, Nullable)
*   `total_amount` (Decimal)
*   `payment_method` (Text): 'Cash', 'M-Pesa', 'Card', 'Credit'
*   `status` (Text): 'Draft', 'Completed', 'Voided'
*   `synced_at` (Timestamp, Nullable): Null if offline/unsynced.
*   `external_ref` (Text): e.g., Shopify Order ID.

### `public.sale_items`
*   `id` (UUID, PK)
*   `sale_id` (UUID, FK -> sales.id)
*   `product_id` (UUID, FK -> products.id)
*   `quantity` (Integer)
*   `unit_price` (Decimal)
*   `tax_amount` (Decimal)
*   `total` (Decimal)

## 4. Security (RLS) policies
*   **Global Rule:** `auth.uid() IN (SELECT user_id FROM profiles WHERE tenant_id = tables.tenant_id)`
*   **Drift/Client Rule:** All local queries must filter `WHERE tenant_id = <current_session_tenant_id>`.
