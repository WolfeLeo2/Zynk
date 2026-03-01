-- Add staff_name to sales
ALTER TABLE public.sales
ADD COLUMN salesperson TEXT;
