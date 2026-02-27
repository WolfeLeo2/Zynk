# Skill: Financial Integrity & Invoicing
**Goal:** Ensure invoices are professional, legally compliant, and accurately calculated.

**Instructions:**
1. **Tax Logic:** Always calculate VAT (16%) and show it as a separate line item.
2. **Branding:** Use the `Design_System_Skill` to ensure invoices include the Shop Logo (Neoman/Golfmart) and Branch Address.
3. **M-Pesa Matching:** Ensure the M-Pesa "Transaction Code" (e.g., RCK21...) is saved in a unique, searchable field on the receipt.
4. **Validation:** Prevent "Negative Stock" sales unless the "Allow Over-sell" flag is enabled for that specific tenant.
5. **Currency Consistency:** Never mix currencies (e.g. KES and USD) in calculations without explicit conversion.
6. **Rounding:** All final monetary values must be rounded to the nearest valid currency unit (e.g. 2 decimal places).