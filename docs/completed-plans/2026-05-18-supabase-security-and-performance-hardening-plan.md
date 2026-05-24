# 2026-05-18 Supabase Security and Performance Hardening Plan

This plan documents the security and performance hardening of the Supabase database `kfqionlpnjetpmuzsvfb` to address all database lints and advisory notices.

## Objectives

1. **Security Hardening**:
   - Resolve **`function_search_path_mutable`** by setting explicit `search_path` bindings.
   - Resolve **`anon_security_definer_function_executable`** by revoking public execute rights on trigger and internal business functions, restricting PostgREST RPC visibility.
   - Resolve **`public_bucket_allows_listing`** by replacing overly permissive bucket `SELECT` policies with role-restricted and owner-restricted policies.
   - Lock down insecure public write privileges on `logos` storage.

2. **Performance Hardening**:
   - Resolve **`auth_rls_initplan`** by optimizing `expense_categories` and `expenses` RLS policies to use the standardized, cached `tenant_id = current_tenant_id()` pattern.
   - Resolve **`multiple_permissive_policies`** by dropping redundant global lookup table policies and targeting the `service_role` role explicitly.
   - Resolve **`unindexed_foreign_keys`** by adding covering indexes for all 21 unindexed foreign keys identified in the audit.

---

## User Review Required

> [!IMPORTANT]
> **No Client-Side Changes Needed**: The database tables, column names, and overall structure remain completely unchanged. The local PowerSync configuration and Dart models are perfectly preserved, meaning no client-side changes are required.

> [!WARNING]
> **Storage Policy Tightening**:
> - We are revoking public `SELECT` policies from `avatars`, `logos`, and `product-images` buckets. Unauthenticated users (e.g., anonymous public visitors) will still be able to read/view images using direct public URLs (since these buckets are marked as "Public" in Supabase Storage), but they will **no longer** be able to list bucket contents using `.list()` or directly querying the `storage.objects` table.
> - We are changing `logos` insert/update permissions from `PUBLIC` to `authenticated` users only to prevent unauthenticated database writes.

---

## Open Questions

> [!NOTE]
> **Leaked Password Protection**: Enabling compromised password checks (`auth_leaked_password_protection`) is a project-level setting. Since this setting cannot be configured via SQL migrations, we have added a manual configuration step in the Verification section for you to toggle it in your Supabase Auth dashboard.

---

## Proposed Changes

### Supabase Database Migration

#### [NEW] [20260518000000_supabase_security_and_performance_remediation.sql](file:///Users/app/AndroidStudioProjects/Zynk/supabase/migrations/20260518000000_supabase_security_and_performance_remediation.sql)

This new migration file will apply all database-level security and performance remediations in a single, safe transactional block.

```sql
-- Zynk Supabase Security and Performance Hardening Migration
-- Target Project ID: kfqionlpnjetpmuzsvfb

BEGIN;

-- ============================================================================
-- 1. SECURITY: TRIGGER & HELPER SEARCH PATH BINDINGS
-- ============================================================================

ALTER FUNCTION public.calculate_commission_on_sale() SET search_path = public;
ALTER FUNCTION public.update_kpi_expenses() SET search_path = public;

-- ============================================================================
-- 2. SECURITY: REVOKE EXECUTE PRIVILEGES ON SECURITY DEFINER FUNCTIONS
-- ============================================================================

-- Revoke public execute on trigger and internal helper functions
REVOKE EXECUTE ON FUNCTION public.calculate_commission_on_sale() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.decrement_stock(uuid, uuid, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.increment_stock(uuid, uuid, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.generate_credit_note_number(uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.generate_invoice_number(uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.next_invoice_number(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.refresh_daily_operational_aggregates(date, uuid, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.sync_credit_note_items_json() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.update_kpi_expenses() FROM PUBLIC;

-- Standardize current_tenant_id() execute permission: restrict to authenticated users
REVOKE EXECUTE ON FUNCTION public.current_tenant_id() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_tenant_id() TO authenticated;

-- ============================================================================
-- 3. SECURITY: TIGHTEN STORAGE POLICIES (PREVENT PUBLIC BUCKET LISTING)
-- ============================================================================

-- A. Avatars Bucket
DROP POLICY IF EXISTS "Allow public view" ON storage.objects;
CREATE POLICY "Allow authenticated users to read their own avatar" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'avatars'::text AND (storage.foldername(name))[1] = (auth.uid())::text);

-- B. Logos Bucket
-- Drop overly permissive select policy
DROP POLICY IF EXISTS "Allow uploads 1peuqw_2" ON storage.objects;
CREATE POLICY "Allow authenticated users to read logos" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'logos'::text);

-- Drop unauthenticated logo write/update policies
DROP POLICY IF EXISTS "Allow uploads 1peuqw_0" ON storage.objects;
DROP POLICY IF EXISTS "Allow uploads 1peuqw_1" ON storage.objects;

-- Re-create write policies restricted to authenticated users
CREATE POLICY "Allow authenticated users to upload logos" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'logos'::text);
CREATE POLICY "Allow authenticated users to update logos" ON storage.objects
  FOR UPDATE TO authenticated USING (bucket_id = 'logos'::text);

-- C. Product-Images Bucket
DROP POLICY IF EXISTS "Public Access" ON storage.objects;
CREATE POLICY "Allow authenticated users to read product images" ON storage.objects
  FOR SELECT TO authenticated USING (bucket_id = 'product-images'::text);

-- Standardize product images upload policy to authenticated role directly
DROP POLICY IF EXISTS "Authenticated Upload" ON storage.objects;
CREATE POLICY "Allow authenticated users to upload product images" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'product-images'::text);


-- ============================================================================
-- 4. PERFORMANCE: RLS INITPLAN OPTIMIZATION (EXPENSES & CATEGORIES)
-- ============================================================================

-- Optimize expense_categories policies to use standard cached current_tenant_id()
DROP POLICY IF EXISTS "Users can view their own tenant categories" ON public.expense_categories;
DROP POLICY IF EXISTS "Users can insert their own tenant categories" ON public.expense_categories;
DROP POLICY IF EXISTS "Users can update their own tenant categories" ON public.expense_categories;

CREATE POLICY "expense_categories_tenant_isolation" ON public.expense_categories
  FOR ALL TO public USING (tenant_id = current_tenant_id()) WITH CHECK (tenant_id = current_tenant_id());

-- Optimize expenses policies to use standard cached current_tenant_id()
DROP POLICY IF EXISTS "Users can view their own tenant expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users can insert their own tenant expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users can update their own tenant expenses" ON public.expenses;
DROP POLICY IF EXISTS "Users can delete their own tenant expenses" ON public.expenses;

CREATE POLICY "expenses_tenant_isolation" ON public.expenses
  FOR ALL TO public USING (tenant_id = current_tenant_id()) WITH CHECK (tenant_id = current_tenant_id());


-- ============================================================================
-- 5. PERFORMANCE: RESOLVE MULTIPLE PERMISSIVE POLICIES ON LOOKUPS
-- ============================================================================

-- A. commission_calculation_types
DROP POLICY IF EXISTS commission_calculation_types_service_write ON public.commission_calculation_types;
CREATE POLICY commission_calculation_types_service_write ON public.commission_calculation_types
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- B. commission_statuses
DROP POLICY IF EXISTS commission_statuses_service_write ON public.commission_statuses;
CREATE POLICY commission_statuses_service_write ON public.commission_statuses
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- C. credit_note_statuses
DROP POLICY IF EXISTS credit_note_statuses_service_write ON public.credit_note_statuses;
CREATE POLICY credit_note_statuses_service_write ON public.credit_note_statuses
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- D. fulfillment_statuses
DROP POLICY IF EXISTS fulfillment_statuses_service_write ON public.fulfillment_statuses;
CREATE POLICY fulfillment_statuses_service_write ON public.fulfillment_statuses
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- E. invoice_statuses
DROP POLICY IF EXISTS invoice_statuses_service_write ON public.invoice_statuses;
CREATE POLICY invoice_statuses_service_write ON public.invoice_statuses
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- F. payment_methods
DROP POLICY IF EXISTS payment_methods_service_write ON public.payment_methods;
CREATE POLICY payment_methods_service_write ON public.payment_methods
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- G. payment_statuses
DROP POLICY IF EXISTS payment_statuses_service_write ON public.payment_statuses;
CREATE POLICY payment_statuses_service_write ON public.payment_statuses
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- H. sale_types
DROP POLICY IF EXISTS sale_types_service_write ON public.sale_types;
CREATE POLICY sale_types_service_write ON public.sale_types
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- I. stock_adjustment_statuses
DROP POLICY IF EXISTS stock_adjustment_statuses_service_write ON public.stock_adjustment_statuses;
CREATE POLICY stock_adjustment_statuses_service_write ON public.stock_adjustment_statuses
  FOR ALL TO service_role USING (true) WITH CHECK (true);

-- J. stock_adjustment_types
DROP POLICY IF EXISTS stock_adjustment_types_service_write ON public.stock_adjustment_types;
CREATE POLICY stock_adjustment_types_service_write ON public.stock_adjustment_types
  FOR ALL TO service_role USING (true) WITH CHECK (true);


-- ============================================================================
-- 6. PERFORMANCE: FOREIGN KEY COVERING INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_commissions_status ON public.commissions(status);
CREATE INDEX IF NOT EXISTS idx_credit_notes_status ON public.credit_notes(status);
CREATE INDEX IF NOT EXISTS idx_daily_payment_method_snapshots_payment_method ON public.daily_payment_method_snapshots(payment_method);
CREATE INDEX IF NOT EXISTS idx_expense_categories_tenant_id ON public.expense_categories(tenant_id);
CREATE INDEX IF NOT EXISTS idx_expenses_branch_id ON public.expenses(branch_id);
CREATE INDEX IF NOT EXISTS idx_expenses_category_id ON public.expenses(category_id);
CREATE INDEX IF NOT EXISTS idx_expenses_payment_method ON public.expenses(payment_method);
CREATE INDEX IF NOT EXISTS idx_expenses_staff_member_id ON public.expenses(staff_member_id);
CREATE INDEX IF NOT EXISTS idx_expenses_tenant_id ON public.expenses(tenant_id);
CREATE INDEX IF NOT EXISTS idx_item_groups_default_commission_type ON public.item_groups(default_commission_type);
CREATE INDEX IF NOT EXISTS idx_product_branches_branch_id ON public.product_branches(branch_id);
CREATE INDEX IF NOT EXISTS idx_products_commission_type ON public.products(commission_type);
CREATE INDEX IF NOT EXISTS idx_sale_payments_payment_method ON public.sale_payments(payment_method);
CREATE INDEX IF NOT EXISTS idx_sales_fulfillment_status ON public.sales(fulfillment_status);
CREATE INDEX IF NOT EXISTS idx_sales_payment_status ON public.sales(payment_status);
CREATE INDEX IF NOT EXISTS idx_sales_sale_type ON public.sales(sale_type);
CREATE INDEX IF NOT EXISTS idx_sales_status ON public.sales(status);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_adjustment_type ON public.stock_adjustments(adjustment_type);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_approved_by ON public.stock_adjustments(approved_by);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_salesperson_id ON public.stock_adjustments(salesperson_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_status ON public.stock_adjustments(status);

COMMIT;
```
