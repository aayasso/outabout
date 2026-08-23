# Design -- Test Hardening
# Created: 2026-05-19 (as "test_coverage")
# Reconciled and executed: 2026-08-23
# Status: complete

## 1. Bugs found and fixed

Ranked by user impact. Items marked **(simulator)** were found by driving the
app, not by reading it.

### 1.1 Clearing every condition never took effect
`activity_repository.dart` — `updateWithConditions` had `if (profile != null)
{ upsert }` and no `else`. Turning off Temperature, Precipitation and Wind and
saving reported success and fired a success haptic, but the old
`condition_profiles` row survived, `fetchForUser`'s join handed it straight
back, and the edit form repopulated its sliders from it on re-entry.
**Reproduced end to end in the simulator**: cleared Running's 88–99°F, saved,
reopened — the toggle was on again at 88–99°F. Fixed with a delete branch.

`add_activity_screen.dart` disagreed in the other direction — it *always*
inserted a profile, even with all three flags false. Now it writes no row, the
same as the edit screen.

### 1.2 Activities with no conditions claimed a weather match **(simulator)**
`evaluateDayMatch` returns true for a null profile and falls through to true
when nothing is enabled — correct as a *filter*, but the schedule rendered a
green success rail and VoiceOver said "conditions match Today". Four of six
activities on the test account were in this state.

Fixed with `ConditionProfile.isConstraining`, which is false for a profile
with nothing enabled *and* for `tempEnabled` with both bounds null (a case
`evaluateDayMatch` also waves through). The card keeps its place on every day
— nothing can rule it out — but takes a neutral rail and reads "no weather
conditions set".

### 1.3 Stale forecast presented as today's plan
`dailyForecastProvider` served the cache on any failure and
`cachedForecastFetchedAtKey` was written on every success and **never read**.
`schedule_tab.dart`'s `_dayLabel` derived "Today"/"Tomorrow" from *list
position*, so an offline Wednesday showed Monday's forecast under "Today" —
while `activity_detail_screen.dart` compared real dates and correctly
disagreed.

Fixed three ways: `dailyForecastProvider` returns a `ForecastSnapshot` that
carries `servedFromCacheAt`; day labels are derived from each day's own date
against `nowProvider`; and a `_StaleForecastBanner` says which day the shown
forecast was saved on. An undatable cache is now refused rather than vouched
for.

### 1.4 Hero tag collision on every route transition **(simulator)**
```
There are multiple heroes that share the same tag within a subtree.
... multiple heroes had the following tag: <default FloatingActionButton tag>
```
Thrown 4 times during a short walk. `StatefulShellRoute.indexedStack` keeps
all three branches mounted, so the Schedule and Activities FABs were in the
tree together with the default tag. Fixed with explicit `heroTag`s. Zero
exceptions on the verification run.

### 1.5 The schedule error state **(simulator)**
Three defects in one screen:
- It stayed in the error state indefinitely after connectivity returned —
  pull-to-refresh was the only way out, and it has no accessible equivalent.
- It said "Couldn't load forecast" when the log showed the **activities**
  fetch was what failed and the forecast had come from cache.
- It was a thin banner on an otherwise blank screen with no retry control,
  while the Activities tab has had a "Try again" button all along.

Fixed: the banner names what actually failed (including a distinct message for
a missing location, which pull-to-refresh could never fix) and carries a
"Try again" button that invalidates both providers.

### 1.6 `behavioral_events` geography was empty and false
`buildPayload` hardcoded `latBucketed: 0.0, lngBucketed: 0.0, country: 'US'`
and empty metro/city/state, while `userLocationProvider` already held real
coordinates. Every client-written row was geographically useless, and actively
wrong for non-US users.

Now built by `buildGeographicContext` from the saved location, bucketed to two
decimal places (~1.1 km) by the existing `bucket()`. **This means coarse
location now leaves the device where zeros did before.** Absence reports as
empty, not as `'US'` — "not collected" and "United States" must not be the
same value. The same hardcoded `'US'` fallback was removed from
`LocationService.mapPlacemark`.

### 1.7 Analytics theme frozen at `sunny`
`ref.watch(weatherThemeProvider.notifier)` only rebuilds when the notifier
*instance* is replaced, and the weather sync mutates its state in place — so
`activeThemeName`, captured at construction, stayed at whatever the theme was
on first build for the whole session. Both `conditions_at_event.weather_theme`
and `session_context.active_theme` were wrong once the weather adapted. The
service now takes `String Function()` and reads at log time.

### 1.8 Session boundaries
- `router.dart` called `clearUserScopedState(ref)` **unawaited**, and its
  first statement is an `await` — so it returned immediately and
  `notifyListeners()` fired, running the redirect, before a single pref was
  removed. The comment claiming the opposite ordering is now true:
  `AuthRefreshNotifier` takes `Future<void> Function(AuthState)` and awaits it.
- `outcomePromptProvider` survived sign-out. The pref was cleared but the
  notifier — which loads once in its constructor — was not invalidated, so the
  previous user's answered prompts stayed in memory and the next
  `markHandled` wrote them back into the just-cleared key. Added to
  `invalidateUserScopedProviders`.

### 1.9 Notification path
- `data?['activity_id'] as String?` threw a `TypeError` inside the OneSignal
  click listener for any non-string id: no navigation, no event, and an
  unhandled zone error. Extracted as
  `NotificationService.parseActivityId`, which accepts numbers, rejects
  structured values, and treats empty/whitespace as absent.
- A deep link arriving before onboarding or auth completed was discarded —
  after `notification_opened` had already been logged, so the funnel recorded
  an open that produced no screen. `pendingDeepLinkProvider` now holds it and
  the redirect replays it once a session exists.

### 1.10 Two Settings writes had no error handling at all
The temperature-unit update and the sign-out both threw straight into the
zone. The unit change silently did nothing; the sign-out left the user on a
Settings tab that looked untouched — *after* `clearUserTag()` had already
detached their push targeting. Both now catch, log, and surface a SnackBar,
and `clearUserTag()` runs only after the session is actually gone.

### 1.11 `onboarding_completed` was dropped on every first run
`log()` returned early with no session and did not even `debugPrint`. Five of
its six call sites are on onboarding steps 1–3, which run **before** the auth
page at step 5 — so the funnel those events exist to measure was empty.

**Approach taken: buffer and flush** (the alternative was moving the logging
to a post-auth point). Buffering keeps each event's payload and its `step`
value at the moment it happened; moving the call sites would have meant either
collapsing six events into one or re-deriving each step's state at step 5.
`log()` now queues on the no-session path, capped at
`maxPendingEvents` (50, oldest dropped), and the router flushes on
`AuthChangeEvent.signedIn`. Buffered rows carry their original `occurredAt`,
so temporal context describes when the step was taken. **No placeholder user
id is ever substituted** — a test asserts nothing reaches the table until a
real id exists.

### 1.12 Smaller
- `activities_tab.dart` wind chip branched the label on `== 'C'` and the value
  on `== 'F'`; any other stored unit printed a km/h number labelled "mph".
- A categories fetch failure rendered `SizedBox.shrink()`, so the filter row
  vanished and a user with eight categories saw what a user with none saw.
  Now shows a message and a retry.
- `activity_detail_screen.dart` bound the save exception and never logged it.
- `add_activity_screen.dart` used `currentUser!.id`; an expired session
  surfaced as "Could not save activity. Please try again.", advice that could
  never work. Now says the session ended.
- `weekOfSeason` used `difference().inDays`, which a spring-forward transition
  shortens to `6d 23h` — and US DST starts inside the spring window, so spring
  week boundaries were wrong every year. Now counts calendar days.
- Removed dead `condition_match.dart`; removed comments claiming the
  onboarding pages were placeholders and that filter events fired at call
  sites they do not.

### 1.13 Not fixed — for your decision

**Five allowlisted event types have no call site anywhere in `lib/`:**
`condition_match_notified` (server-only, written by the edge function),
`app_opened_post_notification`, `partner_impression_viewed`,
`partner_cta_clicked`, `notification_preference_changed` (its feature was
deleted in `49760bf`). Each is currently covered only by a membership
assertion. `partner_impression_viewed` is the notable one: the Find & book
sheet logs `affiliate_link_clicked` on tap but never the impression, so
click-through rate is uncomputable. **No UI was wired for these** — they need a
product decision: wire them, or drop them from the allowlist.

**Also left alone, deliberately:** `airQualityIndex`, `daysSinceLastMatch`,
`daysSinceActivityCreated` and `consecutiveMatchCount` are permanently zero.
Filling them needs data the client does not have; they are noted rather than
faked.

## 2. Vacuous assertions found and repaired

### 2.1 Tests that asserted the test file's own code
`test/services/location_service_test.dart` declared
`_TestableLocationService.testMapPermission`, a verbatim re-implementation of
the switch in `lib`, and `_InjectablePlacemarkService`, which `@override`s
`reverseGeocode` entirely. Ten tests asserted those copies; the production
methods were never called. `_mapPermission` was private, so the suite could
not reach it — the copy was the workaround.

Fixed in `lib`: `mapPermission` is now `@visibleForTesting`, and the pure part
of `reverseGeocode` is extracted as `mapPlacemark` (the method itself calls a
platform channel, which is what drove the workaround). The test file's fakes
are gone; all 18 tests call production code. **Verified**: inverting
`deniedForever` in `lib` now fails a test, where it previously did not.

### 2.2 By class

| Class | Where | Repair |
|---|---|---|
| `isNotNull` / `isA<Function>` on non-nullables | `notification_service_test` ×8, `theme_test` ×5, `location_service_test` ×3 | Replaced with behaviour. The notification ones became real payload-parsing tests. |
| Asserted the test's own fixture | `home_screen_test.dart:84` — `find.text('Today')` matched only the stub route the test declares; the real label is `'Schedule'` | Points at the real label |
| Hardcoded copies of `lib` constants | `contrast_test.dart` copied `SceneVeilAlpha` and the scene alphas | Imports `SceneVeilAlpha`. Noted honestly in the file: the 0.90 card dominates the composite, so these margins are wide by construction. |
| Duplicate group with a weaker threshold | `contrast_test.dart` — `onPrimary` checked at AA-large after AA-normal | Removed |
| "Nothing threw" with no positive assertion | all 16 in `dynamic_type_test` | Each now also asserts the content rendered |
| Name/body mismatch | `booking_provider_test` "every rule resolves to at least one provider" never called `providersFor`; `condition_profile_test` "round-trip" never round-tripped | Bodies now do what the names say |
| Declared-type tautologies | `providers_test` `isA<Provider<SupabaseClient>>()` | Asserts the provider resolves to the injected client |
| Token restating itself | `theme_test` card/button radius read the token on both sides | Asserts the literal *and* the token |

### 2.3 Checked and clean
All 226 `find.text` / `find.bySemanticsLabel` / `find.byTooltip` literals were
cross-checked against `lib/` — apart from the `home_screen_test` case above,
none asserts a string the app never renders. No test targets a deleted `lib/`
file.

### 2.4 Known remaining weakness
45 theme-parameterised widget tests read their expected value from
`WeatherThemeColors.forTheme(theme)` — the same call the widget makes — and
assert with `any(...)` over every `ColoredBox` in the tree. They are
change-detectors with no teeth. Left in place: the palettes *are* pinned to
literals in `theme_test.dart`, so the values are covered; collapsing 45 near
duplicates is a refactor of its own and was not smuggled into this pass.

## 3. Coverage added

| Area | File | What it pins |
|---|---|---|
| Notification path | `notification_service_test.dart` | String, numeric, null, missing, empty, whitespace and structured payloads |
| Matching | `match_reason_test.dart` (new, 19 tests) | `isConstraining`; unconstrained profiles matching but not claiming a match; temp/wind boundary equality; bidirectional precipitation; the dry threshold; null and legacy stored levels agreeing with `normalize`; conjunction across all three |
| Data writes | `activity_repository_test.dart` (new) | A cleared profile is deleted, not skipped; a live one is upserted, not deleted |
| Session boundaries | `user_state_teardown_test.dart` | Every pref gone when the future resolves; the handled-prompt set not surviving; `onEvent` completing before listeners are notified |
| behavioral_events | `behavioral_event_service_test.dart` | Pre-auth buffering, bounded queue, no placeholder id, flush drains once, buffered events keep their own timestamp, geographic context threaded and bucketed |

Every regression test above was run against the pre-fix code and confirmed to
fail before it was kept.

## 4. Verification

`flutter analyze` — no new issues over the 16 pre-existing infos.
`flutter test` — 551 → 576 passing.
Simulator re-run on iPhone 16e: the condition-clear now persists, the false
match rails are gone, and hero exceptions went 4 → 0.
