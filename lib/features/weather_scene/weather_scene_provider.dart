import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/weather_theme_provider.dart';
import '../home/home_providers.dart';
import 'weather_scene_spec.dart';

/// The scene to paint behind the Schedule tab.
///
/// A pure derived provider, not a side-effecting one: it returns a value and is
/// kept alive by the widget that renders it. Nothing is silently skipped when
/// no one is looking, which is the failure mode [weatherThemeSyncProvider]
/// documents.
///
/// It watches the resolved theme rather than the override, so manual overrides
/// drive the scene exactly as they drive the palette.
final weatherSceneProvider = Provider<WeatherSceneSpec>((ref) {
  final theme = ref.watch(weatherThemeProvider);
  final code = ref.watch(weatherDataProvider).valueOrNull?.weatherCode;
  return resolveWeatherScene(theme: theme, liveWeatherCode: code);
});

/// Whether the app is in the foreground.
///
/// Driven by the [AppLifecycleListener] in main.dart. The engine already stops
/// producing frames for a backgrounded app, so this is belt and braces — but it
/// makes the guarantee explicit and testable rather than inherited.
final appIsForegroundProvider = StateProvider<bool>((ref) => true);
