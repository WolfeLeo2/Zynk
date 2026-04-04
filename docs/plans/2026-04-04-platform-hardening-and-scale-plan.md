# 2026-04-04 Platform Hardening And Scale Plan

## Context
This plan consolidates the requested platform hardening and scaling work for Zynk and aligns it with:
- Current architecture (Flutter + Riverpod + Supabase + PowerSync)
- AGENTS.md conventions and Mulch workflow
- Live Supabase advisor findings on project `kfqionlpnjetpmuzsvfb`

## Scope (Requested)
1. Use Zynk Supabase project ref `kfqionlpnjetpmuzsvfb`
2. Fix stale PowerSync config
3. Normalize authority to prevent direct client table CRUD
4. Keep negative stock allowed (business-approved)
5. Separate invoice lifecycle status from payment status
6. Re-check and harden RLS with correct MCP project
7. Keep tax at zero for now (VAT included in selling prices)
8. Make salesperson required in UI
9. Fix convention debt against AGENTS.md
10. Harden security and policy inconsistencies
11. Add performance baseline
12. Add operational aggregates in Postgres for reporting
13. Add scheduled daily KPI snapshots
14. Install and use Mulch + document contributor order

## Additional Items Added (From Live Audit)
- Address Supabase security advisor warnings:
  - Mutable `search_path` on SECURITY DEFINER functions
  - `tenants` table has RLS enabled but no policy
  - Leaked password protection disabled (Auth setting)
- Address sync/schema drift risks in PowerSync config
- Introduce phased authority normalization to avoid product breakage

## Implementation Phases

### Phase 0: Planning And Safety Rails
- [ ] Confirm this plan as implementation source
- [ ] Keep changes scoped to one concern per PR/task where possible
- [ ] Run `dart analyze` after each implementation batch
- [ ] Use Mulch lifecycle throughout (prime/query at start, record/validate/sync at end)

### Phase 1: Critical Fixes (Do First)
- [x] 1A. PowerSync config refresh
  - [x] Remove references to dropped tables (e.g., `stock_item_groups`)
  - [x] Align config to active schema/tables
  - [ ] Prepare migration path to edition 3 sync config format
- [x] 1B. Authority normalization (phase 1)
  - [x] Prevent direct client CRUD for invoice/payment domain writes
  - [x] Route invoice/payment mutations through Edge Functions
  - [x] Keep stock adjustments negative-capable and admin-reversible

### Phase 2: Data Model And Workflow Consistency
- [ ] Separate invoice lifecycle status from payment status end-to-end
- [ ] Keep tax calculations at zero by explicit product policy configuration
- [x] Enforce required salesperson selection in invoice UI and save flows

### Phase 3: Security And Policy Hardening
- [ ] RLS policy audit for tenant-isolated tables (`sales`, `sale_items`, `sale_payments`, `stock`, `credit_notes`, `profiles`, `tenants`)
- [ ] Standardize identity mapping in RLS (`profiles.user_id = auth.uid()`)
- [ ] Harden SECURITY DEFINER functions with fixed `search_path`
- [ ] Tighten permissive policy usage where not intentional
- [ ] Enable leaked password protection in Supabase Auth settings

### Phase 4: Convention Debt Cleanup
- [ ] Replace manual JSON parsing with `json_serializable` where required
- [ ] Eliminate provider layer imports of `material.dart`
- [ ] Remove `Future.microtask` side-effects from Notifier.build
- [ ] Reduce cross-feature imports by moving shared contracts to `core/`
- [ ] Replace spinner loading states with shimmer skeletons in key screens
- [ ] Replace `ListView(children: ...)` with builder/sliver patterns where needed

### Phase 5: Performance Baseline
- [ ] Add indexes for critical query patterns (tenant, branch, status, date, FK)
- [ ] Capture query baselines (before/after) for dashboard/reporting paths
- [ ] Add lightweight performance notes to docs

### Phase 6: Reporting Aggregates And Scheduling
- [ ] Add operational aggregate tables/materialized views (daily revenue/orders/payments/low-stock)
- [ ] Add scheduled snapshots using `pg_cron` (daily KPI jobs)
- [ ] Validate aggregate correctness against source transactions

### Phase 7: Mulch And Contributor Workflow
- [x] Install/initialize Mulch (done in this session)
- [x] Add project domains and record implementation learnings
- [x] Update README with contributor execution order (human/AI)

## Acceptance Criteria
- [ ] No stale table references in PowerSync sync config
- [ ] Invoice/payment write authority is server-routed and not direct client CRUD
- [ ] Negative stock remains supported for approved adjustment workflows
- [ ] Salesperson is required in invoice UI flows
- [ ] Security advisor findings reduced for controllable DB/function policies
- [ ] Performance baseline/index plan documented and partially applied
- [ ] Operational daily aggregates are generated on schedule
- [ ] `dart analyze` passes
- [ ] Mulch records updated with decisions/conventions/failures

## Execution Order For This Task
1. Implement Phase 1A (PowerSync stale config)
2. Implement Phase 1B (Authority normalization for invoice/payment domain)
3. Update README with Mulch contributor workflow
4. Validate (`dart analyze`)
5. Record learnings in Mulch (`ml record`, `ml validate`, `ml sync`)
