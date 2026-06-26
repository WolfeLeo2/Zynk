-- ==============================================================================
-- Migration: Multi-Branch & Commissions Support
-- ==============================================================================

-- 1. Create commissions table
CREATE TABLE IF NOT EXISTS public.commissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    salesperson_id UUID NOT NULL,
    sale_id UUID NOT NULL REFERENCES public.sales(id) ON DELETE CASCADE,
    amount DECIMAL NOT NULL,
    status VARCHAR DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS and add basic policies
ALTER TABLE public.commissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for authenticated users" ON public.commissions FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Enable insert for authenticated users" ON public.commissions FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable update for authenticated users" ON public.commissions FOR UPDATE USING (auth.role() = 'authenticated');

-- 2. Create Database Trigger for Auto-calculating Commissions on new Sale Items
CREATE OR REPLACE FUNCTION calculate_commission_on_sale()
RETURNS TRIGGER AS $$
DECLARE
    v_item_group_id UUID;
    v_salesperson_id UUID;
    v_commission_type VARCHAR;
    v_commission_value DECIMAL;
    v_calculated_amount DECIMAL := 0;
    v_tenant_id UUID;
BEGIN
    -- Only process if sale item is being inserted
    
    -- 1. Find the item_group_id for the inserted item
    SELECT item_group_id, tenant_id INTO v_item_group_id, v_tenant_id
    FROM public.products
    WHERE id = NEW.product_id;

    -- 2. Get the salesperson_id from the sale
    SELECT salesperson_id INTO v_salesperson_id
    FROM public.sales
    WHERE id = NEW.sale_id;
    
    -- In Zynk, salesperson is saved as TEXT (the staff ID), so if your staff ID is a UUID, we can cast it.
    -- Assuming salesperson is storing the staff ID string.
    
    -- 3. Get the default commission type & value from item_group
    IF v_item_group_id IS NOT NULL THEN
        SELECT default_commission_type, default_commission_value 
        INTO v_commission_type, v_commission_value
        FROM public.item_groups
        WHERE id = v_item_group_id;

        -- 4. Calculate commission
        IF v_commission_type IS NOT NULL AND v_commission_value IS NOT NULL AND v_salesperson_id IS NOT NULL THEN
            IF v_commission_type = 'fixed' THEN
                v_calculated_amount := v_commission_value * NEW.quantity;
            ELSIF v_commission_type = 'percentage' THEN
                v_calculated_amount := (NEW.total * v_commission_value) / 100.0;
            END IF;

            IF v_calculated_amount > 0 THEN
                -- Insert into commissions table
                INSERT INTO public.commissions (tenant_id, salesperson_id, sale_id, amount, status)
                VALUES (v_tenant_id, v_salesperson_id::UUID, NEW.sale_id, v_calculated_amount, 'pending');
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_calculate_commission_on_sale ON public.sale_items;
CREATE TRIGGER trg_calculate_commission_on_sale
AFTER INSERT ON public.sale_items
FOR EACH ROW
EXECUTE FUNCTION calculate_commission_on_sale();

-- 3. Add status to stock_adjustments
ALTER TABLE public.stock_adjustments ADD COLUMN status VARCHAR DEFAULT 'approved';

-- 4. Create profile_branches junction table
CREATE TABLE IF NOT EXISTS public.profile_branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL,
    profile_id UUID NOT NULL,
    branch_id UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(profile_id, branch_id)
);

ALTER TABLE public.profile_branches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Enable read for authenticated users" ON public.profile_branches FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Enable insert for authenticated users" ON public.profile_branches FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Enable update for authenticated users" ON public.profile_branches FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Enable delete for authenticated users" ON public.profile_branches FOR DELETE USING (auth.role() = 'authenticated');
