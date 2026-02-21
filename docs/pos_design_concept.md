# Zynk POS & Dashboard Design Concept

## 1. Design Philosophy: "Playful Precision"
*   **Vibe:** Professional utility meets joyful interaction.
*   **Core Metaphor:** The "Digital Countertop". Clean, organized, but with tactile, satisfying interactions (buttons that feel like physical keys, satisfying sounds/haptics).

## 2. Dashboard Shell
The "Command Center". Adaptive based on User Role.

### Header Design
*   **Layout:**
    *   **Left:** Greeting ("Good Morning, [Display Name]") + Avatar.
    *   **Right:** **Branch Selector** (Dropdown).
*   **Behavior:**
    *   Changing the Branch in the dropdown sets the Global App Scope (`currentBranchProvider`).
    *   All data (Inventory, Sales, Staff) instantly reloads to reflect the selected branch.
    *   *Constraint:* Staff with single-branch access see a read-only badge instead of a dropdown.

### Role-Based Access & UI
The UI adapts dynamically to the user's `role` (Owner, Manager, Cashier).

#### 1. Owner (God Mode)
*   **Landing:** Global Dashboard (Aggregated stats across all branches).
*   **Nav:** Full Access (Home, Inventory, Customers, Staff, Reports, Settings).
*   **Unique Actions:** Create Branch, Edit Tenant Settings, View All Ledgers.

#### 2. Manager (Branch Admin)
*   **Landing:** Branch Dashboard (Stats for *their* branch only).
*   **Nav:** Restricted (Home, Inventory, Customers, Local Reports).
*   **Restrictions:** Cannot delete business, cannot see other branches' data unless explicitly granted.
*   **Focus:** operational efficiency—stock levels, cash reconciliation.

#### 3. Cashier (Speed Mode)
*   **Landing:** Direct to **POS Screen** (or a simplified "My Shift" view).
*   **Nav:** Minimal (POS, Transactions, Customers).
*   **Restrictions:**
    *   No access to "Inventory" (except lookup).
    *   No access to "Reports" or "Settings".
    *   Cannot edit product prices (unless authorized via Admin PIN override).

### Layout
*   **Responsive Hybrid Navigation:**
    *   **Desktop/Tablet:** `NavigationRail` (Left). Fixed, glassmorphic background (`bg.surface` with blur).
    *   **Mobile:** `NavigationBar` (Bottom). Floating pill or high-contrast bar.
*   **Header:**
    *   Dynamic Greeting: "Good Morning, [Store Name]".
    *   Global Search: "Search items, customers, or receipts..." (Linear-style command palette later).
    *   Quick Actions: "New Sale" (Primary FAB), "Add Stock".

### Key Screens
1.  **Home (Dashboard):**
    *   **"Pulse" Cards:** Live sales today, Low stock alerts (red/pink accent).
    *   **Recent Activity:** Stream of receipts and inventory moves.
2.  **Inventory (Items):**
    *   **Grid/List Toggle:** Visual grid for discovery, dense list for audits.
    *   **Stock Pills:** Color-coded chips (Green = Good, Orange = Low, Red = Out).

## 3. Point of Sale (POS) UI
The logical heart of the app. Optimized for speed (TAP TAP CHARGE).

### Structure
*   **Split View (Tablet/Desktop):**
    *   **Left (60%):** Product Catalog.
    *   **Right (40%):** The "Ticket" (Current Cart).
*   **Stack View (Mobile):**
    *   **Main:** Product Catalog.
    *   **Floating Bar:** "Charge [Amount]" summary.
    *   **Bottom Sheet:** Full Ticket details when tapped.

### Components
1.  **Product Card:**
    *   **Visual:** Rounded rect (`r=16`), subtle depth.
    *   **Content:** Image/Icon + Name + Price (Bold).
    *   **Micro-interaction:** On tap, card scales down (`0.95`). item "flies" to cart.
2.  **The Ticket (Cart):**
    *   **List Items:** Swipeable rows (Delete/Edit).
    *   **Keypad:** Integrated numeric pad for custom amounts/discounts.
3.  **Charge Button:**
    *   **Visual:** The "Hero" element. Full width or large circle.
    *   **Color:** `AppTokens.brandSecondary` (Neon Lime).
    *   **Animation:** Deep press effect. Particle explosion on success?

## 4. Inspiration
*   **Square:** For the clean, minimal grid of items.
*   **Toast:** For the robust "Table/Ticket" management (simplified for retail).
*   **Zenly:** For the bounce and "squish" of the interaction model.

## 5. Experimentation Plan (Gallery)
We will add a "POS Sandbox" tab to the `DesignSystemGalleryPage` to build and test:
*   `PosProductCard`
*   `PosTicketRow`
*   `PosChargeButton`
