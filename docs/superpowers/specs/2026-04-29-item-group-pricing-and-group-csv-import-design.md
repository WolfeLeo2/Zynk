# Item Group Pricing + Group CSV Import Design

**Date:** 2026-04-29

## Summary
Add tenant-wide item group defaults for selling/buying price and fixed commission, allow per-item price overrides (null = inherit), and extend CSV import to support a group-based format that auto-creates item groups and maps items to them. Remove commission type across the app.

## Goals
- Support item groups with default selling price, buying price, and fixed commission.
- Items inherit group prices by default and only store overrides when explicitly set.
- Import group-based CSVs that auto-create groups and map items correctly.
- Remove commission type everywhere so commissions are fixed amounts.

## Non-Goals
- No UI redesign beyond adding required fields/toggles.
- No backfill/cleanup of historical data (no production data exists).

## Data Model Changes
### Supabase (public schema)
- `item_groups`:
  - Add `default_selling_price` (numeric, nullable)
  - Add `default_buying_price` (numeric, nullable)
  - Remove `default_commission_type`
- `products`:
  - Remove `commission_type`
  - Set `base_price` default to NULL (no forced 0.00)
  - Keep `commission_value` (fixed amount), nullable
- `commissions`:
  - No schema change (already fixed-amount `amount` only)

### Local/PowerSync Schema
- `item_groups` table adds `default_selling_price` and `default_buying_price`.
- `item_groups` removes `default_commission_type`.
- `products.base_price` becomes nullable in models and UI.

## Pricing and Commission Rules
- **Effective Selling Price** = product `base_price` if non-null, else group `default_selling_price`.
- **Effective Buying Price** = product `cost_price` if non-null, else group `default_buying_price`.
- **Commission** is a fixed amount. Group default stored in `item_groups.default_commission_value`.
- If an item has no group, it must have explicit prices (no inheritance).

## CSV Import (Group Format)
### Format Detection
- Detect format by headers:
  - Current format: `name, category, selling_price, initial_stock`.
  - Group format: `name, item group, stock, group selling price, group buying price, group commission`.

### Group CSV Handling
- For each unique group name:
  - Create tenant-wide item group if missing (`branch_id = null`).
  - Set group defaults using group selling/buying price and group commission.
  - If the group already exists, keep existing defaults (do not overwrite).
- Create products with:
  - `item_group_id` set.
  - `base_price` / `cost_price` **null** (inherit).
  - `category_id` **null** if category is not present in CSV.
- Optional override columns (if present): `selling_price`, `cost_price` map to product overrides.
- Stock import uses existing branch fan-out logic (All Branches vs single branch) and coerces decimal stock values to integers via `floor`.

## UI Changes
### Item Group Create/Edit
- Add fields:
  - Default Selling Price
  - Default Buying Price
  - Commission (fixed amount)
- Remove commission type selector.

### Add/Edit Product
- When a group is selected:
  - Show inherited prices (read-only) with a toggle to override.
  - If override is enabled, allow editing `Selling Price` and `Buying Price`.
- If no group is selected:
  - Require explicit prices.

### Batch Upload Screen
- Update help text to mention group CSV format and auto-creation of groups.

## Migration Notes
- Use Supabase MCP `apply_migration` (no CLI) to alter schema.
- No backfill required (no production data).

## Testing
- Unit tests for CSV format detection and parsing.
- Unit tests for inheritance logic (null price -> group default).
- UI sanity checks for group create/edit and product override toggle.

## Open Questions
- None.
