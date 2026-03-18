import 'package:flutter/material.dart';

class OutAboutColors {
  static const Color primary = Color(0xFF4A9EFF);
  static const Color primaryDark = Color(0xFF1A7FE8);
  static const Color primaryLight = Color(0xFFB8D9FF);
  static const Color primarySurface = Color(0xFFF0F7FF);
  static const Color accent = Color(0xFFFF8C42);
  static const Color accentLight = Color(0xFFFFE0C8);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9500);
  static const Color errorColor = Color(0xFFFF3B30);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFF3F4F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F9FA);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color sunny = Color(0xFFFFB800);
  static const Color cloudy = Color(0xFF8FA3B1);
  static const Color rainy = Color(0xFF4A9EFF);
  static const Color windy = Color(0xFF6EC6CA);
  static const Color cold = Color(0xFF90CAF9);
  static const Color hot = Color(0xFFFF7043);
}

class OutAboutTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w700,
    color: OutAboutColors.textPrimary, letterSpacing: -0.5, height: 1.2,
  );
  static const TextStyle displayMedium = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700,
    color: OutAboutColors.textPrimary, letterSpacing: -0.3, height: 1.2,
  );
  static const TextStyle headingLarge = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    color: OutAboutColors.textPrimary, letterSpacing: -0.2,
  );
  static const TextStyle headingMedium = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600,
    color: OutAboutColors.textPrimary, letterSpacing: -0.1,
  );
  static const TextStyle headingSmall = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    color: OutAboutColors.textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400,
    color: OutAboutColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400,
    color: OutAboutColors.textPrimary, height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    color: OutAboutColors.textSecondary, height: 1.4,
  );
  static const TextStyle labelLarge = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
    color: OutAboutColors.textPrimary, letterSpacing: 0.1,
  );
  static const TextStyle labelMedium = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: OutAboutColors.textSecondary, letterSpacing: 0.1,
  );
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w500,
    color: OutAboutColors.textTertiary, letterSpacing: 0.3,
  );
}

class OutAboutSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

class OutAboutRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;
}

class OutAboutShadows {
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 16, offset: Offset(0, 4), spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x08000000),
      blurRadius: 4, offset: Offset(0, 1), spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x334A9EFF),
      blurRadius: 12, offset: Offset(0, 4), spreadRadius: 0,
    ),
  ];
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 24, offset: Offset(0, 8), spreadRadius: 0,
    ),
  ];
}

ThemeData outAboutTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: OutAboutColors.primary,
      primary: OutAboutColors.primary,
      secondary: OutAboutColors.accent,
      surface: OutAboutColors.surface,
      error: OutAboutColors.errorColor,
    ),
    scaffoldBackgroundColor: OutAboutColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: OutAboutColors.surface,
      foregroundColor: OutAboutColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: OutAboutTypography.headingLarge,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: OutAboutColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OutAboutRadius.md),
        ),
        textStyle: OutAboutTypography.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: OutAboutColors.primary,
        textStyle: OutAboutTypography.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OutAboutColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.md),
        borderSide: const BorderSide(color: OutAboutColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.md),
        borderSide: const BorderSide(color: OutAboutColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.md),
        borderSide: const BorderSide(color: OutAboutColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: OutAboutColors.textTertiary, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: OutAboutColors.cardBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OutAboutRadius.lg),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(
      color: OutAboutColors.divider,
      thickness: 1,
      space: 0,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: OutAboutColors.surface,
      selectedItemColor: OutAboutColors.primary,
      unselectedItemColor: OutAboutColors.textTertiary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}