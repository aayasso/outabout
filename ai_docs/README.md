# ai_docs — OutAbout Persistent Knowledge Base

Persistent knowledge base for AI coding agents working on OutAbout.
Feed these files as context at the start of every agent session.

---

## Files

| File | Contents | When to read |
|---|---|---|
| `architecture.md` | Tech stack, folder structure, weather theme system, data flow, Supabase schema | Every session |
| `design_system.md` | All five weather palettes, typography, spacing, radius, shadows, templates | Before any UI work |
| `supabase_api.md` | Table columns, repository patterns, Tomorrow.io API, location patterns | Before any data/API work |
| `riverpod_patterns.md` | Provider types, hand-written patterns, consumer widgets, naming | Before any state work |
| `screens_navigation.md` | All screens, routes, onboarding flow, nav map, go_router config | Before any navigation work |

---

## How to Use in Claude Code

Start of any session:
```
Read @ai_docs/architecture.md before starting.
```

For UI work:
```
Read @ai_docs/design_system.md before writing any widget.
```

For feature work (full context):
```
Read @ai_docs/architecture.md, @ai_docs/design_system.md,
@ai_docs/riverpod_patterns.md, and @ai_docs/supabase_api.md.
```

---

## When to Update

| Trigger | File |
|---|---|
| New screen or route | `screens_navigation.md` |
| New Supabase table or column | `supabase_api.md`, `architecture.md` |
| Tomorrow.io integration built | `supabase_api.md` |
| New weather theme token | `design_system.md` |
| New Riverpod pattern established | `riverpod_patterns.md` |
| Architecture decision changes | `architecture.md` |
| New dependency added | `architecture.md` (tech stack table) |

---

## Relationship to Other AI Folders

```
CLAUDE.md      → Rules. Read automatically by Claude Code every session.
ai_docs/       → Knowledge. Feed manually per session via @ reference.
ai_specs/      → Work history. Per-feature requirements and plans.
```
