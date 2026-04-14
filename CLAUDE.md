# OutAbout — CLAUDE.md

## What This Is
OutAbout is a consumer iOS and Android app that sends push notifications
when weather conditions match activities on a user's personal wishlist.
It is also the primary data acquisition instrument for the OutAbout
Intelligence Platform — a self-improving agentic RAG system that produces
condition-responsive behavioral intelligence.

Every user interaction is a training event. Build accordingly.

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

## Environment Variables — CHECK FIRST
Before writing any code confirm these exist in .env:
- SUPABASE_URL
- SUPABASE_SERVICE_ROLE_KEY
- TOMORROW_IO_API_KEY
- ONESIGNAL_APP_ID
- ONESIGNAL_REST_API_KEY

If any are missing: STOP. Prompt the reviewer before proceeding.

## Tech Stack
- Framework: Flutter (iOS and Android)
- Language: Dart
- Backend: Supabase
- Agent tool: Claude Code (Terminal)

## Target Platforms
- iOS (primary)
- Android (parallel — same codebase, submit to Google Play simultaneously)

## Design Philosophy — Headspace-Inspired
OutAbout should feel like Headspace for the outdoors:
- Warm, encouraging, and emotionally intelligent
- Rounded friendly shapes — nothing sharp or clinical
- Generous whitespace that feels calm not empty
- Bold typography where it matters, light everywhere else
- Transitions that feel smooth and intentional, never jarring
- The app feels like it is on the user's side

## Signature Feature — Weather-Adaptive Theming
The app theme adapts automatically to current weather conditions.
This is a core differentiator — no other activity or weather app does this.
Theme is set on app open based on Tomorrow.io current conditions.
User can override in Settings (adaptive is default).

### Sunny / Clear Theme
- Background: #FFF8EE
- Primary: #F5A623
- Accent: #FF6B35
- Text: #1A1A1A
- Mood: warm, energetic, get outside now

### Overcast / Cloudy Theme
- Background: #F0F2F5
- Primary: #4A9EFF
- Accent: #7B8FA1
- Text: #2C3E50
- Mood: calm, considered, still a good day

### Rainy Theme
- Background: #1A2332
- Primary: #4A9EFF
- Accent: #64B5F6
- Text: #E8EDF2
- Mood: cozy, indoor-friendly, contemplative

### Snowy Theme
- Background: #F7F9FC
- Primary: #90CAF9
- Accent: #546E7A
- Text: #263238
- Mood: crisp, clean, minimal

### Night Theme (time-based, overrides weather after sunset)
- Background: #0D1117
- Primary: #4A9EFF
- Accent: #F5A623
- Text: #E8EDF2
- Mood: premium, calm, stargazing

### Shared Design Tokens (all themes)
- Border radius cards: 16px
- Border radius bottom sheets: 24px
- Border radius buttons: 12px
- Spacing base unit: 4px
- Animation standard: 300ms
- Theme transition: 500ms
- Haptic on activity save: Medium impact
- Haptic on condition toggle: Light impact
- Haptic on condition match: Success notification

All tokens defined in lib/core/theme.dart.
Never hardcode any value anywhere in the codebase.

## App Store Details
- Primary category: Health & Fitness
- Secondary category: Lifestyle
- Monetization: Free, no IAP at launch
- Google Play: Submit simultaneously with App Store

## Auth
- Email + password (Supabase Auth)
- Magic link / passwordless email (Supabase Auth)
- Sign in with Apple (deferred — pending Apple Developer account approval)
- Sign in with Google (deferred — add alongside Apple Sign In)

## Onboarding Flow (6 screens)
1. Value proposition — single bold statement, one CTA
2. Location permission — plain English explanation before system prompt
3. Notification permission — plain English explanation before system prompt
4. Booking integrations — show OpenTable and future partners, incentivize sign in
5. Auth — email/password, magic link, skip option
6. First activity creation — walk directly into creating first activity

Never send a user to an empty screen.
Never skip the first activity creation step.

## Supabase Tables — App (read/write)
- activities
- condition_profiles
- condition_profile_history
- categories
- notification_preferences

## Supabase Tables — Intelligence (write-only from app)
- behavioral_events — every meaningful user interaction
- monetization_events — partner and affiliate interactions

## Behavioral Event Logging — NON-NEGOTIABLE
Every screen must log to behavioral_events.
Every event must include all four jsonb context objects.
Never log an event with missing fields.
Never store precise coordinates — bucket to ~1 mile radius.

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
- theme_override_set
- booking_integration_viewed
- auth_completed
- auth_skipped
- onboarding_completed

### Required jsonb — conditions_at_event
{
  "temp_c": 0.0,
  "temp_f": 0.0,
  "precipitation_probability": 0,
  "wind_kph": 0.0,
  "uv_index": 0,
  "air_quality_index": 0,
  "weather_theme": "",
  "forecast_window_hours": 0
}

### Required jsonb — geographic_context
{
  "metro": "",
  "city": "",
  "state": "",
  "country": "US",
  "lat_bucketed": 0.000,
  "lng_bucketed": 0.000,
  "timezone": ""
}

### Required jsonb — temporal_context
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

### Required jsonb — session_context
{
  "platform": "ios",
  "app_version": "",
  "active_theme": ""
}

## Screen Build Status
- Phase 1 (Environment + Design System): COMPLETE
- Phase 2 Screen 1 (Onboarding / Auth — 6 screens): COMPLETE
- Phase 2 Screen 2 (Activity Library): NOT STARTED
- Phase 2 Screen 3 (Add / Edit Activity): NOT STARTED
- Phase 2 Screen 4 (Browse Right Now): NOT STARTED
- Phase 2 Screen 5 (Settings / Account): NOT STARTED
- Phase 3 (Polish Pass): NOT STARTED
- Phase 4 (App Store + Google Play Submission): NOT STARTED

## Workflow Protocol — MANDATORY

### Step 1 — Session Start Checklist
Every Claude Code session must begin with:
1. Read CLAUDE.md and AGENTS.md in full
2. Verify all environment variables present in .env
   — If any missing: STOP and prompt reviewer
3. State which screen is being built
4. Confirm current build status matches CLAUDE.md

### Step 2 — Planning Mode
Before writing any code produce a numbered execution plan:
- What will be built, file by file
- What depends on what, in order
- Which behavioral events logged and at which interactions
- What tests prove each piece works
- Any decisions or information needed from reviewer

DO NOT write any code until reviewer explicitly approves the plan.

### Step 3 — Decision Prompts
STOP and prompt reviewer whenever:
- Two or more valid implementation approaches exist
- A UI pattern not specified in the design system
- Behavioral event coverage for an interaction is ambiguous
- Any decision could affect intelligence platform data quality
- Anything in the codebase contradicts these instructions

### Step 4 — Build One Step At A Time
After plan approval:
- Build one logical unit at a time
- Write tests alongside code — never after
- Confirm each step passes before moving to next
- Never proceed past a failing test

### Step 5 — Screen Completion Gate
A screen is complete only when ALL of the following are true:
- UI matches active weather theme correctly
- Theme transitions animate at 300-500ms
- All behavioral events log with full jsonb context
- active_theme captured in every session_context
- Widget tests pass
- Integration tests pass
- iOS simulator build runs clean
- Android build runs clean
- Reviewer has explicitly approved

Update Screen Build Status after each completion.

## Blue Chip Quality Standards
Every screen must meet all of these:
- Weather-adaptive theme applied correctly
- Physics-based animations on all transitions
- Haptic feedback on all key interactions
- Loading skeletons on all async operations — never spinners
- Contextual empty states — never a blank screen
- Accessibility labels on all interactive elements
- Typographic hierarchy consistent with active theme
- No hardcoded values anywhere

## Professionalism Rules
- No personal names in code or comments
- No email addresses anywhere in codebase
- No internal references in user-facing text
- No placeholder copy in production code
- User-friendly error messages — never expose technical details
- All copy polished and brand-consistent with OutAbout tone

## Installed Skills
- frontend-design (Anthropic)
- supabase (Supabase)
- supabase-postgres-best-practices (Supabase)
- security-guidance (Anthropic)
- Skill Development (Anthropic)
- Agent Development (Anthropic)
- Hook Development (Anthropic)
- find-skills (Vercel Labs)

## What Claude Code Must Never Do
- Hardcode any color, spacing, or text style value
- Use a spinner — always use a loading skeleton
- Leave any empty state blank
- Log a behavioral event with missing jsonb fields
- Store precise user coordinates
- Include personal info or developer names anywhere
- Proceed past a failing test
- Make architectural decisions without prompting reviewer
- Write code before plan is approved
- Skip weather-adaptive theme on any screen
