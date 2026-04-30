# Implementation Plan - Utawala Branch Product Data Import

Import product data from `utawala 1.csv` for the "Prestine Homes" tenant, linking stock to the "Utawala" branch while avoiding duplicate global entities (Item Groups and Products).

## User Review Required

> [!IMPORTANT]
> This import assumes that products with the same name are identical across branches. If a product with the same name exists, we will reuse the existing `product_id` and only create a new `stock` record for the Utawala branch.

## Proposed Changes

### Data Migration

#### [NEW] `parse_utawala.py`
A Python script to:
1. Parse `utawala 1.csv`.
2. Map existing `item_groups` and `products` by name for the tenant.
3. Identify new `item_groups` or `products` that need to be created.
4. Generate a SQL script `seed_utawala.sql` containing:
    - `INSERT` statements for new `item_groups`.
    - `INSERT` statements for new `products`.
    - `INSERT` statements for `stock` (Utawala branch) for all products in the CSV.

### Database IDs
- **Tenant ID**: `870a2a76-4a11-4b6f-a537-ee71d4f82037` ("Prestine Homes")
- **Branch ID**: `9ec5fc08-91ed-45d5-9fdf-03c70b88e7a9` ("Utawala")

## Verification Plan

### Automated Tests
- Execute count queries after migration to verify:
    - Total number of `products` for the tenant.
    - Total number of `stock` records for the Utawala branch.
    - Verification that existing products now have stock in both Kitengela and Utawala branches.

### Manual Verification
- Verify a few random products from the CSV are correctly linked to the Utawala branch with the correct stock quantity.
