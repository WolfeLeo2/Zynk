# Skill: Multi-Tenant Security Guard
**Goal:** Prevent data leaks between Shop A and Shop B.

**Instructions:**
1. **Migration Audit:** Every `CREATE TABLE` must include a `tenant_id` and a corresponding RLS policy.
2. **Query Audit:** Reject any Drift or SQL query that doesn't explicitly filter by `tenant_id`.
3. **JWT Verification:** Ensure Edge Functions verify the `tenant_id` inside the JWT before processing payments.
4. **Input Validation:** Validate all inputs to prevent SQL injection and other injection attacks.
5. **PII Protection:** Mask sensitive data (phone numbers, IDs) in all logs.