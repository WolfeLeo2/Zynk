# GEMINI.md — Zynk Codebase Design Principles & Workflows

This file defines the engineering standards for the Zynk codebase, as well as the behavior protocol for Gemini / AI agents.
All contributors (human and AI) must follow these rules.

---
## Coding Conventions
- Do not use Supabase CLI for SQL migrations. Use Supabase MCP
- Move completed implementation plans from `docs/plans/` to `docs/completed-plans/` when finished.

### Dart / Flutter
- `json_serializable` for JSON parsing — no manual `fromJson`
- All async operations use `AsyncValue` from Riverpod — handle loading, data, and error in UI
- Feature folders are self-contained with `data/`, `domain/`, `presentation/`
- Shared widgets in `lib/shared/widgets/` — never duplicate across features
- File naming: `snake_case.dart`
- Class naming: `PascalCase`
- Never use `BuildContext` across async gaps
- `ListView.builder` only — never `ListView` with children array
- Loading states: shimmer skeleton loaders only — never `CircularProgressIndicator`
- Never show empty screens — always shimmer, error state, or empty state illustration
- Remote images: `cached_network_image` with team color gradient placeholder
- Complex list items: wrap in `RepaintBoundary`
- Do not use if blocks if it is a simple Null check. Dart is null aware. Use that to your advantage
- All screens need to be responsive
- Do not use my AppTokens raw. Use them from referencing colorScheme. Raw AppTokens don't mutate according to theme

---

## Core Design Principles

### DRY — Don't Repeat Yourself
> Every piece of knowledge must have a **single, unambiguous, authoritative representation**.

**In practice:**
- Extract shared UI into reusable widgets (`BranchRequiredGuard`, `AuthPinPad`, `SkeletonWidget`)
- Shared business logic lives in services (`SalesService`, `AuthService`) — not in screen `build()` methods
- Database queries belong in `PowerSyncRepository` — never inline SQL in providers or widgets
- Theme values come from `AppTokens` — never hardcode colors or spacing

### KISS — Keep It Simple, Stupid
> The simplest solution that works is the correct one.

**In practice:**
- Providers should do **one thing** — watch data OR derive data, not both + manage side effects
- Prefer `StreamProvider` over complex `AsyncNotifier` when you just need a stream
- Riverpod redirect functions must be **pure functions** — read state, return a path, nothing else
- Avoid over-engineering state: if a `bool` works, don't use a `sealed class`

### SOLID
#### S — Single Responsibility
Each class/file has **one reason to change**.
| Layer | Responsibility |
|-------|---------------|
| `repository.dart` | Raw DB queries only |
| `*_service.dart` | Business logic (validation, orchestration) |
| `*_provider.dart` | State + derived data |
| `*_screen.dart` | UI layout and user events only |
| `*_widget.dart` | Reusable UI components |

#### O — Open/Closed
Extend behavior without modifying existing code.
- Use `Provider.family` for parameterized data — don't add conditionals inside existing providers
- Add new routes in `routes.dart` without touching existing route definitions

#### L — Liskov Substitution
- `ConsumerWidget` and `ConsumerStatefulWidget` should be interchangeable for the same use case
- Prefer `ConsumerWidget` (stateless) unless you need `AnimationController` or `TextEditingController`

#### I — Interface Segregation
- Don't add methods to `PowerSyncRepository` that only one screen uses — create a focused service instead
- Providers that only one widget uses should be scoped (`.autoDispose`) or local

#### D — Dependency Inversion
- Screens depend on **providers**, not on concrete service classes
- `ref.watch(repositoryProvider)` not `PowerSyncRepository(db)` inside a widget

---

### YAGNI — You Aren't Gonna Need It
> Don't build features until they are needed.

**In practice:**
- Don't add `refreshBranches()` to a notifier when a `StreamProvider` already handles freshness
- Don't build a `CombinedListenable` unless you actually combine multiple listenables
- Delete dead code immediately — unused classes/providers are tech debt

---

## Riverpod-Specific Rules
1. **`Notifier.build()` must be pure** — return initial state only. No `ref.listen`, no `Future.microtask`, no async calls.
2. **Side effects that react to streams** belong in a dedicated `Provider` (not a `Notifier`), watched by an always-alive widget (e.g., `AppShell`).
3. **Use `WidgetsBinding.addPostFrameCallback`** (not `Future.microtask`) to defer state mutations that happen during provider initialization.
4. **`StreamProvider.autoDispose`** for screen-scoped data; **`StreamProvider`** (no autoDispose) for app-wide data (branches, auth).
5. **`ref.read` in callbacks**, **`ref.watch` in build** — never the other way around.
6. **`Provider.family`** for parameterized providers — never pass state through constructors to solve the same problem.

---

## File Structure Rules
```
lib/
  core/
    models/         # Pure Dart data classes — no Flutter imports
    providers/      # App-wide Riverpod providers
    services/       # Business logic (no UI)
    widgets/        # Truly reusable, app-wide UI components
    theme/          # AppTokens, ThemeData
    routes.dart     # GoRouter config only
    app_shell.dart  # Navigation shell only
  data/
    local/          # PowerSync repository (SQL only)
  features/
    <feature>/
      models/       # Feature-specific models
      providers/    # Feature-specific providers
      presentation/ # Screens + widgets
```
**Rules:**
- No cross-feature imports
- Models never import Flutter
- Services never import widgets
- Providers never import `package:flutter/material.dart`

---

## Naming Conventions
| Thing | Convention | Example |
|-------|-----------|---------|
| Provider | `camelCaseProvider` | `currentBranchIdProvider` |
| Notifier | `PascalCaseNotifier` | `BranchSelectionNotifier` |
| Screen | `PascalCaseScreen` | `PosScreen` |
| Widget file | `snake_case.dart` | `branch_required_guard.dart` |
| Service | `PascalCaseService` | `SalesService` |
| Model | `PascalCase` | `Branch`, `Sale` |

---

## AI Agent Guidelines

When making changes to this codebase:
1. **Read before writing** — view the file and understand what exists before editing
2. **Analyze before claiming done** — always run `dart analyze` before saying a task is complete
3. **One concern per PR/task** — don't mix feature work with refactoring
4. **Delete dead code** — if a class/provider/method is no longer referenced, remove it
5. **No inline SQL in widgets or providers** — it belongs in `repository.dart`
6. **No business logic in `build()` methods** — delegate to services/providers
7. **Prefer hot reload over full restart** — use the DTD MCP tool when available

### **Research -> Questions -> Plan Pipeline**
When tackling medium-to-complex user requests, feature additions, or UI/UX overhauls, the Agent MUST follow this pipeline **before making any code changes**:
1. **Research First**: Gather context by reviewing existing files, scraping provided web links (e.g., competitors, inspiration), or searching the web for concepts (e.g., "Zoho Item Groups").
2. **Ask Questions**: Identify any ambiguities in the user's request. Formulate clear, concise questions regarding business logic, UI preferences, or database schema decisions.
3. **Draft an Implementation Plan**: Using the `writing-plans` skill or similar, create an implementation plan artifact (e.g., `implementation_plan.md`) outlining database migrations, logic changes, and UI/UX designs.
4. **Notify User**: Present findings, ask the questions, and link the plan artifact for the user's approval.
5. **Wait for Approval**: Do not edit code until the user approves the plan or answers the questions.
