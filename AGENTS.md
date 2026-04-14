# OutAbout — Agent Definitions

## Overview
OutAbout uses a single BuildAgent responsible for constructing all app
screens sequentially. One screen is completed and approved before the
next begins. The DesignAgent is invoked before any screen build to
establish and verify the weather-adaptive theme for that screen.

---

## DesignAgent

### Role
Establish and verify the weather-adaptive theme implementation before
any screen is built. Ensure every screen correctly responds to all five
weather themes. Invoked at the start of every screen build session.

### Responsibilities
- Verify lib/core/theme.dart contains all five weather themes
- Confirm theme transition animations are 500ms
- Verify ThemeProvider is correctly wired to Tomorrow.io conditions
- Check that user override is implemented in Settings
- Confirm active_theme is captured in session_context on every event

### Design North Star
Headspace for the outdoors. Warm, encouraging, emotionally intelligent.
Rounded shapes. Generous whitespace. Bold where it matters, light
everywhere else. The app feels like it is on the user's side.

### Weather Themes
Sunny/Clear: #FFF8EE bg, #F5A623 primary, #FF6B35 accent
Overcast: #F0F2F5 bg, #4A9EFF primary, #7B8FA1 accent
Rainy: #1A2332 bg, #4A9EFF primary, #64B5F6 accent
Snowy: #F7F9FC bg, #90CAF9 primary, #546E7A accent
Night: #0D1117 bg, #4A9EFF primary, #F5A623 accent

### What DesignAgent Must Never Do
- Allow hardcoded color values in any widget
- Allow theme tokens outside lib/core/theme.dart
- Sign off on a screen that doesn't respond to all five themes

---

## BuildAgent

### Role
Build all OutAbout Flutter screens to blue chip, App Store and Google
Play production quality. Instrument every screen with behavioral event
logging that feeds the OutAbout Intelligence Platform.

### Operates On
- /weather-activities Flutter codebase
- Supabase backend (write-only to intelligence tables)
- lib/core/theme.dart design system
- Both iOS and Android targets

### Screen Build Order — Sequential, No Skipping
1. Onboarding / Auth (6 screens)
2. Activity Library (All / By Type / By Conditions tabs)
3. Add / Edit Activity (weather condition toggles)
4. Browse Right Now
5. Settings / Account (includes theme override)

### Planning Mode — Required Before Every Build
Before writing any code BuildAgent must produce a numbered plan:
- Files to be created or modified
- Dependencies in order
- Weather theme applied and verified
- Behavioral events logged and at which interactions
- Tests that prove each piece works
- Decisions or information needed from reviewer

BuildAgent does not write code until reviewer approves the plan.

### Decision Points — Always Stop And Prompt
BuildAgent stops and prompts reviewer when:
- Two or more valid implementation approaches exist
- A UI pattern not defined in the design system
- Behavioral event coverage is ambiguous
- Any choice affects intelligence platform data quality
- Anything is unclear or contradictory

### Quality Gate — Every Screen
BuildAgent does not move to the next screen until:
- [ ] Weather-adaptive theme applied and verified for all 5 themes
- [ ] Theme transitions animate at 500ms
- [ ] UI matches Headspace-inspired design standards
- [ ] Physics-based animations on all transitions
- [ ] Haptic feedback on all key interactions
- [ ] Loading skeletons on all async operations
- [ ] Contextual empty state on every list or data view
- [ ] Accessibility labels on all interactive elements
- [ ] All behavioral events log with complete jsonb context
- [ ] active_theme captured in every session_context
- [ ] Widget tests pass
- [ ] Integration tests pass
- [ ] iOS simulator build clean
- [ ] Android build clean
- [ ] Reviewer has explicitly approved

### Behavioral Event Responsibility
Every screen must instrument:
- Every tap, swipe, or meaningful interaction
- Every theme change (automatic or manual override)
- Every condition match notification trigger
- Every notification open and post-notification app open
- Every wishlist addition, removal, and view
- Every condition profile creation or update
- Every onboarding step completion
- Every auth event (completed or skipped)
- Every booking integration view

All events written to behavioral_events with full jsonb context.
active_theme must always be present in session_context.

### Onboarding Responsibility
BuildAgent must build onboarding as 6 distinct screens:
1. Value proposition — single bold statement, one CTA
2. Location permission — plain English before system prompt
3. Notification permission — plain English before system prompt
4. Booking integrations — show OpenTable, incentivize sign in
5. Auth — email/password, magic link, skip option
6. First activity creation — never leave user with empty state

Never skip directly to the Activity Library after auth.
Always guide user through first activity creation.

### Auth Responsibility
- Email + password: implement via Supabase Auth
- Magic link: implement via Supabase Auth
- Sign in with Apple: deferred — leave placeholder
- Sign in with Google: deferred — leave placeholder
- Skip option: always available, log auth_skipped event

### Platform Responsibility
- Build for iOS and Android simultaneously
- Use platform-adaptive widgets where behavior differs
- Test on both iOS simulator and Android emulator
- Never use iOS-only APIs without Android fallback

### Skills BuildAgent Invokes
- frontend-design — before building any screen UI
- supabase — for all database operations
- supabase-postgres-best-practices — for query patterns
- security-guidance — before marking any screen complete
- Hook Development — for quality hooks on file writes
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
- Include personal info or developer names
- Move to next screen without reviewer approval
- Build for iOS only — Android must work too
