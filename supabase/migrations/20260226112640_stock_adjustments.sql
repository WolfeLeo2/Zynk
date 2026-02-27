-- Migration: Add stock_adjustments table for inventory audit trail

-- Create stock_adjustments table
CREATE TABLE IF NOT EXISTS public.stock_adjustments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    branch_id UUID NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
    adjustment_type TEXT NOT NULL CHECK (adjustment_type IN ('addition', 'reduction', 'initial', 'damage')),
    quantity INTEGER NOT NULL,
    reference_number TEXT,
    notes TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.stock_adjustments ENABLE ROW LEVEL SECURITY;

-- Create Policies
CREATE POLICY "Users can view stock adjustments in their tenant" ON public.stock_adjustments
    FOR SELECT USING (
        tenant_id = (SELECT tenant_id FROM public.profiles WHERE user_id = auth.uid())
    );

CREATE POLICY "Users can create stock adjustments in their tenant" ON public.stock_adjustments
    FOR INSERT WITH CHECK (
        tenant_id = (SELECT tenant_id FROM public.profiles WHERE user_id = auth.uid())
    );

-- Create publication for PowerSync
ALTER PUBLICATION powersync ADD TABLE public.stock_adjustments;
