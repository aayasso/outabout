# ai_specs — OutAbout Feature Specs & Work History

Per-feature requirements, designs, and task breakdowns.
This is the structured planning layer between "I want X" and "agent, build it."

---

## Folder Structure

```
ai_specs/
  [feature-name]/
    requirements.md    ← what to build (written first, no code yet)
    design.md          ← how to build it (architecture, data flow, edge cases)
    tasks.md           ← phase-by-phase implementation checklist
```

---

## The Workflow

### Phase 1 — Requirements
```
Read @CLAUDE.md and @ai_docs/architecture.md.

I want to build [feature]. Here's what it needs to do: [description]
Ask any clarifying questions before writing the requirements file.
```
Then: `Write requirements to ai_specs/[feature]/requirements.md`

Review and edit manually. This is the highest-leverage step.

### Phase 2 — Design
```
Read @ai_specs/[feature]/requirements.md,
@ai_docs/riverpod_patterns.md, and @ai_docs/supabase_api.md.

Write a design document to ai_specs/[feature]/design.md covering:
screens/widgets involved, provider structure, repository methods,
data flow, edge cases and error states.
Ask questions before starting.
```

### Phase 3 — Tasks
```
Read @ai_specs/[feature]/requirements.md and design.md.

Break this into tasks in ai_specs/[feature]/tasks.md.
Each top-level task = one minimal visible increment.
Each task must include subtasks for implementation,
widget tests, and running flutter analyze.
```

### Phase 4 — Implementation (one task at a time)
```
Read @ai_specs/[feature]/tasks.md.
Implement Task 1. Run flutter analyze when done.
Do not proceed to Task 2 until Task 1 passes.
```

### Phase 5 — Verify
- [ ] `flutter analyze` — zero warnings
- [ ] `flutter test` — all pass
- [ ] No hardcoded colors, static OutAboutColors in widgets
- [ ] All typography calls pass `colors` argument
- [ ] No hardcoded spacing, radius, or route strings
- [ ] New routes in AppRoutes + routerProvider
- [ ] Supabase operations through repository classes
- [ ] Haptics called at correct interaction points

---

## Requirements Template

```markdown
# Requirements — [Feature Name]
# Created: [date]
# Status: draft | in-progress | complete

## Summary
[One paragraph: what this feature is, who it serves, why it matters.]

## User Stories

### Primary flow
- As a user, I want to [action] so that [outcome].

### Secondary flows
- As a user, I want to [action] so that [outcome].

### Edge cases
- What happens when [network failure]?
- What happens when [empty state]?
- What happens when [permission denied]?

## Acceptance Criteria
- [ ] [Specific, testable condition]
- [ ] [Specific, testable condition]

## Screens Involved
- [ScreenName] — [new or modified, what changes]

## Data Requirements
- Supabase tables: [table names or "none"]
- New columns needed: [column, type] or "none"
- Tomorrow.io fields needed: [fields] or "none"
- SharedPreferences keys: [key names] or "none"

## Weather Theme Considerations
- Does this feature behave differently across themes? [yes/no]
- If yes: [describe per-theme behavior]

## Out of Scope
- [Explicitly list what this does NOT include]

## Open Questions
- [Any unresolved decision that could affect the build]
```

---

## Design Template

```markdown
# Design — [Feature Name]
# Created: [date]
# Requires: requirements.md approved

## Screens & Widgets

### [ScreenName]
- **Route:** `AppRoutes.X`
- **Type:** ConsumerWidget | ConsumerStatefulWidget
- **New widgets:** [list or "none"]
- **Colors source:** `ref.watch(weatherThemeColorsProvider)`

## Provider Structure

```dart
// New providers required
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier(ref.watch(myRepositoryProvider));
});
```

## Repository Methods

```dart
// New methods needed
class MyRepository {
  Future<X> methodName(args) async { ... }
}
```

## Data Flow
[User action → provider → repository → Supabase → UI]

## Edge Cases & Error States
| Scenario | Behavior |
|---|---|
| Network failure | Error state with retry button |
| Empty state | [describe empty state UI] |
| Loading | Shimmer skeleton |
| Permission denied | [describe fallback] |

## Haptic Moments
- [Action] → [OutAboutHaptics.method()]

## Open Questions Resolved
[Questions from requirements and their answers]
```

---

## Tasks Template

```markdown
# Tasks — [Feature Name]
# Created: [date]
# Requires: design.md approved

## Task 1 — [Data Layer]
Visible when done: [what user sees]

- [ ] Create repository: `lib/data/repositories/[name]_repository.dart`
- [ ] Add repository provider to providers or feature providers file
- [ ] Create model class: `lib/data/models/[name].dart`
- [ ] Write unit tests for repository methods
- [ ] Run `flutter analyze` — must pass before Task 2

## Task 2 — [Screen / UI]
Visible when done: [what user sees]

- [ ] Create screen: `lib/features/[feature]/screens/[name]_screen.dart`
- [ ] Add route to `AppRoutes` constants
- [ ] Add `GoRoute` to `routerProvider` with fade transition
- [ ] `colors = ref.watch(weatherThemeColorsProvider)` as first line of build
- [ ] All colors from `colors.X` — no OutAboutColors in widget
- [ ] All typography uses `colors` argument
- [ ] All spacing from `OutAboutSpacing`
- [ ] Write widget tests
- [ ] Run `flutter analyze` — must pass before Task 3

## Task 3 — [Integration & Polish]
Visible when done: [what user sees]

- [ ] Wire navigation to/from this screen
- [ ] Handle loading state with shimmer
- [ ] Handle error state with retry
- [ ] Handle empty state
- [ ] Haptics at correct interaction points
- [ ] Run `flutter test` — all pass
- [ ] Run `flutter analyze` — zero warnings

## Final Check
- [ ] Full pre-flight checklist from CLAUDE.md passes
- [ ] Tested on iOS simulator
- [ ] Tested on Android emulator
- [ ] `ai_docs/` updated if schema or architecture changed
```

---

## Active Features

| Feature | Status | Folder |
|---|---|---|
| — | — | — |

## Completed Features

| Feature | Completed | Notes |
|---|---|---|
| — | — | — |
