# Zynk: Codebase Review

> Reviewed: March 2026 | Status: MVP | Framework: Flutter + Riverpod + PowerSync + Supabase

---

## Executive Summary

Zynk is at a solid MVP. The architecture choices (PowerSync offline-first + Supabase + Riverpod) are production-grade and right for a multi-branch SME POS. The core flows (POS sale, invoice lifecycle, branch management) work well. The gap between this and Zoho/Shopify isn't the stack — it's polish, data integrity enforcement, and missing features. Below are the specific issues and the path to fix them.

---

## 1. Application Logic Issues

### 🔴 Critical

#### 1.1 Tax is always zero
```dart
// sales_service.dart
final double taxAmount = 0.0; // TODO: calculate from tax_category
```
`tax_amount` is hardcoded to `0` in both POS sales and draft invoice creation. The `tax_category` field exists on products but is never read. Every sale is effectively tax-free. This is a business-critical bug.

**Fix:** Create a `TaxService` that maps `tax_category` strings to rates (e.g., `'vat_16'` → 16%). Apply at line-item level and roll up.

#### 1.2 Stock validation is client-side only
```dart
// pos_screen.dart — _addToCart()
final stockState = ref.read(stockProvider(product.id)).value;
```
The stock check in `_addToCart` reads local SQLite. This is a **race condition**: two devices on the same branch can both see 1 item in stock and both complete a sale. The `complete-sale` Edge Function should enforce stock checks server-side within the transaction.

#### 1.3 TEMP invoice numbers leak to production
```dart
final tempInvoiceNumber = 'INV-$year-TEMP-${...}';
```
Draft invoices created offline get `INV-2026-TEMP-xxxxx` as their number. If the server edge function doesn't replace this on sync/approval, these show in the customer-facing invoice list.

**Fix:** Never display the invoice number for drafts — show "Draft" until a real sequential number is assigned server-side.

#### 1.4 `uploadData` has no per-operation error recovery
```dart
// powersync.dart
} catch (e) {
  _log.e('Upload Error: $e');
  // transaction not completed — retries the whole batch
}
```
If one operation in a batch fails, all retry. This can cause duplicate calls on previously-applied operations.

#### 1.5 POS cart state lives in widget state — lost on navigation
```dart
// pos_screen.dart
final List<PosCartItem> _cart = [];
```
Navigating away (e.g., to check stock) destroys the cart. This should be a `cartProvider` Notifier so it survives navigation and shows a cart badge.

---

### 🟡 Medium

#### 1.6 `BranchSelectionNotifier.build()` schedules async work via `Future.microtask`
Not fully safe — should be handled by `branchSyncProvider` pattern instead.

#### 1.7 `salesListProvider` hard-caps at 50 results with no pagination
A merchant with 60+ sales sees a silently truncated list. Need cursor-based pagination.

#### 1.8 `loyalty_points` and `credit_limit` are dead schema
Columns exist on `customers` table but no UI or business logic to earn/redeem.

#### 1.9 `fulfillment_status` on sales is never set or read

#### 1.10 Permission checks are client-side only (no RLS enforcement)
`hasPermissionProvider` is UI-only. If Supabase RLS is not configured, API calls can bypass permissions.

---

## 2. UI / UX Issues

### 🔴 Jank & Performance

#### 2.1 `LayoutBuilder` at root of AppShell rebuilds on any state change
The sidebar + all watched providers rebuild whenever any ancestor changes. Extract sidebar into its own `ConsumerStatefulWidget`.

#### 2.2 `CircularProgressIndicator` everywhere — violates your own AGENTS.md
- `sales_list_screen.dart` line 71  
- `settings_screen.dart`  
- `dashboard_layout.dart`

These should all be shimmer skeleton loaders matching the content layout.

#### 2.3 `PhosphorIcon` instances created fresh on every `_buildDestinations` call
Destinations never change for a given role — memoize or use `const`.

#### 2.4 `_SaleCard` uses `Navigator.push` instead of `GoRouter`
```dart
Navigator.push(context, MaterialPageRoute(...)) // line 182
```
Breaks deep linking, Android back-stack, and web URL routing. Use `context.push('/sales/${sale.id}')`.

#### 2.5 Filter chips call `setState` rebuilding the entire screen
The filter state should be held in a provider, so only the `ListView` rebuilds.

### 🟡 Design & Info Overload

#### 2.6 Dashboard shows 8+ metric cards — information overload
Show 3-4 KPIs above the fold. Move charts below or to a dedicated Analytics tab.

#### 2.7 Sidebar hardcodes `'Active'` status — meaningless
Connect to actual PowerSync sync status (`syncStatusProvider`) or remove.

#### 2.8 Design System gallery visible to end users in production nav
Gate behind a dev flag or remove from `_buildDestinations`.

#### 2.9 POS mobile tab UX — users don't know the cart tab has items
Standard pattern: floating cart badge or expand-able bottom sheet (Shopify POS style).

#### 2.10 `product_details_screen` has `Expanded` inside `SingleChildScrollView` — renderflex risk
Switch to `CustomScrollView` + `SliverList`.

---

## 3. Supabase / Backend Review

### 🔴 Critical

#### 3.1 Verify RLS multi-tenant isolation
Every table has `tenant_id` — verify RLS policies exist restricting all rows to the user's `tenant_id`. Without this, Supabase API calls can read other tenants' data.

**Test:** Call `GET /rest/v1/sales` with Tenant A's token — ensure Tenant B's rows are absent.

#### 3.2 No indexes on high-cardinality query columns
Queries like `WHERE branch_id = ? AND created_at >= ?` will full-table-scan at scale.

```sql
CREATE INDEX idx_sales_branch_date ON sales(branch_id, created_at DESC);
CREATE INDEX idx_sales_tenant_status ON sales(tenant_id, status);
CREATE INDEX idx_stock_product ON stock(product_id);
CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
```

#### 3.3 `credit_notes.items` stored as JSON text blob
Should be a `credit_note_items` junction table (like `sale_items`) for queryability and proper PowerSync sync.

### 🟡 Medium

#### 3.4 Supabase Storage RLS on avatars bucket — verify
Ensure users can only write to their own path (`avatars/{user_id}/...`).

#### 3.5 Edge Function responses not typed
All edge function responses are `Map<String, dynamic>`. A field rename will silently break the app. Use typed response DTOs.

#### 3.6 `local_auth` still in `pubspec.yaml` — dead dependency
Biometrics removed but package remains. Remove it to reduce binary size and avoid Play Store permission flags.

### 🟢 What's Working Well

- **PowerSync** offline-first is the right choice for retail with patchy connectivity
- **Edge Functions** for transactional ops (stock decrement, approval) is correct pattern
- **12-table schema** well-normalized for current scope
- **`branchSyncProvider` + `addPostFrameCallback`** pattern is correct for safe stream-to-state propagation
- **Sales lifecycle** (draft → approval → payment → fulfillment) is a proper workflow

---

## 4. Feature Roadmap

### 🔴 High Priority (blocks real customers)
| Feature | Notes |
|---------|-------|
| **Tax engine** | Map `tax_category` → rates; show on receipts |
| **PDF receipts/invoices** | `pdf` + `printing` packages in pubspec — just need wiring |
| **Cart persistence** | Move to Riverpod `Notifier` |
| **Barcode scanning in POS** | `mobile_scanner` in pubspec, not connected |
| **Customer loyalty redemption** | Schema exists, no logic |

### 🟡 Medium Priority (competitive parity)
| Feature | Notes |
|---------|-------|
| Sales reports + CSV export | `csv` package already in pubspec |
| Purchase orders / stock receiving | Supplier → GRN flow |
| Expense tracking | Cost of goods beyond sale `cost_price` |
| Refund flow (POS) | Credit note creation exists, no POS UI |
| Low-stock notifications | Supabase Realtime → push |
| Offline sync indicator | Show PowerSync status in app bar |

### 🟢 Later (polish)
| Feature | Notes |
|---------|-------|
| Multi-currency | KES assumed everywhere |
| Activity audit log | Who did what, when |
| Customer invoice portal | Shareable link |
| M-Pesa / Stripe integration | Online invoice payment |
| Role-based dashboard widgets | Cashier vs Owner views |
| Dark mode toggle | `AppTokens` infrastructure ready |

---

## 5. Do You Need a Separate Server?

**No — not yet.** Supabase Edge Functions handle all server-authority operations. PowerSync handles sync.

Add a dedicated server when:
- Edge Functions hit memory limits (heavy ML, complex reports)
- You need collaborative real-time features beyond Supabase Realtime
- A client requires data sovereignty / self-hosting

**Better near-term infrastructure moves:**
- Postgres function for sequential invoice numbers (replaces TEMP hack)
- `pg_cron` daily aggregation into `daily_sales_summary` for faster dashboard
- Enable `pg_stat_statements` to profile slow queries

---

## Summary Scorecard

| Area | Score | Notes |
|------|-------|-------|
| Architecture | 8/10 | PowerSync + Riverpod is correct |
| Data Model | 6/10 | Well-normalized but credit_notes.items is a blob, missing indexes |
| Business Logic | 5/10 | Tax=0, TEMP invoices, client-side stock check are blockers |
| UI Polish | 5/10 | Spinner overuse, info overload, jank risks |
| Security | 6/10 | Verify RLS on all tables + storage |
| Feature Completeness | 4/10 | PDF, tax, barcode, loyalty all missing |
| **Overall MVP** | **6/10** | Solid foundation, clear path forward |
