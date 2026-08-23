import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// WeatherTheme enum
// ---------------------------------------------------------------------------

enum WeatherTheme {
  sunny,
  overcast,
  rainy,
  snowy,
  night;

  String get displayName {
    switch (this) {
      case WeatherTheme.sunny:
        return 'Sunny';
      case WeatherTheme.overcast:
        return 'Overcast';
      case WeatherTheme.rainy:
        return 'Rainy';
      case WeatherTheme.snowy:
        return 'Snowy';
      case WeatherTheme.night:
        return 'Night';
    }
  }

  Brightness get brightness {
    switch (this) {
      case WeatherTheme.sunny:
      case WeatherTheme.overcast:
      case WeatherTheme.snowy:
        return Brightness.light;
      case WeatherTheme.rainy:
      case WeatherTheme.night:
        return Brightness.dark;
    }
  }
}

// ---------------------------------------------------------------------------
// WeatherThemeColors — per-theme color palette
// ---------------------------------------------------------------------------

class WeatherThemeColors {
  final Color background;
  final Color primary;

  /// Ink for content drawn *on top of* a [primary] fill.
  ///
  /// Not derived from [Brightness]: the light palettes carry pale primaries
  /// (`#F5A623`, `#90CAF9`), so the obvious `isDark ? black : white` puts white
  /// on amber at 2.03:1. Each palette names its own ink instead, and every one
  /// clears 6.8:1.
  final Color onPrimary;

  /// [primary] restated as a *foreground* colour, for text and icons.
  ///
  /// [primary] is tuned to be seen as a fill. Used as ink on a light palette it
  /// reaches 1.66-2.46:1, so anything reading as text — link labels, icon
  /// buttons, focus rings, slider tracks — takes this instead. The fill colour
  /// is untouched.
  final Color primaryInteractive;

  final Color accent;
  final Color text;
  final Color textSecondary;
  final Color surface;
  final Color cardBackground;
  final Color divider;

  const WeatherThemeColors({
    required this.background,
    required this.primary,
    required this.onPrimary,
    required this.primaryInteractive,
    required this.accent,
    required this.text,
    required this.textSecondary,
    required this.surface,
    required this.cardBackground,
    required this.divider,
  });

  static const WeatherThemeColors sunny = WeatherThemeColors(
    background: Color(0xFFFFF8EE),
    primary: Color(0xFFF5A623),
    onPrimary: Color(0xFF1A1A1A),
    primaryInteractive: Color(0xFFA05E00),
    accent: Color(0xFFFF6B35),
    text: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B5B3E),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    divider: Color(0xFFE8DCC8),
  );

  static const WeatherThemeColors overcast = WeatherThemeColors(
    background: Color(0xFFF0F2F5),
    primary: Color(0xFF4A9EFF),
    onPrimary: Color(0xFF0D1117),
    primaryInteractive: Color(0xFF1565C0),
    accent: Color(0xFF7B8FA1),
    text: Color(0xFF2C3E50),
    textSecondary: Color(0xFF5A6978),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    divider: Color(0xFFD8DCE2),
  );

  static const WeatherThemeColors rainy = WeatherThemeColors(
    background: Color(0xFF1A2332),
    primary: Color(0xFF4A9EFF),
    onPrimary: Color(0xFF000000),
    primaryInteractive: Color(0xFF7DBBFF),
    accent: Color(0xFF64B5F6),
    text: Color(0xFFE8EDF2),
    textSecondary: Color(0xFF9EACBA),
    surface: Color(0xFF243447),
    cardBackground: Color(0xFF243447),
    divider: Color(0xFF2E3F52),
  );

  static const WeatherThemeColors snowy = WeatherThemeColors(
    background: Color(0xFFF7F9FC),
    primary: Color(0xFF90CAF9),
    onPrimary: Color(0xFF263238),
    primaryInteractive: Color(0xFF1565C0),
    accent: Color(0xFF546E7A),
    text: Color(0xFF263238),
    textSecondary: Color(0xFF506A78),
    surface: Color(0xFFFFFFFF),
    cardBackground: Color(0xFFFFFFFF),
    divider: Color(0xFFE0E8EE),
  );

  static const WeatherThemeColors night = WeatherThemeColors(
    background: Color(0xFF0D1117),
    primary: Color(0xFF4A9EFF),
    onPrimary: Color(0xFF000000),
    primaryInteractive: Color(0xFF4A9EFF),
    accent: Color(0xFFF5A623),
    text: Color(0xFFE8EDF2),
    textSecondary: Color(0xFF8B949E),
    surface: Color(0xFF161B22),
    cardBackground: Color(0xFF161B22),
    divider: Color(0xFF21262D),
  );

  static WeatherThemeColors forTheme(WeatherTheme theme) {
    switch (theme) {
      case WeatherTheme.sunny:
        return sunny;
      case WeatherTheme.overcast:
        return overcast;
      case WeatherTheme.rainy:
        return rainy;
      case WeatherTheme.snowy:
        return snowy;
      case WeatherTheme.night:
        return night;
    }
  }
}

// ---------------------------------------------------------------------------
// Semantic / condition icon colors (weather-independent)
// ---------------------------------------------------------------------------

class OutAboutColors {
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color errorColor = Color(0xFFFF3B30);

  // Weather-condition icon tints
  static const Color sunny = Color(0xFFFFB800);
  static const Color cloudy = Color(0xFF8FA3B1);
  static const Color rainy = Color(0xFF4A9EFF);
  static const Color windy = Color(0xFF6EC6CA);
  static const Color cold = Color(0xFF90CAF9);
  static const Color hot = Color(0xFFFF7043);
}

// ---------------------------------------------------------------------------
// Typography — text colors derived from active theme
// ---------------------------------------------------------------------------

class OutAboutTypography {
  static TextStyle displayLarge(WeatherThemeColors c) => TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: c.text,
    letterSpacing: -0.5,
    height: 1.2,
  );
  static TextStyle displayMedium(WeatherThemeColors c) => TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: c.text,
    letterSpacing: -0.3,
    height: 1.2,
  );
  static TextStyle headingLarge(WeatherThemeColors c) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: c.text,
    letterSpacing: -0.2,
  );
  static TextStyle headingMedium(WeatherThemeColors c) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: c.text,
    letterSpacing: -0.1,
  );
  static TextStyle headingSmall(WeatherThemeColors c) =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text);
  static TextStyle bodyLarge(WeatherThemeColors c) => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: c.text,
    height: 1.5,
  );
  static TextStyle bodyMedium(WeatherThemeColors c) => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: c.text,
    height: 1.5,
  );
  static TextStyle bodySmall(WeatherThemeColors c) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: c.textSecondary,
    height: 1.4,
  );
  static TextStyle labelLarge(WeatherThemeColors c) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: c.text,
    letterSpacing: 0.1,
  );
  static TextStyle labelMedium(WeatherThemeColors c) => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: c.textSecondary,
    letterSpacing: 0.1,
  );
  static TextStyle labelSmall(WeatherThemeColors c) => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: c.textSecondary,
    letterSpacing: 0.3,
  );
}

// ---------------------------------------------------------------------------
// Spacing (unchanged)
// ---------------------------------------------------------------------------

class OutAboutSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

// ---------------------------------------------------------------------------
// Radius — with semantic aliases per spec
// ---------------------------------------------------------------------------

class OutAboutRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  // Semantic aliases (CLAUDE.md spec)
  static const double cards = lg; // 16px
  static const double bottomSheet = xl; // 24px
  static const double buttons = md; // 12px
}

// ---------------------------------------------------------------------------
// Shadows
// ---------------------------------------------------------------------------

class OutAboutShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 16,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
      spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x334A9EFF),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: 0,
    ),
  ];
}

// ---------------------------------------------------------------------------
// Animation constants
// ---------------------------------------------------------------------------

class OutAboutAnimations {
  static const Duration standardDuration = Duration(milliseconds: 300);
  static const Duration themeTransitionDuration = Duration(milliseconds: 500);
  static const Curve standardCurve = Curves.easeInOut;
}

// ---------------------------------------------------------------------------
// Haptic feedback helpers
// ---------------------------------------------------------------------------

class OutAboutHaptics {
  static void onActivitySave() => HapticFeedback.mediumImpact();
  static void onConditionToggle() => HapticFeedback.lightImpact();
  static void onConditionMatch() => HapticFeedback.vibrate();
}

// ---------------------------------------------------------------------------
// Theme builder — returns full ThemeData for a given WeatherTheme
// ---------------------------------------------------------------------------

ThemeData outAboutTheme([WeatherTheme weatherTheme = WeatherTheme.sunny]) {
  final colors = WeatherThemeColors.forTheme(weatherTheme);
  final isDark = weatherTheme.brightness == Brightness.dark;

  return ThemeData(
    useMaterial3: true,
    brightness: weatherTheme.brightness,
    colorScheme: ColorScheme(
      brightness: weatherTheme.brightness,
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.accent,
      onSecondary: isDark ? Colors.black : Colors.white,
      surface: colors.surface,
      onSurface: colors.text,
      error: OutAboutColors.errorColor,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: colors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: OutAboutTypography.headingLarge(colors),
      systemOverlayStyle: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
        ),
        textStyle: OutAboutTypography.labelLarge(
          colors,
        ).copyWith(color: colors.onPrimary),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primaryInteractive,
        textStyle: OutAboutTypography.labelLarge(colors),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
        borderSide: BorderSide(color: colors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
        borderSide: BorderSide(color: colors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
        borderSide: BorderSide(color: colors.primaryInteractive, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: colors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 1,
      space: 0,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.surface,
      selectedItemColor: colors.primaryInteractive,
      unselectedItemColor: colors.textSecondary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
