-- 1. Create expense_categories
CREATE TABLE expense_categories (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Create expenses
CREATE TABLE expenses (
    id UUID PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    branch_id UUID NOT NULL REFERENCES branches(id),
    category_id UUID NOT NULL REFERENCES expense_categories(id),
    staff_member_id UUID REFERENCES staff_members(id),
    amount NUMERIC NOT NULL DEFAULT 0,
    description TEXT,
    payment_method TEXT REFERENCES payment_methods(code),
    expense_date TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Update daily_kpi_snapshots
ALTER TABLE daily_kpi_snapshots ADD COLUMN total_expenses NUMERIC DEFAULT 0;
ALTER TABLE daily_kpi_snapshots ADD COLUMN net_profit NUMERIC DEFAULT 0;

-- 4. Create Trigger for KPI snapshot
CREATE OR REPLACE FUNCTION update_kpi_expenses()
RETURNS TRIGGER AS $$
DECLARE
    v_date DATE;
    v_branch_id UUID;
    v_tenant_id UUID;
    v_total_expenses NUMERIC;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_date := OLD.expense_date::DATE;
        v_branch_id := OLD.branch_id;
        v_tenant_id := OLD.tenant_id;
    ELSE
        v_date := NEW.expense_date::DATE;
        v_branch_id := NEW.branch_id;
        v_tenant_id := NEW.tenant_id;
    END IF;

    -- Calculate total expenses for this branch and date
    SELECT COALESCE(SUM(amount), 0) INTO v_total_expenses 
    FROM expenses 
    WHERE tenant_id = v_tenant_id AND branch_id = v_branch_id AND expense_date::DATE = v_date;

    -- Update or Insert snapshot
    -- Note: gross_sales calculation depends on existing sales data. 
    -- If no snapshot exists, gross_sales is 0.
    INSERT INTO daily_kpi_snapshots (snapshot_date, tenant_id, branch_id, total_expenses, net_profit)
    VALUES (v_date, v_tenant_id, v_branch_id, v_total_expenses, -v_total_expenses)
    ON CONFLICT (snapshot_date, tenant_id, branch_id)
    DO UPDATE SET 
        total_expenses = v_total_expenses,
        net_profit = daily_kpi_snapshots.gross_sales - v_total_expenses;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_kpi_expenses
AFTER INSERT OR UPDATE OR DELETE ON expenses
FOR EACH ROW EXECUTE FUNCTION update_kpi_expenses();
