# 2026-04-15 Supabase Schema Remediation Plan

## Objective

Stabilize the data contract between live Supabase, local migrations, PowerSync local schema, and Flutter app write paths so that:

- schema changes are deterministic and reproducible from repo state
- server-authoritative financial writes remain authoritative
- PowerSync local schema matches synced table shapes
- security and performance debt from schema drift is reduced

Project ref: kfqionlpnjetpmuzsvfb

## Audit Baseline (Confirmed)

1. Live DB and repo migration history are drifted.
- Live applied migrations: 46
- Repo migrations: 19
- Live schema still contains legacy artifacts expected to be removed in repo migrations.

2. App has local write paths that conflict with server-authoritative financial model.
- Commission status writes are triggered in UI and local repository, but upload layer skips direct commission table sync.

3. PowerSync local table definitions do not fully match live Supabase table shape.
- Example drift: composite components and commissions column mismatch.

4. Security and performance advisor debt remains.
- Security warnings on storage listing and auth leaked-password setting.
- High count of unused indexes and low FK covering index ratio.

## Non-Negotiable Constraints

1. Use Supabase MCP for schema work, not Supabase CLI migrations execution.
2. Keep invoice and payment mutations server-authoritative.
3. Preserve multi-tenant isolation through current_tenant_id-based RLS model.
4. Keep PowerSync sync config on edition 3 stream model as active source.

## Phase Plan

### Phase 0: Safety, Snapshot, and Contract Lock

Goal: freeze target contract before edits.

Tasks:
- Export and store a live schema snapshot artifact in docs for reference.
- Record a contract matrix for each critical table:
  - live Supabase columns
  - PowerSync local schema columns
  - Dart model fields
  - repository write SQL
- Confirm which artifacts are canonical going forward:
  - DB schema: Supabase live after remediation migrations
  - App contract: updated to match DB
  - PowerSync config: powersync/sync-config.yaml only

Deliverables:
- docs/schema/live-schema-snapshot-2026-04-15.md
- docs/schema/contract-matrix-2026-04-15.md

### Phase 1: Migration Reconciliation and Legacy Cleanup

Goal: remove historical drift and align repo migrations with intended current schema.

Tasks:
- Add reconciliation migration set to repo, applied via Supabase MCP in controlled order.
- Clean legacy variant/group remnants if confirmed as deprecated:
  - products.group_id
  - products.product_type
  - products.variant_options
  - products.variant_images
  - products.parent_id
  - stock_item_groups table
- Remove stale indexes tied to dropped columns.
- Normalize sales status defaults and constraints to lifecycle model:
  - pending_approval, approved, rejected, voided
  - payment_status and fulfillment_status as separate axes
- Add missing constraints for status columns where absent.

Planned migration files:
- supabase/migrations/20260415090000_reconcile_legacy_product_grouping.sql
- supabase/migrations/20260415091000_sales_status_defaults_and_checks.sql
- supabase/migrations/20260415092000_drop_stale_indexes_from_legacy_columns.sql

### Phase 2: App and PowerSync Contract Alignment

Goal: make app write/read behavior consistent with reconciled schema.

Tasks:
- Update PowerSync local schema definitions in lib/core/config/powersync.dart to exactly match live columns for synced tables.
- Update repository SQL writes for affected tables (especially composite items and commissions).
- Remove or reroute local commission status mutation paths to server-authoritative endpoint.
- Add server endpoint for commission payout status changes if needed.
- Consolidate sync config ownership:
  - keep powersync/sync-config.yaml active
  - archive/deprecate legacy sync_rules.yaml file to avoid dual-source confusion

Planned code targets:
- lib/core/config/powersync.dart
- lib/data/local/repository.dart
- lib/features/reports/presentation/commissions_report_screen.dart
- supabase/functions/manage-sale/index.ts (or a new dedicated commission function)
- powersync/sync-config.yaml
- sync_rules.yaml

### Phase 3: Security Hardening

Goal: reduce blast radius and close advisor warnings.

Tasks:
- Restrict unnecessary table-level grants for anon/authenticated to least privilege where possible.
- Keep RLS enforcement intact and verify policy behavior after privilege changes.
- Tighten storage object listing policies for public buckets:
  - avatars
  - logos
  - product-images
- Enable leaked password protection in Supabase Auth settings.

Validation:
- Re-run Supabase security advisors and confirm warning reduction.

### Phase 4: Performance and Integrity Hardening

Goal: improve operational safety and query posture after schema reconciliation.

Tasks:
- Add FK covering indexes for high-frequency relations first, then remaining uncovered set.
- Review and prune truly dead indexes after observation window.
- Standardize updated_at maintenance:
  - add update trigger coverage for tables using updated_at where automation is expected
- Tighten nullable core fields where business-required and safe to enforce.

Planned migration files:
- supabase/migrations/20260415093000_fk_covering_indexes_priority_set.sql
- supabase/migrations/20260415094000_updated_at_trigger_coverage.sql
- supabase/migrations/20260415095000_not_null_enforcements_safe_subset.sql

### Phase 5: Validation and Rollout

Goal: verify behavior, prevent regression, and document the new source of truth.

Validation checklist:
- Supabase:
  - run security advisors
  - run performance advisors
  - run FK index coverage query
  - run policy/grant sanity queries
- App:
  - dart analyze
  - smoke tests for invoices, payments, credit notes, commissions, and stock adjustments
  - verify no local-only financial state drift
- Sync:
  - verify PowerSync first sync and upload queue behavior
  - verify no schema mismatch errors during CRUD replay

Documentation updates:
- docs/SCHEMA.md updated to actual post-remediation contract
- docs/ARCHITECTURE.md write-authority section updated
- move this plan to docs/completed-plans after implementation completion

## Execution Order

1. Phase 0 contract lock
2. Phase 1 migration reconciliation
3. Phase 2 app/powersync alignment
4. Phase 3 security hardening
5. Phase 4 performance/integrity hardening
6. Phase 5 validation and docs

## Risks and Mitigations

1. Risk: destructive legacy cleanup can break hidden dependencies.
- Mitigation: run dependency scans before each drop; apply in branch with data backup.

2. Risk: commission flow behavior changes for users.
- Mitigation: ship server endpoint first, then switch UI calls, then remove old local path.

3. Risk: over-tightening NOT NULL/check constraints breaks existing rows.
- Mitigation: pre-clean data and apply constraints in two-step migrations.

4. Risk: privilege tightening unexpectedly blocks app paths.
- Mitigation: execute with explicit role-path tests and rollback statements prepared.

## Decisions Needed Before Implementation

1. Legacy product variant/group model:
- Confirm full removal of products.group_id, stock_item_groups, and parent/variant columns.

2. Commission payout authority:
- Confirm commissions status updates must be server-authoritative only (recommended).

3. complete-sale function:
- Confirm whether to deprecate/remove or keep and align with current sales contract.

4. Security posture:
- Confirm we should enforce least-privilege grants now in same rollout (recommended) or defer to separate hardening release.

## Definition of Done

- Repo migrations can recreate current intended schema without manual drift patches.
- App and PowerSync schemas match live Supabase contract.
- No local-only financial state transitions remain.
- Security warnings reduced (or explicitly accepted with documented rationale).
- Performance baseline and FK index coverage improved and documented.
