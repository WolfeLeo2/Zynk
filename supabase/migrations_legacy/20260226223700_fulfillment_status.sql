ALTER TABLE public.sales ADD COLUMN fulfillment_status TEXT DEFAULT 'unfulfilled';
ALTER TABLE public.credit_notes ADD COLUMN restock_items BOOLEAN DEFAULT false;
