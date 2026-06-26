# Expenses Feature Design

## 1. Overview
The Expenses Feature allows SME businesses using Zynk to log their operational costs. This is critical for moving beyond gross sales tracking to calculating true Net Profit. The feature uses a "Trust but Verify" approach, meaning any authorized staff member can log an expense immediately (no heavy approval gating), with the action tied to their profile, tenant, and branch for full accountability.

## 2. Database Schema
Two new tables will be added, and an existing table will be modified via Supabase migrations.

### `expense_categories` Table
Allows tenants to define their own custom categories (e.g., Rent, Utilities, Payroll).
- `id` (UUID, PK)
- `tenant_id` (UUID, FK)
- `name` (Text)
- `created_at` (Timestamptz)
- `updated_at` (Timestamptz)

### `expenses` Table
Stores the actual logged expenses.
- `id` (UUID, PK)
- `tenant_id` (UUID, FK)
- `branch_id` (UUID, FK)
- `category_id` (UUID, FK)
- `staff_member_id` (UUID, FK) - links to the user logging the expense
- `amount` (Numeric)
- `description` (Text)
- `payment_method` (Text)
- `expense_date` (Timestamptz)
- `created_at` (Timestamptz)
- `updated_at` (Timestamptz)

### `daily_kpi_snapshots` Modifications
- Add `total_expenses` (Numeric, default 0)
- Add `net_profit` (Numeric, default 0)
- **Trigger**: A PostgreSQL trigger will recalculate `total_expenses` for the given date/branch and update `net_profit` (`gross_sales - total_expenses`) whenever an expense is inserted, updated, or deleted.

## 3. App Architecture

### Sync Configuration (PowerSync)
- `expense_categories` will sync globally per `tenant_id`.
- `expenses` will sync scoped to `tenant_id` and `branch_id`.

### Data Layer
- **Models**: `Expense` and `ExpenseCategory` using `freezed` and `json_serializable`.
- **Repository**: `ExpensesRepository` for local PowerSync database operations.

### State Management (Riverpod)
- `expenseCategoriesProvider`: `StreamProvider` for categories.
- `expensesListProvider`: `StreamProvider` for viewing expenses filtered by date/month.
- `ExpenseActionService`: Service logic to handle expense creation/deletion.
- **Dashboard Updates**: Update existing dashboard providers to query and expose the new `net_profit` and `total_expenses` metrics.

## 4. UI & UX Design

### Dashboard Enhancements
- Include **Net Profit** prominently next to Gross Sales.
- Add a metric card for **Total Expenses**.

### Expenses Management
- **Entry Point**: A new item in the App Drawer (`AppDrawer`).
- **`ExpensesScreen`**: A main list screen with a `MonthPill` for filtering, showing expense details (amount, category, description, staff member, date). Includes shimmer loading states and empty state graphics.
- **`LogExpenseSheet`**: A bottom sheet for quick data entry (Amount, Category dropdown, Payment Method dropdown, Description, Date picker defaulting to today).

### Configuration
- **`ExpenseCategoriesScreen`**: Accessible from Settings (for Owners/Managers) to add, edit, or delete custom categories.
