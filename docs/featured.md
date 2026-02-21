# Zynk Feature Specifications

## Core Features (MVP)

### 1. The Invoice & Receipt Engine
A "Local-First" invoicing system that ensures tax compliance and seamless digital delivery.
*   **Pro-Forma Invoices:** Generate professional quotes for clients (e.g., construction materials). These do not affect inventory until converted to a Tax Invoice upon payment.
*   **Automated Digital Receipts:**
    *   **Trigger:** M-Pesa Callback Success or Cash Payment confirmation.
    *   **Action:** Generate a branded PDF receipt.
    *   **Delivery:** Auto-send via WhatsApp (using cloud API) or Email.
*   **Thermal Printing:** Support for 80mm ESC/POS Bluetooth/USB printers for high-volume counter environments.
*   **Multi-Currency Logic:** Primary logic in KES. Secondary support for USD invoices, with fixed or live exchange rates for reporting.

### 2. Inventory & Multi-Branch Logic
A "Double-Entry" inventory system preventing stock leakage.
*   **No Teleportation:** Stock cannot simply "change" location. It must move via a transaction:
    *   `Source: Warehouse` -> `Destination: Shop A` (Transfer In-Transit)
*   **Stock Aging Alerts:** Automated flagging of items that have not moved in X days (Dead Stock), prompting discount offers.
*   **Handshake Transfers:**
    *   **Dispatch:** Branch A Manager scans items out. Status: "In-Transit".
    *   **Receive:** Branch B Manager scans items in. Status: "Available".
    *   *Conflict:* If Branch B receives fewer items, a "Variance Ticket" is auto-created.

### 3. Partner & Supplier Management
*   **Credit Ledgers:** Track "Accounts Payable" for suppliers.
*   **Batch Tracking:** Mandatory for specific item groups (e.g., Paint, Medicine) to track Expiry Dates and Batch Numbers.

---

## "Game-Changer" Features (Advanced)

### 1. Lipa Pole Pole (Layby) Engine
A complete system for managing installment-based payments, popular in the Kenyan furniture and electronics sectors.

*   **Workflow:**
    1.  **Initiation:** Customer selects an item (e.g., Sofa set - KES 50,000).
    2.  **Deposit:** Customer pays initial deposit (e.g., KES 10,000).
    3.  **Reservation:** System creates a "Soft Hold" on the stock. It is removed from "Available for Sale" but not "Sold" (Asset remains on books).
    4.  **Installments:** Customer makes partial payments via M-Pesa. System auto-updates the "Amount Remaining".
    5.  **reminders:** Automated SMS/WhatsApp nudges sent 3 days before agreed payment dates.
    6.  **Completion:** Upon 100% payment, stock is marked "Sold", Tax Invoice is generated, and collection is authorized.
*   **Forfeiture Logic:** Configuration for "Refund minus Cancellation Fee" if customer defaults.

### 2. Wholesale / Retail Dual Pricing
Smart pricing logic that adapts to the customer type and quantity purchased.

*   **Customer Groups:**
    *   **Walk-in:** Standard Retail Price.
    *   **Reseller/Fundi:** Wholesale Price (requires account approval).
*   **Automatic Price Switching:**
    *   *Scenario A (Identity):* If Customer is tagged as "Reseller", system applies Price List B automatically.
    *   *Scenario B (Bulk Breaker):*
        *   Product: "Soda Crate" (Parent) vs "Review Soda" (Child).
        *   Logic: If 24 "Review Sodas" are added to cart, system auto-swaps them for 1 "Soda Crate" at the cheaper wholesale rate.
*   **Profit Margins:** Analytics dashboard must show blended margins across both channels.

### 3. WooCommerce / Shopify Sync
Real-time bi-directional synchronization to enable "Click & Collect" and prevent overselling.

*   **Inventory Sync (Upstream):**
    *   When a physical sale occurs in-store (Drift DB), the new stock level is pushed to Supabase.
    *   Supabase Webhooks trigger an Edge Function to update the WooCommerce API / Shopify Admin API.
    *   *Latency:* Target < 30 seconds.
*   **Order Sync (Downstream):**
    *   Web Order placed -> Webhook to Supabase -> Insert into `sales` table with `status: 'Pending_Fulfillment'`.
    *   **Shop Dashboard:** Order appears with a unique "Web Order" badge.
    *   **Action:** Shop staff "Picks & Packs", then marks "Ready for Collection".
*   **Conflict Resolution:**
    *   If Online Order and Physical Sale happen simultaneously for the last item:
    *   **Rule:** Physical Sale wins (money in hand). Web Order is auto-flagged "Out of Stock" and Customer Support alert is generated.
