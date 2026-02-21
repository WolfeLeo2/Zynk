# Zynk Features & Roadmap

## Core Features (From PRD)

### 1. The Invoice & Receipt Engine
- **Pro-Forma Invoices:** Create professional quotes/estimates that convert to tax invoices upon payment.
- **Multi-Currency Support:** Base KES, with USD support via PayPal/GlobalPay.
- **Automated Digital Receipts:** Instant PDF generation sent via WhatsApp/Email upon M-Pesa callback.
- **Thermal Print Support:** 80mm ESC/POS printing for physical counters.
- **Tax Compliance:** 16% VAT calculation and separate line items.

### 2. Inventory & Multi-Branch Logic
- **"Double-Entry" Inventory:** No teleportation. Every move has a Source and Destination.
- **Stock Aging Alerts:** "Dead Stock" warnings for items sitting too long.
- **Handshake Transfers:** Dispatch limits stock at Branch A; Receive increments stock at Branch B.
- **Multi-Branch Dashboard:** valid real-time view of stock across all locations.

### 3. Partner & Supplier Management
- **Credit Ledgers:** Track "Supplied on Credit" vs "Paid" status.
- **Batch/Lot Tracking:** For construction (paint batches) and fashion (dye lots).

## "Game-Changer" Features (Proposed)

### 1. Financial & Sales
- **"Lipa Pole Pole" (Layby) Engine:**
    - allow customers to pay in installments.
    - Reserves stock (soft hold) or tracks deposits until fully paid.
    - Automated SMS reminders for next payment.
- **Wholesale/Retail Dual Pricing:**
    - Automatically switch prices based on Customer Group (e.g., "Walk-in" vs "Reseller").
    - "Bulk Breaker" logic: Buy a Carton (Wholesale), sell individual packets (Retail) automatically managing stock units.

### 2. Advanced Integrations
- **Shopify/WooCommerce Sync:**
    - Real-time inventory sync. If a physical shop sells the last item, the website marks it "Out of Stock" instantly.
- **WhatsApp for Business Bot:**
    - Customers can check their own Loyalty Points.
    - Re-order previous items ("Send me the usual").

### 3. Intelligent Operations
- **AI Stock Predictions:**
    - "You usually run out of Milk on Fridays. Order 20 crates now to avoid stockouts."
- **Supplier VMI Portal:**
    - Give suppliers a limited link to see *only* their products' stock levels in your shop, allowing them to proactively restock you.

### 4. Technical Advantages
- **Offline-First via Drift:** Continue selling even when ISP is down. Sync happens invisibly when back online.
- **Real-time Collaboration:** Multiple shop assistants see the same cart updates instantly (using Supabase Realtime).
