# Google Play Console — Data Safety Answers

Derived from the same code audit as `app-privacy.md`.
Every answer maps to a question in Play Console >
App content > Data safety.

---

## Does your app collect or share any of the required user data types?

**Yes.**

---

## Is all of the user data collected by your app encrypted in transit?

**Yes.** All network calls use HTTPS:
- Supabase client (`supabase_flutter`) — HTTPS only
- Tomorrow.io API — `https://api.tomorrow.io/...`
  (`weather_repository.dart:43-44, 68-69`)
- OneSignal SDK — HTTPS only

---

## Do you provide a way for users to request that their data is deleted?

**Yes.**
- In-app: Settings > Delete Account
- Web: `delete-account.html` (public URL)
- Server: `delete-account` edge function
  (`delete-account/index.ts:54-136`)

---

## Data types

### Location — Approximate location

- **Collected:** Yes
- **Shared:** Yes — with Tomorrow.io (weather API)
  for weather forecast retrieval
  (`weather_repository.dart:40-41, 66-67`)
- **Ephemeral:** No — stored in `user_locations`
  table for server-side weather checks
- **Required:** Yes — core feature depends on it
- **Purpose:** App functionality, Analytics
- **Justification:** Coordinates bucketed to 2dp
  (~1 mi) before any transmission. Used for weather
  forecasts and stored in behavioral event geographic
  context.

### Personal info — Email address

- **Collected:** Yes
- **Shared:** No — stored in Supabase Auth only,
  not sent to Tomorrow.io or OneSignal
- **Ephemeral:** No
- **Required:** No — anonymous auth is available
- **Purpose:** Account management
- **Justification:** Auth credential for email/OTP
  sign-in (`auth_service.dart:68-109`).

### App activity — App interactions

- **Collected:** Yes
- **Shared:** No
- **Ephemeral:** No
- **Required:** No — app functions without it
- **Purpose:** Analytics
- **Justification:** Behavioral events log user
  actions with weather/temporal/session context
  (`behavioral_event_service.dart:239-251`).
  De-identified on account deletion.

### App info and performance — (none)

- **Collected:** No
- **Justification:** No crash reporting SDK. No
  diagnostics collected.

### Device or other IDs — (none)

- **Collected:** No
- **Justification:** No advertising ID, no device
  ID. OneSignal manages its own push token
  internally; the app only sends a `user_id` tag
  (`notification_service.dart:36`).

---

## Data types NOT collected

Select "No" for all of the following:

| Category | Type | Reason |
|---|---|---|
| Financial info | All | Not collected |
| Health and fitness | All | Not collected |
| Messages | All | Not collected |
| Photos and videos | All | Not collected |
| Audio files | All | Not collected |
| Files and docs | All | Not collected |
| Calendar | Events | Write-only; no data leaves device |
| Contacts | All | Not collected |
| Web browsing | All | Not collected |
| Personal info | Name | Field exists but never written |
| Personal info | Phone | Not collected |
| Personal info | Address | Not collected |

### Calendar — READ_CALENDAR resolved

The merged release manifest (`build/app/intermediates/
merged_manifests/release/.../AndroidManifest.xml`)
contains only `WRITE_CALENDAR`. `READ_CALENDAR` is NOT
present — `device_calendar_plus_android` does not merge
it in. No calendar read declaration is needed on the
Data Safety form.

The app requests `CalendarAccessLevel.writeOnly`
(`calendar_service.dart:121`) and the iOS purpose
string states "It never reads your calendar."

---

## Data sharing

### Shared with third parties

| Partner | Data shared | Purpose |
|---|---|---|
| Tomorrow.io | Approximate location (bucketed to 2dp) | Weather forecast retrieval |

Tomorrow.io receives bucketed lat/lng in the query
string of API calls. No other user data is shared with
third parties.

OneSignal receives only a `user_id` tag for push
targeting — no location, no email, no content.

Supabase is the first-party backend (infrastructure
provider), not a third-party data recipient in Play's
definition.

---

## Privacy policy URL

`https://aayasso.github.io/outabout/privacy-policy.html`

---

## Ads

**Does your app contain ads?** No.

---

## Government and financial features

**Is your app a banking/financial/government app?** No.
