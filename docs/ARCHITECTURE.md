I. Data Flow & Sync (Drift + Supabase)
We use a Repository Pattern with a "Local-First" strategy:

UI interacts only with the Drift Repository.

Drift stores the transaction and marks it as synced: false.

**Sync Strategy:**
*   **Upstream (Device -> Cloud):** A Background Service pushes unsynced rows to Supabase immediately when online.
*   **Downstream (Cloud -> Device):** The app subscribes to **Supabase Realtime** channels. Changes in the cloud (from other branches or external integrations) are instantly pushed to the device and written to Drift.

Conflict Resolution: "Last Write Wins" for general metadata; "Incremental" for stock counts (e.g., SET stock = stock - 1).

**External Integrations:**
*   **Webhooks:** Zynk uses Supabase Database Webhooks to trigger Edge Functions when specific data changes.
    *   *Example:* New Sale -> Webhook -> Edge Function -> Updates Shopify Inventory.
    *   *Example:* Shopify Order -> Webhook -> Edge Function -> Inserts Sale into Zynk Database -> Realtime syncs to Shop POS.

II. Security Architecture
Auth: Supabase Auth (JWT) containing tenant_id in the app_metadata.

Authorization: Row Level Security (RLS) policies prevent cross-tenant data leaks.

API: All sensitive logic (M-Pesa, Tax, Admin Reports) happens in Supabase Edge Functions to hide logic from the frontend.


The architecture uses a Strict Hierarchy:

### Definitions
*   **Tenant:** The Business Entity (e.g., "Neoman Styles"). An "Owner" user creates a Tenant. Data is strictly isolated by `tenant_id`.
*   **Location:** A physical or logical area (e.g., "Nairobi Region", "Main Warehouse").
*   **Branch:** A point of sale/service (e.g., "Mombasa Road Shop") belonging to a Location.

### Hierarchy
**Tenant** -> **Locations** -> **Branches**

profiles table (User_ID, Tenant_ID, Role_ID, Branch_ID)

The Global Filter: All Drift queries and Supabase RLS policies must include:
WHERE tenant_id = current_user.tenant_id AND (role == 'Admin' OR branch_id = current_user.branch_id)