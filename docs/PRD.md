I. Background & Problem Statement
Context: Based on experience with Kenyan retail (e.g., Neoman Styles, Golfmart), SMEs operate in a high-trust but high-risk environment.

The Problem: Current tools are either too "Western" (lacking M-Pesa/local tax logic) or too manual. Owners of multi-branch shops (Interior Design, Hardware, Fashion) lose up to 15% of revenue to "leakage" (untracked stock) and manual reconciliation errors between M-Pesa and Paper receipts.

The Solution: A "local-first" SaaS that automates the link between a physical sale, a digital payment (M-Pesa/Visa), and a legally binding PDF invoice.

II. Core Functional Modules
1. The Invoice & Receipt Engine (P0)
Pro-Forma Invoices: Allow creation of quotes for construction projects that can be converted to tax invoices upon payment.

Multi-Currency Support: KES as base, but support for USD/other currencies via PayPal and M-Pesa GlobalPay (Visa).

Automated Receipting: Upon M-Pesa callback success, the system must instantly generate a PDF receipt and send it to the customer via WhatsApp/Email.

Thermal Print Support: UI must support 80mm ESC/POS printing for physical shop counters.

2. Inventory & Multi-Branch Logic (P0)
Stock Aging: Track how long items have been in the warehouse to trigger "Dead Stock" alerts.

The Handshake Transfer: (As defined previously) Stock is never "teleported"—it must be Dispatched and Received.

3. Partner & Supplier Management (P1)
Credit Ledgers: Track "Supplied on Credit" vs "Paid" status for each supplier.

Batch Tracking: Necessary for construction (e.g., paint batches) or fashion (e.g., fabric rolls).

4. User Management & Authentication (P0)
**Self-Service Onboarding:** New Shop Owners can "Sign Up" via Email/Password to create a **new, empty Tenant (Shop)**.
*   *Clarification:* Any user can sign up and become an *Owner* of their own *new* shop. This does NOT give them access to other existing shops.

**Staff Onboarding (Secure Mode):**
*   Staff **cannot** sign up publicly to join an existing shop.
*   Owners/Managers must **Invite** staff via email.
*   Staff receive an email, set their own password, and are linked specifically to that Shop's Tenant ID with a restricted role.

**Role-Based Access:**
*   **Owner:** Full access. Can invite staff.
*   **Manager:** Can manage stock and view reports, but cannot delete the shop.
*   **Cashier:** Can only sell (POS) and view stock. Restricted from "Costs" and "Profit" views.
**Web-Based Management:** Setup and heavy admin tasks (importing stock) are easier on the Web; POS is for the Mobile/Tablet.

III. User Flows (The "Standard Operating Procedures")
Flow: The Multi-Step Invoicing Process

Draft: Shopkeeper adds items to a cart.

Checkout: System prompts for "Payment Method" (M-Pesa, Cash, Card, or Credit).

Verification: If M-Pesa, trigger STK Push. If Credit, check against the customer's "Credit Limit."

Finalization: On payment confirmation, the "Stock Level" is decremented, the "Sales Journal" is updated, and the "Digital Receipt" is generated.

2. Architecture Artifact
File Name: ARCHITECTURE.md

I. The "Double-Entry" Inventory System
To prevent errors, every stock movement must have a "Source" and a "Destination."

Sale: Source: Branch Shelf -> Destination: Customer.

Restock: Source: Supplier -> Destination: Branch Shelf.

Transfer: Source: Branch A -> Destination: In-Transit -> Destination: Branch B.

II. Local-First Reactivity (Flutter + Drift)
Reactive UI: Use Stream or Watch in Drift. When a sale is made, the stock count on the dashboard must update without a page refresh.

Conflict Resolution: If two shopkeepers sell the last item at the exact same time offline, the system must flag a "Stock Conflict" once they sync.