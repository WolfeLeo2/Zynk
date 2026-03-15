# AGENTS.md — Zynk Codebase Design Principles

This file defines the engineering standards for the Zynk codebase.
All contributors (human and AI) must follow these rules.

---
## Coding Conventions

### Dart / Flutter

- `freezed` for all model classes (immutable, copyWith, equality)
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



## Core Design Principles

### DRY — Don't Repeat Yourself
> Every piece of knowledge must have a **single, unambiguous, authoritative representation**.

**In practice:**
- Extract shared UI into reusable widgets (`BranchRequiredGuard`, `AuthPinPad`, `SkeletonWidget`)
- Shared business logic lives in services (`SalesService`, `AuthService`) — not in screen `build()` methods
- Database queries belong in `PowerSyncRepository` — never inline SQL in providers or widgets
- Theme values come from `AppTokens` — never hardcode colors or spacing

**Red flags:**
```dart
// ❌ Same SQL in 3 different providers
final p1 = StreamProvider((ref) => ref.watch(repositoryProvider).db.watch('SELECT ...'));
final p2 = StreamProvider((ref) => ref.watch(repositoryProvider).db.watch('SELECT ...'));

// ✅ One method on the repository, called from providers
final p1 = StreamProvider((ref) => ref.watch(repositoryProvider).watchProducts());
```

---

### KISS — Keep It Simple, Stupid
> The simplest solution that works is the correct one.

**In practice:**
- Providers should do **one thing** — watch data OR derive data, not both + manage side effects
- Prefer `StreamProvider` over complex `AsyncNotifier` when you just need a stream
- Riverpod redirect functions must be **pure functions** — read state, return a path, nothing else
- Avoid over-engineering state: if a `bool` works, don't use a `sealed class`

**Red flags:**
```dart
// ❌ Notifier.build() with ref.listen + side effects + async init + validation
class BranchNotifier extends Notifier<State> {
  @override
  State build() {
    ref.listen(...); // ❌ fires during build
    Future.microtask(() => _init()); // ❌ deferred side effect in build
    return initialState;
  }
}

// ✅ build() returns initial state only; side effects in separate providers
class BranchNotifier extends Notifier<State> {
  @override
  State build() => const State(isLoading: true); // pure
}
```

---

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
Not directly applicable to Flutter, but:
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
- Don't add `role`-based visibility to a feature before the role system is tested end-to-end
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
- No cross-feature imports (feature A must not import from feature B's `presentation/`)
- Models never import Flutter — only `dart:core`
- Services never import widgets
- Providers never import `package:flutter/material.dart` (use `package:flutter/foundation.dart` if needed)

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
