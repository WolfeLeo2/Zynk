# Zoho SME Features — What Zynk Can Learn

## Overview

Beyond sales/invoicing, Zoho provides a suite of interconnected modules for SME management. This document identifies the features Zynk should consider adopting for a competitive offering in the East African SME market.

---

## 1. Expense Tracking

### What Zoho Does
- Categorize expenses (rent, supplies, utilities, employee per diems)
- Import expenses from bank/credit card statements
- Bill expenses to specific customers
- Mileage tracking for field staff
- Receipt scanning via mobile (OCR → auto-categorization)
- Multi-level approval workflows for expense reports
- Recurring expense templates

### What Zynk Should Do
| Feature | Priority | Rationale |
|---------|----------|-----------|
| Manual expense entry | P1 | Essential for profit/loss tracking |
| Expense categories | P1 | Reporting accuracy |
| Bill to customer | P2 | Service businesses need this |
| Receipt photo capture | P2 | Mobile-first advantage |
| Recurring expenses | P2 | Rent, subscriptions, etc. |
| Bank import | P3 | M-Pesa statement integration |

---

## 2. Purchase Orders & Vendor Management

### What Zoho Does
- Create and send purchase orders to suppliers
- Track PO status (Draft → Issued → Received)
- Auto-convert PO to Bill when goods arrive
- Vendor portal: vendors upload invoices, check payment status, accept/reject POs
- Multi-currency support for international suppliers
- Vendor credit management

### What Zynk Should Do
| Feature | Priority | Rationale |
|---------|----------|-----------|
| Create purchase orders | P1 | Stock replenishment workflow |
| Track PO status | P1 | Know what's ordered vs. received |
| Auto-update stock on receive | P1 | Closes the inventory loop |
| Supplier directory | P2 | Contact info, lead times |
| PO → Bill conversion | P2 | Accounts payable tracking |
| Vendor portal | P3 | Nice-to-have for larger businesses |

---

## 3. Inventory Management (Beyond Basic Stock)

### What Zoho Does
- **Composite items**: Bundle products (e.g., "Gift Set" = Mug + Tea + Card)
- **Serial/batch tracking**: Track individual units by serial number
- **Reorder points**: Auto-alert when stock falls below threshold
- **Stock adjustments**: Manual corrections with reason codes
- **Warehouse transfers**: Move stock between locations/branches
- **Landed cost**: Factor in shipping, customs, handling into product cost
- **Aging inventory**: Report on items sitting too long

### What Zynk Should Do
| Feature | Priority | Rationale |
|---------|----------|-----------|
| Low stock alerts | P1 | Already placeholder in dashboard |
| Stock adjustments | P1 | Shrinkage, breakage, counting errors |
| Reorder points per product | P1 | Prevent stockouts |
| Branch-to-branch transfers | P2 | Multi-location businesses |
| Composite/bundle items | P2 | Common in retail (meal deals, gift sets) |
| Serial tracking | P3 | Electronics, high-value items |
| Aging inventory | P3 | Reduce dead stock |

---

## 4. Customer Management (CRM-lite)

### What Zoho Does
- Customer profiles with purchase history
- Customer groups/segments
- Loyalty points and rewards
- Credit limits per customer
- Customer statements (account summary)
- Customer portal for self-service

### What Zynk Should Do
| Feature | Priority | Rationale |
|---------|----------|-----------|
| Customer profiles linked to sales | P1 | Already have `customers` table |
| Purchase history per customer | P1 | "This customer usually buys X" |
| Customer balance/credit | P2 | "Buy now, pay later" common in EA |
| Loyalty program | P3 | Retention tool |
| Customer groups | P3 | Wholesale vs retail pricing |

---

## 5. Reporting & Analytics

### What Zoho Does
- Profit & Loss statement
- Balance Sheet
- Cash Flow statement
- Sales by item/customer/salesperson
- Tax summary reports
- Inventory valuation report
- Accounts Receivable/Payable aging
- Custom report builder

### What Zynk Should Do
| Feature | Priority | Rationale |
|---------|----------|-----------|
| Sales summary (daily/weekly/monthly) | P1 | Currently mock data |
| Top products report | P1 | Currently placeholder |
| Staff performance (sales by employee) | P2 | Accountability |
| Profit & Loss | P2 | Business health overview |
| Inventory valuation | P2 | "How much is my stock worth?" |
| Payment method breakdown | P2 | M-Pesa vs Cash insights |
| Tax report | P2 | KRA compliance (VAT returns) |
| Custom date ranges | P1 | Currently time selector does nothing |

---

## 6. Multi-Branch Management

### What Zoho Does
- Per-branch inventory tracking
- Branch-level P&L reporting
- Inter-branch stock transfers
- Branch-specific pricing
- Centralized vs decentralized purchasing

### What Zynk Should Do
| Feature | Priority | Rationale |
|---------|----------|-----------|
| Per-branch stock levels | P1 | Already have `branches` + `stock` tables |
| Branch-level sales reports | P1 | "Which branch is performing?" |
| Stock transfer requests | P2 | "Branch A needs item X from Branch B" |
| Branch-specific pricing | P3 | Different markets, different prices |

---

## 7. Tax & Compliance (Kenya-Specific)

### What Zoho Does
- Tax rate management
- Automatic tax calculation on invoices
- Tax exemption for specific customers
- Tax reports for filing

### What Zynk Should Do
| Feature | Priority | Rationale |
|---------|----------|-----------|
| VAT (16%) configuration | P1 | Kenyan standard rate |
| Zero-rated items support | P2 | Some goods are VAT-exempt |
| KRA ETR integration | P1 | Electronic Tax Register is legally required for invoicing in Kenya |
| Pin number on invoices | P1 | Legal requirement |

---

## 8. Feature Comparison: Zynk vs Competition

| Feature | Zoho | Square | Shopify POS | Lightspeed | **Zynk (Target)** |
|---------|------|--------|------------|------------|-------------------|
| Invoice states | ✅ Full | ❌ Basic | ❌ Basic | ✅ Full | ✅ Full |
| Custom roles | ✅ | ⚠️ Limited | ⚠️ Limited | ✅ | ✅ Planned |
| M-Pesa integration | ❌ | ❌ | ❌ | ❌ | ✅ **Differentiator** |
| Offline-first POS | ❌ | ⚠️ Limited | ⚠️ Limited | ⚠️ Limited | ✅ PowerSync |
| Multi-branch | ✅ | ✅ | ✅ | ✅ | ✅ |
| Purchase orders | ✅ | ❌ | ✅ | ✅ | ✅ Planned |
| Expense tracking | ✅ | ❌ | ❌ | ⚠️ | ✅ Planned |
| KRA ETR | ❌ | ❌ | ❌ | ❌ | ✅ **Differentiator** |
| Returns/Credit notes | ✅ | ✅ | ✅ | ✅ | ✅ Planned |
| Customer credit | ✅ | ❌ | ❌ | ✅ | ✅ Planned |
