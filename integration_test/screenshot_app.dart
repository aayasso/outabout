/// Minimal app shell for screenshots.
///
/// Replicates [OutAboutApp.build] without the initState side
/// effects (HomeWidget listeners, OneSignal click handlers,
/// AppLifecycleListener). Lives in integration_test/ so lib/
/// is untouched.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:outabout/core/router.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/features/home/home_providers.dart';

class ScreenshotApp extends ConsumerWidget {
  const ScreenshotApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Let the theme derive from overridden weather data
    // and clock — exactly as OutAboutApp does.
    ref.watch(weatherThemeSyncProvider);

    final themeData = ref.watch(themeDataProvider);
    final router = ref.watch(routerProvider);

    return AnimatedTheme(
      data: themeData,
      duration: OutAboutAnimations.themeTransitionDuration,
      curve: OutAboutAnimations.standardCurve,
      child: MaterialApp.router(
        title: 'OutAbout',
        debugShowCheckedModeBanner: false,
        theme: themeData,
        routerConfig: router,
      ),
    );
  }
}
