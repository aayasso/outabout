# OutAbout — Design System Reference
# ai_docs/design_system.md
# Living document. Update when tokens change.
# Source of truth: lib/core/theme.dart
# Last updated: 2026-04-28

## Core Concept — Dynamic Color System

OutAbout's color system is DYNAMIC. Colors change at runtime based on weather.
There is no single color palette — there are five, one per WeatherTheme.

**Always get colors from the provider. Never use static values in widgets.**

```dart
// In every widget build method — this is the only way
final colors = ref.watch(weatherThemeColorsProvider);
```

---

## WeatherThemeColors — Five Palettes

Each palette exposes: `background`, `primary`, `accent`, `text`,
`textSecondary`, `surface`, `cardBackground`, `divider`

### Sunny (light)
| Role | Token | Hex |
|---|---|---|
| background | `colors.background` | #FFF8EE |
| primary | `colors.primary` | #F5A623 |
| accent | `colors.accent` | #FF6B35 |
| text | `colors.text` | #1A1A1A |
| textSecondary | `colors.textSecondary` | #6B5B3E |
| surface | `colors.surface` | #FFFFFF |
| cardBackground | `colors.cardBackground` | #FFFFFF |
| divider | `colors.divider` | #E8DCC8 |

### Overcast (light)
| Role | Token | Hex |
|---|---|---|
| background | `colors.background` | #F0F2F5 |
| primary | `colors.primary` | #4A9EFF |
| accent | `colors.accent` | #7B8FA1 |
| text | `colors.text` | #2C3E50 |
| textSecondary | `colors.textSecondary` | #6B7B8D |
| surface | `colors.surface` | #FFFFFF |
| cardBackground | `colors.cardBackground` | #FFFFFF |
| divider | `colors.divider` | #D8DCE2 |

### Rainy (dark)
| Role | Token | Hex |
|---|---|---|
| background | `colors.background` | #1A2332 |
| primary | `colors.primary` | #4A9EFF |
| accent | `colors.accent` | #64B5F6 |
| text | `colors.text` | #E8EDF2 |
| textSecondary | `colors.textSecondary` | #9EACBA |
| surface | `colors.surface` | #243447 |
| cardBackground | `colors.cardBackground` | #243447 |
| divider | `colors.divider` | #2E3F52 |

### Snowy (light)
| Role | Token | Hex |
|---|---|---|
| background | `colors.background` | #F7F9FC |
| primary | `colors.primary` | #90CAF9 |
| accent | `colors.accent` | #546E7A |
| text | `colors.text` | #263238 |
| textSecondary | `colors.textSecondary` | #607D8B |
| surface | `colors.surface` | #FFFFFF |
| cardBackground | `colors.cardBackground` | #FFFFFF |
| divider | `colors.divider` | #E0E8EE |

### Night (dark)
| Role | Token | Hex |
|---|---|---|
| background | `colors.background` | #0D1117 |
| primary | `colors.primary` | #4A9EFF |
| accent | `colors.accent` | #F5A623 |
| text | `colors.text` | #E8EDF2 |
| textSecondary | `colors.textSecondary` | #8B949E |
| surface | `colors.surface` | #161B22 |
| cardBackground | `colors.cardBackground` | #161B22 |
| divider | `colors.divider` | #21262D |

---

## Static Semantic Colors (OutAboutColors)

These do NOT change with weather. Use for status and condition icons only.
Never use for backgrounds, text, or interactive elements.

### Status
```dart
OutAboutColors.success      // #34C759 — green
OutAboutColors.warning      // #FF9500 — orange
OutAboutColors.errorColor   // #FF3B30 — red
```

### Weather Condition Icon Tints
```dart
OutAboutColors.sunny    // #FFB800 — sun icon
OutAboutColors.cloudy   // #8FA3B1 — cloud icon
OutAboutColors.rainy    // #4A9EFF — rain icon
OutAboutColors.windy    // #6EC6CA — wind icon
OutAboutColors.cold     // #90CAF9 — cold/snow icon
OutAboutColors.hot      // #FF7043 — heat icon
```

---

## Typography

All methods take `WeatherThemeColors` as required parameter.
Text color is derived from the active theme — never hardcode it.

```dart
// Usage pattern — always pass colors
Text('Hello', style: OutAboutTypography.headingLarge(colors))
Text('Body', style: OutAboutTypography.bodyMedium(colors))

// Modify with copyWith if needed
Text('Muted', style: OutAboutTypography.bodyMedium(colors).copyWith(
  color: colors.textSecondary,
))
```

### Type Scale
| Method | Size | Weight | Letter Spacing | Notes |
|---|---|---|---|---|
| `displayLarge(colors)` | 34 | 700 | -0.5 | Hero headlines |
| `displayMedium(colors)` | 28 | 700 | -0.3 | Section headlines |
| `headingLarge(colors)` | 22 | 700 | -0.2 | Screen titles |
| `headingMedium(colors)` | 18 | 600 | -0.1 | Card titles |
| `headingSmall(colors)` | 16 | 600 | 0 | Sub-section titles |
| `bodyLarge(colors)` | 16 | 400 | 0 | Primary body, h=1.5 |
| `bodyMedium(colors)` | 14 | 400 | 0 | Standard body, h=1.5 |
| `bodySmall(colors)` | 12 | 400 | 0 | Captions, h=1.4, textSecondary |
| `labelLarge(colors)` | 15 | 600 | 0.1 | Button labels |
| `labelMedium(colors)` | 13 | 500 | 0.1 | Tags, chips, textSecondary |
| `labelSmall(colors)` | 11 | 500 | 0.3 | Overlines, textSecondary |

No custom fonts — system font stack (San Francisco on iOS, Roboto on Android).

---

## Spacing

```dart
OutAboutSpacing.xs   = 4.0
OutAboutSpacing.sm   = 8.0
OutAboutSpacing.md   = 16.0   // standard internal padding
OutAboutSpacing.lg   = 24.0   // section gaps
OutAboutSpacing.xl   = 32.0   // major sections
OutAboutSpacing.xxl  = 48.0
OutAboutSpacing.xxxl = 64.0
```

---

## Border Radius

```dart
OutAboutRadius.sm         = 8.0
OutAboutRadius.md         = 12.0
OutAboutRadius.lg         = 16.0
OutAboutRadius.xl         = 24.0
OutAboutRadius.full       = 999.0

// Semantic aliases — prefer these
OutAboutRadius.cards      = 16.0   // all cards
OutAboutRadius.bottomSheet = 24.0  // bottom sheets
OutAboutRadius.buttons    = 12.0   // buttons and inputs
```

---

## Shadows

Select based on current theme brightness:

```dart
final weatherTheme = ref.watch(weatherThemeProvider);
final isDark = weatherTheme.brightness == Brightness.dark;
// then:
boxShadow: isDark ? OutAboutShadows.cardDark : OutAboutShadows.card,
```

| Constant | Use |
|---|---|
| `OutAboutShadows.card` | Cards on light themes (sunny, overcast, snowy) |
| `OutAboutShadows.cardDark` | Cards on dark themes (rainy, night) |
| `OutAboutShadows.button` | Primary action buttons |
| `OutAboutShadows.elevated` | Bottom sheets, modals |

---

## Animations

```dart
OutAboutAnimations.standardDuration        // 300ms
OutAboutAnimations.themeTransitionDuration // 500ms
OutAboutAnimations.standardCurve           // Curves.easeInOut
```

Route transitions: FadeTransition + Curves.easeOutCubic + standardDuration.
Theme transition: AnimatedTheme in MaterialApp handles automatically at 500ms.
Custom animations: use `flutter_animate` package for declarative syntax.

---

## Haptics

```dart
OutAboutHaptics.onActivitySave()      // HapticFeedback.mediumImpact()
OutAboutHaptics.onConditionToggle()   // HapticFeedback.lightImpact()
OutAboutHaptics.onConditionMatch()    // HapticFeedback.vibrate()
```

---

## Screen Template

```dart
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text('Title', style: OutAboutTypography.headingLarge(colors)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          child: // content
        ),
      ),
    );
  }
}
```

## Card Template

```dart
final weatherTheme = ref.watch(weatherThemeProvider);
final isDark = weatherTheme.brightness == Brightness.dark;

Container(
  decoration: BoxDecoration(
    color: colors.cardBackground,
    borderRadius: BorderRadius.circular(OutAboutRadius.cards),
    boxShadow: isDark ? OutAboutShadows.cardDark : OutAboutShadows.card,
  ),
  padding: const EdgeInsets.all(OutAboutSpacing.md),
  child: // content
)
```

## Button Template

```dart
// Primary — uses theme primary color automatically via ThemeData
SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () {},
    child: Text('Get Outside'),  // style from theme
  ),
)

// Secondary / ghost
TextButton(
  onPressed: () {},
  child: Text('Maybe Later'),
)
```

## Loading State (shimmer)

```dart
import 'package:shimmer/shimmer.dart';

Shimmer.fromColors(
  baseColor: colors.surface,
  highlightColor: colors.divider,
  child: Container(
    height: 80,
    decoration: BoxDecoration(
      color: colors.cardBackground,
      borderRadius: BorderRadius.circular(OutAboutRadius.cards),
    ),
  ),
)
```
