# OutAbout — CLAUDE.md

## What This Is
OutAbout is a consumer iOS app that sends push notifications when weather
conditions match activities on a user's personal wishlist. It is also the
primary data acquisition instrument for the OutAbout Intelligence Platform —
a self-improving agentic RAG system that produces condition-responsive
behavioral intelligence.

Every user interaction in this app is a training event. Build accordingly.

## Repositories
- Flutter app: weather-activities
- Intelligence platform: outabout-intelligence
- Supabase project ID: tswxxjwqnppqlfcbfowt

## Backend Services
- Database: Supabase (PostgreSQL + pgvector)
- Auth: Supabase Auth
- Push notifications: OneSignal + Firebase Cloud Messaging
- Weather data: Tomorrow.io
- Bundle ID: com.outabout
- Edge Functions: Deno / TypeScript

## Environment Variables — CHECK FIRST
Before writing any code confirm these exist in .env:
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- TOMORROW_IO_API_KEY
- ONESIGNAL_APP_ID
- ONESIGNAL_REST_API_KEY

If any are missing: STOP. Prompt the reviewer before proceeding.

## Tech Stack
- Framework: Flutter (iOS first — Android deferred to Phase 4)
- Language: Dart
- Backend: Supabase
- Agent tool: Claude Code (Terminal)

## Design System
- Primary color: #4A9EFF (sky blue)
- Accent color: #FF8C42 (warm orange)
- Personality: warm, energetic, motivating
- All design tokens defined in lib/core/theme.dart
- Never hardcode colors, text styles, or spacing values
- Always invoke the frontend-design skill for any UI work

## Supabase Schema — App Tables (read/write)
- activities — user wishlist items
- condition_profiles — weather thresholds per activity
- condition_profile_history — append-only log of every profile change
- categories — user-defined activity categories
- notification_preferences — per-activity notification settings

## Supabase Schema — Intelligence Tables (write-only from app)
- behavioral_events — every meaningful user interaction
- monetization_events — partner and affiliate interactions

## Behavioral Event Logging — NON-NEGOTIABLE
Every screen must log to behavioral_events.
Every event must include all four jsonb context objects.
Never log an event with missing fields.
Never store precise user coordinates — bucket to ~1 mile radius.

### Approved event_types
- wishlist_added
- wishlist_removed
- activity_viewed
- condition_profile_updated
- condition_match_notified
- notification_opened
- app_opened_post_notification
- activity_confirmed
- condition_match_ignored
- affiliate_link_clicked
- partner_impression_viewed
- partner_cta_clicked

### Required jsonb structure — conditions_at_event
{
  "temp_c": 0.0,
  "temp_f": 0.0,
  "precipitation_probability": 0,
  "wind_kph": 0.0,
  "uv_index": 0,
  "air_quality_index": 0,
  "forecast_window_hours": 0
}

### Required jsonb structure — geographic_context
{
  "metro": "",
  "city": "",
  "state": "",
  "country": "US",
  "lat_bucketed": 0.000,
  "lng_bucketed": 0.000,
  "timezone": ""
}

### Required jsonb structure — temporal_context
{
  "hour_of_day": 0,
  "day_of_week": 0,
  "week_of_month": 0,
  "month_of_year": 0,
  "season": "",
  "week_of_season": 0,
  "days_since_last_match": 0,
  "days_since_activity_created": 0,
  "consecutive_match_count": 0
}

### Required jsonb structure — session_context
{
  "platform": "ios",
  "app_version": ""
}

## Screen Build Status
- Phase 1 (Environment + Design System): COMPLETE
- Phase 2 Screen 1 (Onboarding / Auth): NOT STARTED
- Phase 2 Screen 2 (Activity Library): NOT STARTED
- Phase 2 Screen 3 (Add / Edit Activity): NOT STARTED
- Phase 2 Screen 4 (Browse Right Now): NOT STARTED
- Phase 2 Screen 5 (Settings / Account): NOT STARTED
- Phase 3 (Polish Pass): NOT STARTED
- Phase 4 (App Store Submission): NOT STARTED

## Workflow Protocol — MANDATORY

### Step 1 — Session Start Checklist
Every Claude Code session must begin with:
1. Read CLAUDE.md and AGENTS.md in full
2. Verify all environment variables are present in .env
   — If any are missing: STOP and prompt reviewer
3. State which screen is currently being built
4. Confirm current build status matches CLAUDE.md

### Step 2 — Planning Mode
Before writing any code produce a numbered execution plan:
- What will be built, file by file
- What depends on what, in order
- Which behavioral events will be logged and at what interaction
- What tests will prove each piece works
- Any decisions or information needed from reviewer

DO NOT write any code until reviewer explicitly approves the plan.

### Step 3 — Decision Prompts
STOP and prompt reviewer whenever:
- Two or more valid implementation approaches exist
- A UI pattern is not specified in the design system
- Behavioral event coverage for an interaction is ambiguous
- Any decision could affect intelligence platform data quality
- Anything in the codebase contradicts these instructions

### Step 4 — Build One Step At A Time
After plan approval:
- Build one logical unit at a time
- Write tests alongside the code — never after
- Confirm each step passes before moving to the next
- Never proceed past a failing test

### Step 5 — Screen Completion Gate
A screen is complete only when ALL of the following are true:
- UI matches design system exactly (verified against theme.dart)
- All behavioral events log correctly with full jsonb context
- Widget tests pass
- Integration tests pass
- iOS simulator build runs without errors
- Reviewer has explicitly approved

Update Screen Build Status in this file after each completion.

## Blue Chip Quality Standards
Every screen must meet all of these before moving on:
- Physics-based animations on all transitions
- Haptic feedback on all key interactions
- Loading skeletons on all async operations — never spinners
- Contextual empty states — never a blank screen
- Accessibility labels on all interactive elements
- Typographic hierarchy consistent with design system
- No hardcoded values anywhere in the codebase

## Professionalism Rules
These apply to every file, every comment, every string:
- No personal names in code or comments
- No email addresses anywhere in the codebase
- No internal project references in user-facing text
- No placeholder copy left in production code
- Error messages must be user-friendly — never expose technical details
- All UI copy must be polished and brand-consistent with OutAbout tone

## Installed Skills
- frontend-design (Anthropic) — invoke for all UI work
- supabase (Supabase) — invoke for all database interactions
- supabase-postgres-best-practices (Supabase)
- security-guidance (Anthropic) — run before every screen completion
- Skill Development (Anthropic)
- Agent Development (Anthropic)
- find-skills (Vercel Labs)

## What Claude Code Must Never Do
- Hardcode any color, spacing, or text style value
- Use a spinner — always use a loading skeleton
- Leave any empty state blank
- Log a behavioral event with missing jsonb fields
- Store precise user coordinates
- Include personal info, developer names, or internal references
- Proceed past a failing test
- Make architectural decisions without prompting reviewer
- Write code before the plan is approved by reviewer
- Reference Cursor — Claude Code in Terminal is the build tool
