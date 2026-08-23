import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/weather_theme_provider.dart';
import 'features/home/home_providers.dart';
import 'features/weather_scene/weather_scene_provider.dart';
import 'services/behavioral_event_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  try {
    OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!);
  } catch (e) {
    log('OneSignal init failed: $e', name: 'OutAbout');
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const OutAboutApp(),
    ),
  );
}

class OutAboutApp extends ConsumerStatefulWidget {
  const OutAboutApp({super.key});

  @override
  ConsumerState<OutAboutApp> createState() => _OutAboutAppState();
}

class _OutAboutAppState extends ConsumerState<OutAboutApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onResume,
      onStateChange: _onLifecycleStateChange,
    );
    _setupNotificationClickHandler();
  }

  /// Keeps the animated weather scene off the CPU while the app is not visible.
  ///
  /// The engine already stops producing frames for a backgrounded app, so this
  /// is belt and braces — but it makes the guarantee explicit rather than
  /// inherited, and it is what the scene's TickerMode reads.
  void _onLifecycleStateChange(AppLifecycleState state) {
    ref.read(appIsForegroundProvider.notifier).state =
        state == AppLifecycleState.resumed;
  }

  void _setupNotificationClickHandler() {
    final notificationService = ref.read(notificationServiceProvider);
    final eventService = ref.read(behavioralEventServiceProvider);
    notificationService.setupClickHandler(
      onActivityTap: (activityId) {
        ref.read(routerProvider).go('/activity/$activityId');
      },
      eventService: eventService,
    );
  }

  void _onResume() {
    ref.invalidate(weatherDataProvider);
    ref.invalidate(dailyForecastProvider);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the weather-adaptive theme alive: this provider applies live
    // conditions to the theme notifier, and a provider nothing watches never
    // runs.
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
