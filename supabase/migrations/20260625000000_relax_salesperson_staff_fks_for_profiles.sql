-- Salesperson/staff now reference profiles (login accounts) going forward.
-- staff_members is retained for historic rows, but these columns must be able to
-- hold profile ids, so drop the FKs to staff_members. Columns + data unchanged.
ALTER TABLE public.stock_adjustments DROP CONSTRAINT IF EXISTS stock_adjustments_salesperson_id_fkey;
ALTER TABLE public.expenses DROP CONSTRAINT IF EXISTS expenses_staff_member_id_fkey;

COMMENT ON COLUMN public.stock_adjustments.salesperson_id IS 'Salesperson. New rows: profiles.id (logged-in staffer). Historic rows: staff_members.id. No FK (resolve name from either table).';
COMMENT ON COLUMN public.expenses.staff_member_id IS 'Recorded-by staffer. New rows: profiles.id. Historic rows: staff_members.id. No FK.';
