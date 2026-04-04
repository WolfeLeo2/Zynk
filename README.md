# Zynk

Zynk is an offline-first SME business platform focused on inventory, invoicing, POS, and operations.

Core stack:
- Flutter + Riverpod
- Supabase (Auth, Postgres, Edge Functions, RLS)
- PowerSync for local-first sync

## Contributor Workflow (Human + AI)

Follow this order for every implementation task.

1. Understand task and project rules
	- Read `AGENTS.md` first.
	- Review relevant docs in `docs/`.

2. Load and query project memory with Mulch (mandatory)
	- Run `ml prime` (or `ml prime <domain>` for focused context).
	- Run `ml query <domain>` for the area you will change.
	- Use `ml search "<topic>"` when uncertain.

3. Plan before coding (for medium/complex changes)
	- Create a trackable plan in `docs/plans/`.
	- Get alignment/approval before broad changes.

4. Implement with architecture boundaries
	- Keep business-critical writes server-authoritative through Edge Functions.
	- Avoid direct client CRUD for sensitive financial domains.
	- Keep feature boundaries and AGENTS.md conventions intact.

5. Validate
	- Run `dart analyze`.
	- Run targeted checks relevant to your change.

6. Record learnings in Mulch before finishing
	- Run `ml learn` to inspect change impact.
	- Run `ml record <domain> --type <type> ...` for durable insights.
	- Run `ml validate` to ensure memory quality.
	- Run `ml sync` to stage/commit `.mulch/` knowledge updates.

7. Maintain planning hygiene
	- Move completed plans from `docs/plans/` to `docs/completed-plans/`.

## Mulch Quick Setup

If Mulch is not installed:

```bash
npm install -g @os-eco/mulch-cli
curl -fsSL https://bun.sh/install | bash
```

In the repository:

```bash
ml init
ml add architecture
ml add backend
ml add powersync
ml add security
ml add performance
ml add conventions
```

## Dev Commands

```bash
dart analyze
flutter test
```

## Important Project Notes

- Use Supabase MCP for SQL migrations; do not rely on ad-hoc SQL drift.
- Keep tax behavior aligned with current business rule (VAT already included in selling prices).
- Negative stock is allowed by product policy and resolved via adjustment approval/reversal workflows.
