import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------

const _overrideKey = 'weather_theme_override';

// ---------------------------------------------------------------------------
// SharedPreferences provider
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in ProviderScope',
  );
});

// ---------------------------------------------------------------------------
// User theme override — persisted via SharedPreferences
// ---------------------------------------------------------------------------

final userThemeOverrideProvider =
    StateNotifierProvider<UserThemeOverrideNotifier, WeatherTheme?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return UserThemeOverrideNotifier(prefs);
});

class UserThemeOverrideNotifier extends StateNotifier<WeatherTheme?> {
  final SharedPreferences _prefs;

  UserThemeOverrideNotifier(this._prefs) : super(_loadOverride(_prefs));

  static WeatherTheme? _loadOverride(SharedPreferences prefs) {
    final stored = prefs.getString(_overrideKey);
    if (stored == null) return null;
    return WeatherTheme.values.where((t) => t.name == stored).firstOrNull;
  }

  Future<void> setOverride(WeatherTheme? theme) async {
    state = theme;
    if (theme == null) {
      await _prefs.remove(_overrideKey);
    } else {
      await _prefs.setString(_overrideKey, theme.name);
    }
  }
}

// ---------------------------------------------------------------------------
// Weather-adaptive theme notifier
// ---------------------------------------------------------------------------

final weatherThemeProvider =
    StateNotifierProvider<WeatherThemeNotifier, WeatherTheme>((ref) {
  final override = ref.watch(userThemeOverrideProvider);
  return WeatherThemeNotifier(override);
});

class WeatherThemeNotifier extends StateNotifier<WeatherTheme> {
  final WeatherTheme? _userOverride;

  WeatherThemeNotifier(this._userOverride)
      : super(_userOverride ?? WeatherTheme.sunny);

  /// Whether the current theme is a user override or adaptive.
  bool get isUserOverride => _userOverride != null;

  /// Map a Tomorrow.io weather code to a theme.
  void setThemeFromConditions(int weatherCode) {
    if (_userOverride != null) return; // user override takes precedence
    state = _mapWeatherCode(weatherCode);
  }

  /// Apply night override after sunset.
  void setThemeFromTimeOfDay(DateTime now, {int sunsetHour = 20, int sunriseHour = 6}) {
    if (_userOverride != null) return;
    if (now.hour >= sunsetHour || now.hour < sunriseHour) {
      state = WeatherTheme.night;
    }
  }

  /// The theme name for session_context.active_theme logging.
  String get activeThemeName => state.name;

  // Tomorrow.io weather code mapping
  // https://docs.tomorrow.io/reference/data-layers-weather-codes
  static WeatherTheme _mapWeatherCode(int code) {
    if (code >= 5000 && code < 6000) return WeatherTheme.snowy;  // snow
    if (code >= 4000 && code < 5000) return WeatherTheme.rainy;  // rain/drizzle
    if (code >= 2000 && code < 3000) return WeatherTheme.rainy;  // fog → rainy mood
    if (code >= 1100 && code < 2000) return WeatherTheme.overcast; // cloudy
    if (code == 1001) return WeatherTheme.overcast;               // cloudy
    return WeatherTheme.sunny;                                     // clear / mostly clear
  }
}

// ---------------------------------------------------------------------------
// Derived ThemeData provider
// ---------------------------------------------------------------------------

final themeDataProvider = Provider<ThemeData>((ref) {
  final weatherTheme = ref.watch(weatherThemeProvider);
  return outAboutTheme(weatherTheme);
});

// ---------------------------------------------------------------------------
// Derived WeatherThemeColors provider (convenience for widgets)
// ---------------------------------------------------------------------------

final weatherThemeColorsProvider = Provider<WeatherThemeColors>((ref) {
  final weatherTheme = ref.watch(weatherThemeProvider);
  return WeatherThemeColors.forTheme(weatherTheme);
});
