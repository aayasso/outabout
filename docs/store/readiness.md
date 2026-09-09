# Store Readiness Report

Branch: `prep/store-readiness`
Date: 2026-09-09

Ranked by what blocks the App Store submission first,
then Play.

---

## Blockers — yours, not mine

### B1. No DEVELOPMENT_TEAM (iOS)

CODE_SIGN_STYLE is Automatic with no team set in
`project.pbxproj`. No provisioning profile resolves,
archiving fails. Needs an Apple Developer Program
membership linked in Xcode.

**Blocks:** App Store archive, TestFlight upload.

### B2. No android/key.properties (Android)

The release signing config is guarded by
`hasReleaseKeystore` in `build.gradle.kts:18`. When
the file is absent the bundle is built **unsigned** —
it does not fail loudly. This is known behavior: the
build succeeds but the artifact is not uploadable to
Play Console. Needs an upload keystore created and
`key.properties` populated.

**Blocks:** Play Console upload.

---

## App Store — remaining gaps (ranked)

### S1. Screenshots — MISSING

Zero screenshots exist in the repo. App Store requires
at minimum:
- iPhone 6.9" (1320x2868): 1-10
- iPhone 6.7" (1290x2796): 1-10
- iPad 13" (2064x2752): 1-10 (if supporting iPad)

**Action:** Capture on device or simulator, or use
Fastlane snapshot.

### S2. Store metadata — MISSING

No App Store description, keywords, promotional text,
or support URL defined in the repo. These are entered
in App Store Connect manually. Inventory:
- App name: "OutAbout" (from CFBundleDisplayName)
- Subtitle: not defined
- Description: not written
- Keywords: not written
- Promotional text: not written
- Support URL: not defined (contact is
  support@slowma.ai per terms page)
- Marketing URL: optional, not defined

### S3. Age rating questionnaire

Filled in App Store Connect. OutAbout has no violence,
gambling, horror, alcohol, drugs, sexual content, or
user-generated content visible to others. Expected
rating: 4+ (Everyone).

### S4. Privacy policy — location description incomplete

The hosted privacy policy described location as used
only for weather — it omitted the analytics use and
did not clarify that Tomorrow.io receives only
approximate coordinates. Fixed in this branch.
Calendar wording was already correct (write-only).

### S5. Onboarding step 3 — FIXED

OpenTable Connect button, both "More coming soon"
cards, and the Skip button removed. Step 3 is now
purely informational: it names the partners OutAbout
hands off to (AllTrails, OpenTable, Playtomic,
Mindbody) with only a Continue button.

---

## Play Store — remaining gaps (ranked)

### P1. Screenshots — MISSING

Same as S1. Play requires minimum 2 screenshots,
320-3840px per side.

### P2. Feature graphic — MISSING

Play requires a 1024x500 PNG/JPEG. None exists.

### P3. High-res icon — needs verification

Android mipmap icons go up to xxxhdpi (192x192). Play
Console requires a 512x512 high-res icon uploaded
separately (not pulled from the APK). The 1024x1024
iOS icon may be usable as a source.

### P4. Store metadata — MISSING

Same as S2. Play Console requires:
- Short description (80 chars max)
- Full description (4000 chars max)
- App category
- Content rating (IARC questionnaire)

### P5. Privacy policy — same as S4

### P6. Onboarding step 3 — FIXED (same as S5)

---

## Passed

| Check | Evidence |
|---|---|
| iOS release compiles | `flutter build ios --release --no-codesign` -> 30.7MB Runner.app |
| Android release compiles | `flutter build appbundle --release` -> 48.0MB app-release.aab (unsigned) |
| R8/ProGuard | No shrink/minify failures; ProGuard rules cover all native plugins |
| Tree-shaking | Icons reduced 99%+; no missing asset errors |
| PrivacyInfo.xcprivacy | Declares all 5 collected types; CoarseLocation now lists Analytics purpose |
| Widget PrivacyInfo.xcprivacy | Correct: collects nothing, 1C8F.1 only |
| ITSAppUsesNonExemptEncryption | `false` in Info.plist |
| READ_CALENDAR | Not in merged manifest; no Data Safety declaration needed |
| WRITE_CALENDAR | Present; matches write-only code behavior |
| Background location | Not requested; not declared |
| POST_NOTIFICATIONS | Declared |
| Location purpose strings | Present and specific (iOS) |
| Calendar purpose strings | Present — write-only wording (iOS) |
| Account deletion | In-app + server-side + web URL |
| Coordinate bucketing | All 4 outbound paths verified — precise location never leaves device |
| Privacy policy URL | Loads, is substantive |
| Terms of service URL | Loads, is substantive |
| Legal links in app | Settings tab, properly wired |
| Error states | All use friendly copy, no raw exceptions |
| Navigation | All screens have exit paths |
| No debug UI strings | Confirmed |
| compileSdk/targetSdk 36 | Set in build.gradle.kts |
| minSdk 24 | Set in build.gradle.kts |
| iOS deployment target 14.0 | Set in Podfile and project.pbxproj |
| iOS app icons | All 15 sizes present including 1024x1024 |
| Sign in with Apple | Not required (no OAuth/social login) |
| check-weather edge function | Done, deployed as v15 (not re-verified) |

---

## Changes made in this session

| File | Change |
|---|---|
| `lib/data/repositories/weather_repository.dart` | Bucket lat/lng before Tomorrow.io calls; accept injectable http.Client |
| `test/data/repositories/weather_repository_test.dart` | New: 3 tests asserting bucketed coordinates in request URLs |
| `ios/Runner/PrivacyInfo.xcprivacy` | Added Analytics purpose to CoarseLocation entry |
| `docs/store/app-privacy.md` | New: App Store Connect privacy form answers |
| `docs/store/data-safety.md` | New: Play Console Data Safety form answers |
| `docs/store/readiness.md` | New: this file |

---

## Follow-up: technical debt

`bucket()` is defined in
`lib/data/models/behavioral_event.dart:9` and is now
used by both `behavioral_event_service.dart` and
`weather_repository.dart`. It should move to a shared
core helper (e.g. `lib/core/geo.dart`) in a later
cleanup so the weather repository does not import a
behavioral-event model file for a math function.
