# App Store Connect — App Privacy Answers

Derived from `ios/Runner/PrivacyInfo.xcprivacy`, reconciled
against what the code actually sends. Every answer below maps to
one question in the App Privacy section of App Store Connect.

---

## Do you or your third-party partners collect data?

**Yes.**

---

## Third-party data recipients

| Partner | What it receives | File:line |
|---|---|---|
| Tomorrow.io (weather API) | Coarse location (lat/lng bucketed to 2dp, ~1 mi) | `weather_repository.dart:40-41, 66-67` |
| Supabase (backend) | Email, user ID, coarse location, activity content, behavioral events | `auth_service.dart:68`, `home_providers.dart:139-141`, `behavioral_event_service.dart:239-251` |
| OneSignal (push notifications) | User ID tag only; no location, no email | `notification_service.dart:36` |

Tomorrow.io is a third party receiving coarse location.
Coordinates are bucketed to 2 decimal places before the
request is constructed (`weather_repository.dart:40-41`
calls `bucket(lat)` / `bucket(lng)`). Precise location
never leaves the device.

---

## Data types collected

### 1. Contact Info — Email Address

- **Collected:** Yes
- **Linked to user:** Yes
- **Used for tracking:** No
- **Purposes:** App Functionality
- **Justification:** Email is the primary auth
  credential (`auth_service.dart:68-109`). Used for
  sign-in, magic-link OTP, and account recovery. Not
  used for marketing or analytics.

### 2. Location — Coarse Location

- **Collected:** Yes
- **Linked to user:** Yes
- **Used for tracking:** No
- **Purposes:** App Functionality, Analytics
- **Justification:** Coordinates bucketed to 2dp
  (~1 mi). Used for weather forecast lookups
  (`weather_repository.dart:40-41`) and stored in
  `user_locations` for server-side weather checks
  (`home_providers.dart:139-141`). Also sent in
  `behavioral_events.geographic_context` for analytics
  (`behavioral_event_service.dart:212`). Precise
  location is never collected or transmitted.

### 3. User Content — Other User Content

- **Collected:** Yes
- **Linked to user:** Yes
- **Used for tracking:** No
- **Purposes:** App Functionality
- **Justification:** Activity names, notes, and URLs
  entered by the user (`activity_repository.dart`).
  Stored for the user's own use. De-identified on
  account deletion (`delete-account/index.ts:122-125`).

### 4. Identifiers — User ID

- **Collected:** Yes
- **Linked to user:** Yes
- **Used for tracking:** No
- **Purposes:** App Functionality, Analytics
- **Justification:** Supabase auth UUID
  (`auth_service.dart`). Used to scope all data to the
  user and to key behavioral events. Set to NULL on
  account deletion for de-identification
  (`delete-account/index.ts:122-125`).

### 5. Usage Data — Product Interaction

- **Collected:** Yes
- **Linked to user:** Yes
- **Used for tracking:** No
- **Purposes:** Analytics
- **Justification:** Behavioral events
  (`behavioral_event_service.dart:18-72`) log user
  actions (activity viewed, condition toggled, booking
  link clicked, etc.) with weather, temporal, and
  session context. Used to understand feature usage and
  improve condition-matching. De-identified (not
  deleted) on account deletion.

---

## Data types NOT collected

| Type | Why not |
|---|---|
| Name | `profiles.display_name` exists but is never written by the app |
| Phone number | Not collected |
| Precise location | Coordinates bucketed to 2dp before leaving device |
| Health & fitness | Not collected |
| Financial info | Not collected |
| Sensitive info | Not collected |
| Contacts | Not collected |
| Browsing history | Not collected |
| Search history | Not collected |
| Photos or videos | Not collected |
| Audio | Not collected |
| Gameplay content | Not applicable |
| Advertising data | No ads, no ad identifiers |
| Diagnostics | No crash reporting SDK (no Sentry, no Crashlytics) |
| Device ID | Not collected; OneSignal manages its own push token internally |

---

## Tracking

**Does this app track users?** No.

`NSPrivacyTracking` is `false`. No advertising identifier
is collected. No data is shared with data brokers. No
cross-app or cross-site tracking occurs.

---

## Account deletion

**Does this app support account deletion?** Yes.

In-app: Settings > Delete Account
(`settings_tab.dart`).
Server-side: `delete-account` edge function hard-deletes
personal data, de-identifies behavioral/monetization
events (`delete-account/index.ts:54-136`).
Web fallback: `delete-account.html` (satisfies Apple
5.1.1(v) and Play's web-URL requirement).

---

## Privacy policy URL

`https://aayasso.github.io/outabout/privacy-policy.html`

Defined at `lib/core/providers.dart:104-105`.
Verified: loads, is substantive, mentions location,
email, Tomorrow.io, OneSignal, Supabase, account
deletion.

**Note:** The privacy policy says "calendar access
(read-only)" which contradicts the app's actual
behavior (write-only). This should be corrected in the
hosted document before submission.
