-- Phase 5: Cover unindexed foreign keys (advisor-driven)
-- Project: kfqionlpnjetpmuzsvfb

CREATE INDEX IF NOT EXISTS idx_branches_location_id ON public.branches(location_id);
CREATE INDEX IF NOT EXISTS idx_branches_tenant_id ON public.branches(tenant_id);

CREATE INDEX IF NOT EXISTS idx_categories_branch_id ON public.categories(branch_id);
CREATE INDEX IF NOT EXISTS idx_categories_tenant_id ON public.categories(tenant_id);

CREATE INDEX IF NOT EXISTS idx_commissions_sale_id ON public.commissions(sale_id);

CREATE INDEX IF NOT EXISTS idx_composite_item_components_component_product_id
  ON public.composite_item_components(component_product_id);
CREATE INDEX IF NOT EXISTS idx_composite_item_components_composite_product_id
  ON public.composite_item_components(composite_product_id);

CREATE INDEX IF NOT EXISTS idx_credit_note_items_product_id
  ON public.credit_note_items(product_id);

CREATE INDEX IF NOT EXISTS idx_credit_notes_applied_to_sale_id
  ON public.credit_notes(applied_to_sale_id);
CREATE INDEX IF NOT EXISTS idx_credit_notes_approved_by
  ON public.credit_notes(approved_by);
CREATE INDEX IF NOT EXISTS idx_credit_notes_branch_id
  ON public.credit_notes(branch_id);
CREATE INDEX IF NOT EXISTS idx_credit_notes_created_by
  ON public.credit_notes(created_by);

CREATE INDEX IF NOT EXISTS idx_customers_branch_id ON public.customers(branch_id);
CREATE INDEX IF NOT EXISTS idx_customers_tenant_id ON public.customers(tenant_id);

CREATE INDEX IF NOT EXISTS idx_item_groups_branch_id ON public.item_groups(branch_id);
CREATE INDEX IF NOT EXISTS idx_item_groups_tenant_id ON public.item_groups(tenant_id);

CREATE INDEX IF NOT EXISTS idx_locations_tenant_id ON public.locations(tenant_id);

CREATE INDEX IF NOT EXISTS idx_products_branch_id ON public.products(branch_id);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_products_group_id ON public.products(group_id);
CREATE INDEX IF NOT EXISTS idx_products_item_group_id ON public.products(item_group_id);
CREATE INDEX IF NOT EXISTS idx_products_parent_id ON public.products(parent_id);
CREATE INDEX IF NOT EXISTS idx_products_tenant_id ON public.products(tenant_id);
CREATE INDEX IF NOT EXISTS idx_products_uom_id ON public.products(uom_id);

CREATE INDEX IF NOT EXISTS idx_profiles_branch_id ON public.profiles(branch_id);

CREATE INDEX IF NOT EXISTS idx_sale_payments_branch_id ON public.sale_payments(branch_id);

CREATE INDEX IF NOT EXISTS idx_sales_approved_by ON public.sales(approved_by);
CREATE INDEX IF NOT EXISTS idx_sales_created_by ON public.sales(created_by);
CREATE INDEX IF NOT EXISTS idx_sales_customer_id ON public.sales(customer_id);

CREATE INDEX IF NOT EXISTS idx_staff_members_branch_id ON public.staff_members(branch_id);
CREATE INDEX IF NOT EXISTS idx_staff_members_tenant_id ON public.staff_members(tenant_id);

CREATE INDEX IF NOT EXISTS idx_stock_product_id ON public.stock(product_id);

CREATE INDEX IF NOT EXISTS idx_stock_adjustments_branch_id ON public.stock_adjustments(branch_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_created_by ON public.stock_adjustments(created_by);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_product_id ON public.stock_adjustments(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_reason_id ON public.stock_adjustments(reason_id);
CREATE INDEX IF NOT EXISTS idx_stock_adjustments_tenant_id ON public.stock_adjustments(tenant_id);

CREATE INDEX IF NOT EXISTS idx_units_of_measurement_base_unit_id
  ON public.units_of_measurement(base_unit_id);
