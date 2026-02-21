-- 1. Add tenant_id column to sale_items
ALTER TABLE sale_items 
ADD COLUMN IF NOT EXISTS tenant_id UUID REFERENCES tenants(id);

-- 2. Backfill existing data
UPDATE sale_items si
SET tenant_id = s.tenant_id
FROM sales s
WHERE si.sale_id = s.id
AND si.tenant_id IS NULL;

-- 3. Create function to auto-set tenant_id on insert
CREATE OR REPLACE FUNCTION set_sale_item_tenant_id()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.tenant_id IS NULL THEN
    SELECT tenant_id INTO NEW.tenant_id
    FROM sales
    WHERE id = NEW.sale_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create trigger
DROP TRIGGER IF EXISTS trigger_set_sale_item_tenant_id ON sale_items;
CREATE TRIGGER trigger_set_sale_item_tenant_id
BEFORE INSERT ON sale_items
FOR EACH ROW
EXECUTE FUNCTION set_sale_item_tenant_id();
