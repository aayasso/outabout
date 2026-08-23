# Design -- Accessibility Audit
# Created: 2026-05-19
# Reconciled and executed: 2026-08-23
# Status: complete

## 1. Token changes

Two fields added to `WeatherThemeColors`, one value changed in two palettes.
`primary`, `accent`, `background`, `text`, `surface`, `cardBackground` and
`divider` are unchanged everywhere.

### 1.1 `onPrimary` — ink on a primary fill

White ink on `colors.primary` failed on all three light palettes. One root
cause behind six widgets: the FAB icon, `ElevatedButton` labels, the selected
`SegmentedButton` label, the outcome prompt's "Yes" chip, the active theme
chip, and the `Switch` active thumb.

| Theme | primary | ink before | before | ink after | after |
|---|---|---|---|---|---|
| sunny | #F5A623 | white | 2.03:1 | #1A1A1A | 8.59:1 |
| overcast | #4A9EFF | white | 2.75:1 | #0D1117 | 6.87:1 |
| rainy | #4A9EFF | black | 7.63:1 | #000000 | 7.63:1 |
| snowy | #90CAF9 | white | 1.75:1 | #263238 | 7.52:1 |
| night | #4A9EFF | black | 7.63:1 | #000000 | 7.63:1 |

Not derived from `Brightness`: the light palettes carry pale primaries, so
`isDark ? black : white` is exactly the rule that produced the failures.

### 1.2 `primaryInteractive` — primary restated as a foreground

For text, icons, focus rings, slider tracks and thumbs, and selected chip
borders. Evaluated against three backgrounds: the flat background, the flat
card, and the worst-case Schedule composite (`surface` 0.90 over the
lightest veil over the worst scene stack).

| Theme | value | vs background | vs card | vs schedule composite |
|---|---|---|---|---|
| sunny | #A05E00 | 4.86:1 | 5.13:1 | 4.80:1 |
| overcast | #1565C0 | 5.12:1 | 5.75:1 | 5.36:1 |
| rainy | #7DBBFF | 7.84:1 | 6.29:1 | 5.83:1 |
| snowy | #1565C0 | 5.45:1 | 5.75:1 | 5.44:1 |
| night | #4A9EFF | 6.87:1 | 6.28:1 | 5.66:1 |

Rainy is **not** "same as primary" as the 2026-05-19 draft proposed.
`#4A9EFF` reaches only 4.26:1 on the Schedule card composite — a surface
that did not exist when the draft was written.

### 1.3 `textSecondary` darkened on two palettes

| Theme | before | after | vs bg before | vs bg after | vs schedule composite |
|---|---|---|---|---|---|
| overcast | #6B7B8D | #5A6978 | 3.87:1 | 5.02:1 | 5.25:1 |
| snowy | #607D8B | #506A78 | 4.14:1 | 5.42:1 | 5.41:1 |

## 2. Contrast over the animated scene

The Schedule tab stacks, bottom to top: `colors.background`, the scene, the
graded veil, then content. `_SceneVeil` grades the scrim — `alpha * 0.5` at
the top, `alpha` at 0.42, `alpha + 0.22` at the foot — so the **top** of the
list is the worst case, and that is where the "Today" section sits.

Veil alphas (`SceneVeilAlpha`): sunny 0.26, overcast 0.24, rainy 0.34,
snowy 0.24, night 0.20, fog 0.46.

Worst-case scene = overlapping large-area elements (two or three stacked
clouds; the sun's outer, mid and core glow; the moon disc and halo).
Particles are excluded: a raindrop is 3pt wide and no glyph sits wholly on
one.

### Text painted directly on the veil — the finding

`_EmptyText` (both day and activity empty states), `_ActivityHeader` and
`_ScheduleEmptyState` had no surface behind them.

| Theme | `text` 16px/600 | `textSecondary` 12px |
|---|---|---|
| sunny | 8.27 PASS | **3.13 FAIL** |
| overcast | 4.94 PASS | **1.95 FAIL** |
| rainy | 4.74 PASS | **2.41 FAIL** |
| fog | **4.08 FAIL** | **2.07 FAIL** |
| snowy | 7.16 PASS | **2.38 FAIL** |
| night | **3.79 FAIL** | **1.45 FAIL** |

**Fix:** `_sceneSurface()` in `schedule_tab.dart` — the same
`surface @ _scheduleSurfaceOpacity` (0.90) container `_DayHeader` already
used, now shared by the empty states, the activity-first header and the
whole-tab empty state. On that surface every reading lands between 4.98:1
and 13.4:1. No veil alphas were changed; the scene looks as the animations
sprint tuned it.

## 3. VoiceOver

### 3.1 The Schedule card collapsed the whole day section

`Semantics(button: true, label: ...)` **without `container: true` creates no
node** — it annotates whichever node the parent chain already provides. That
was the sliver item covering the entire `_DaySection`, so one button
announced nine merged lines:

```
"Today / Cloudy / H: 78°F / L: 56°F / 20% / 6 mph /
 Activity: Morning run / Morning run /
 Did you go to Morning run today? / Did you go?"
```

**Fix:** `container: true` plus `explicitChildNodes: true` on the card, the
tap action declared on the node, and the `GestureDetector` beneath it set to
`excludeFromSemantics` so the two do not both offer a tap. The day header
became its own `header: true` node; the chevron and the duplicated activity
name are excluded. Verified on device — see Verification.

### 3.2 Buttons that announced no action

`Semantics(button: true, excludeSemantics: true, child: InkWell(...))`
drops the InkWell's tap along with the rest of the subtree, leaving a node
flagged `isButton` with no action. Present in the outcome chips, the Find &
book provider rows and the theme chips. **Fix:** `onTap:` declared on the
Semantics wherever the subtree is excluded.

### 3.3 Labels announced twice

Theme chips read "Theme: Night / Night"; legal rows read "Privacy Policy,
opens in browser / Privacy Policy"; settings rows read the trailing value
twice. **Fix:** `excludeSemantics: true` on the wrapper, and the trailing
widget excluded when the row states a `value:`.

### 3.4 The dialog hint floated onto the dialog

`Semantics(hint:)` wrapped around the confirm button had no container, so
the hint merged onto the `AlertDialog` node: VoiceOver announced "Dimmed.
Type DELETE..." on entering the dialog while the button said nothing.
**Fix:** the hint moved *inside* the button, wrapping its child, so it
merges into the button's own node.

### 3.5 Sliders announced the wrong number entirely

Neither slider had a `semanticFormatterCallback`. Flutter's default is
percentage of range, so a 50 °F setting was announced as **"20%"**.
**Fix:** formatters that render the unit on screen. Verified on device:
"59 °F", increases to "61 °F".

### 3.6 Other

Condition rows merged into one node (`MergeSemantics`), the iOS Settings
pattern: "Temperature, on, switch button". `PrecipitationSection` gained a
group label. `_MatchingDayBadge` gained a spoken label because the weather
icon is its only carrier of the condition. `ProgressDots` gained "Step N of
6". The day header's precipitation and wind figures gained names, because
`OutAboutColors.cold`/`.sunny`/`.rainy` sit at 1.73-2.75:1 on a light card.
`WeatherSceneBackground` contributes no semantics.

## 4. Touch targets

| Control | Before | After |
|---|---|---|
| Theme override chip ("Adaptive") | 106.4 x **24.0** | 48pt target, 32pt pill |
| Theme override chip ("Sunny") | 74.5 x **26.0** | 48pt target, 34pt pill |
| Precipitation segment | 400 x 48.0 | unchanged, already compliant |
| Settings rows | >= 48 | unchanged |
| Outcome chips, dismiss | >= 48 | unchanged |

The draft's other two tap-target items targeted code deleted in `3d3e4f2`.

## 5. Dynamic Type

Measured at `textScaler` 1.0 / 1.5 / 2.0 / 3.0 (AX5). Two real overflows,
both only at 3.0:

| Surface | Overflow at AX5 | Fix |
|---|---|---|
| `_DayHeader` second row | **92px and 106px** | `Wrap` instead of `Row`; each stat its own widget |
| `TemperatureSection` min/max row | **71px** | `Flexible` on both end labels |
| `_DeleteAccountDialog` | content did not scroll | `scrollable: true` |
| Find & book sheet | capped at half-screen | `isScrollControlled: true` |

## 6. Reduce Motion

Before this work, `weather_scene_background.dart` was the only consumer of
the platform flag. Its three-way check (`reduceMotion || disableAnimations
|| MediaQuery`) was correct and was lifted verbatim into `lib/core/motion.dart`
rather than reinvented — iOS reports only the first of the three.

| Surface | How it honours the flag |
|---|---|
| 6 shimmer skeletons | `MotionSafeShimmer` renders the still block |
| 16 entrance chains | `animateSafely()` -> `Animate(value: 1, autoPlay: false)` |
| Route transitions | `_fadeTransitionPage` returns the child directly |
| Theme cross-fade (500ms) | `motionDuration()` |
| `ConditionSection` cross-fade | `motionDuration()` |
| `ProgressDots` | `motionDuration()` |

`animateSafely` pins the chain at completion rather than stopping it: a
stopped `fadeIn` is an invisible widget.

## 7. Deliberately not changed

- **Veil alphas.** The scene is as the animations sprint tuned it; the fix
  was a surface under the text, not a heavier scrim.
- **`primary` fills.** A filled button is identified by its label, and the
  label now clears 6.8:1 everywhere.
- **`ColorScheme.onSecondary`.** `secondary` is declared but never painted
  in OutAbout — `accent` is used only for scene painting and icon tints. The
  latent value (white on sunny `#FF6B35` = 3.10:1) is recorded here rather
  than fixed, because there is no rendered surface to fix.
- **Weather icon tints in `_DayHeader`.** The condition name is spelled out
  beside the glyph, so the tint is supplemental. In `_MatchingDayBadge`,
  where the icon stands alone, a spoken label was added instead.

## 8. Verification

`flutter analyze` clean, `flutter test` green at 546 tests (480 before).

New suites under `test/accessibility/`: `contrast_test.dart` (the tables
above, including the composite), `semantics_test.dart`, `tap_target_test.dart`,
`dynamic_type_test.dart`, `reduce_motion_test.dart`.

Each regression test was confirmed to fail against the pre-fix code before
being kept; the overflow harness was checked against a deliberate overflow
first.

Device pass on iPhone 16e (iOS 26.3), semantics enabled, with the live tree
dumped at each step: Schedule, Settings, delete dialog (armed, then
cancelled), Find & book sheet, Add Activity. **Limit:** the tree is what iOS
turns into VoiceOver elements; the announcements are transcribed from it,
not captured as audio. Onboarding was covered by the semantics suite rather
than on device, because the simulator session is signed in.
