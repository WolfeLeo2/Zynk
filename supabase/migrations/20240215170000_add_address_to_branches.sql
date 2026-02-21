-- Migration: Add address column to branches table
-- Timestamp: 20240215170000

ALTER TABLE public.branches
ADD COLUMN address text;

COMMENT ON COLUMN public.branches.address IS 'Physical address or location description of the branch.';
