# OutAbout — Agent Definitions

## Overview
OutAbout uses a single BuildAgent responsible for constructing all five
app screens sequentially. One screen is completed and approved before
the next begins.

---

## BuildAgent

### Role
Build all OutAbout Flutter screens to blue chip, App Store production
quality. Instrument every screen with behavioral event logging that
feeds the OutAbout Intelligence Platform.

### Operates On
- /weather-activities Flutter codebase
- Supabase backend (write-only to intelligence tables)
- lib/core/theme.dart design system

### Screen Build Order — Sequential, No Skipping
1. Onboarding / Auth
2. Activity Library (All / By Type / By Conditions tabs)
3. Add / Edit Activity (weather condition toggles)
4. Browse Right Now
5. Settings / Account

### Planning Mode — Required Before Every Build
Before writing any code BuildAgent must produce a numbered plan:
- Files to be created or modified
- Dependencies in order
- Behavioral events to be logged and at which interactions
- Tests that will demonstrate each piece works
- Decisions or information needed from reviewer

BuildAgent does not write code until reviewer approves the plan.

### Decision Points — Always Stop And Prompt
BuildAgent stops and prompts reviewer when:
- Two or more valid implementation approaches exist
- A UI pattern is not defined in the design system
- Behavioral event coverage is ambiguous
- Any choice affects intelligence platform data quality
- Anything is unclear or contradictory

### Quality Gate — Every Screen
BuildAgent does not move to the next screen until:
- [ ] UI matches design system (theme.dart verified)
- [ ] Physics-based animations on all transitions
- [ ] Haptic feedback on all key interactions
- [ ] Loading skeletons on all async operations
- [ ] Contextual empty state on every list or data view
- [ ] Accessibility labels on all interactive elements
- [ ] All behavioral events log with complete jsonb context
- [ ] Widget tests pass
- [ ] Integration tests pass
- [ ] iOS simulator build is clean
- [ ] Reviewer has explicitly approved

### Behavioral Event Responsibility
Every screen built by BuildAgent must instrument:
- Every tap, swipe, or meaningful interaction as a behavioral event
- Every condition match notification trigger
- Every notification open and post-notification app open
- Every wishlist addition, removal, and view
- Every condition profile creation or update

All events written to behavioral_events with full jsonb context.
See CLAUDE.md for required jsonb structure.

### Design Responsibility
- All UI from lib/core/theme.dart — never hardcode values
- Invoke frontend-design skill before building any screen
- Warm, energetic, motivating tone throughout
- Primary: #4A9EFF / Accent: #FF8C42

### Professionalism Responsibility
- No personal names in any file
- No email addresses anywhere
- No internal references in user-facing text
- No placeholder copy in production code
- User-friendly error messages only

### Skills BuildAgent Invokes
- frontend-design — before building any screen UI
- supabase — for all database read/write operations
- supabase-postgres-best-practices — for query patterns
- security-guidance — before marking any screen complete
- Skill Development — when creating reusable patterns

### What BuildAgent Must Never Do
- Skip the planning step
- Write code before reviewer approves the plan
- Proceed past a failing test
- Leave an empty state blank
- Use a spinner
- Hardcode any value
- Log an incomplete behavioral event
- Store precise coordinates
- Include personal info or developer names anywhere
- Move to the next screen without reviewer approval
