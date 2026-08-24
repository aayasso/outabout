import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/motion.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'features/outcomes/outcome_providers.dart';
import 'core/weather_theme_provider.dart';
import 'features/home/home_providers.dart';
import 'features/weather_scene/weather_scene_provider.dart';
import 'features/widget/widget_gateway.dart';
import 'features/widget/widget_launch.dart';
import 'features/widget/widget_providers.dart';
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

  // Points home_widget at the App Group before anything tries to write. Its
  // own failure is swallowed — a widget that cannot be fed is not a reason to
  // stop the app launching, and on any build without the entitlement this is
  // the expected path.
  await initialiseHomeWidget();

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

  /// Separates "a notification was tapped" from "the app opened because of
  /// one" — see [NotificationOpenTracker].
  final _notificationOpens = NotificationOpenTracker();

  late final WidgetLaunchCoordinator _widgetLaunch;
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onResume,
      onStateChange: _onLifecycleStateChange,
    );
    _setupNotificationClickHandler();
    _setupWidgetTapHandler();
  }

  /// Routes home-screen widget taps to the schedule.
  ///
  /// Both delivery paths are wired, because iOS uses a different one depending
  /// on whether the app was already running, and the coordinator is what stops
  /// a cold start that fires both from counting one tap twice.
  void _setupWidgetTapHandler() {
    _widgetLaunch = WidgetLaunchCoordinator(
      // The same shape the notification tap uses: the router is read off the
      // container rather than through a global navigator key.
      onRoute: (route) => ref.read(routerProvider).go(route),
      onOpened: () =>
          ref.read(behavioralEventServiceProvider).log(widgetOpenEvent),
    );

    _widgetClicks = HomeWidget.widgetClicked.listen(_widgetLaunch.handleClick);

    // Deferred: the launch URL is available immediately, but routing before
    // the first frame runs go_router's redirect against a router that has not
    // been built yet.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        _widgetLaunch.handleLaunch(
          await HomeWidget.initiallyLaunchedFromHomeWidget(),
        );
      } catch (e) {
        log('Widget launch url unavailable: $e', name: 'OutAbout');
      }
    });
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
        _notificationOpens.recordTap(
          activityId,
          appIsForeground: ref.read(appIsForegroundProvider),
        );
        ref.read(routerProvider).go('/activity/$activityId');
      },
      eventService: eventService,
    );
    // A cold start from a notification tap delivers the click before any
    // lifecycle event, so there is no resume to consume the marker. Drain it
    // on the first frame instead.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _flushNotificationOpen(),
    );
  }

  /// Logs `app_opened_post_notification` once, if a tap brought us here.
  void _flushNotificationOpen() {
    final activityId = _notificationOpens.takePending();
    if (activityId == null) return;
    ref
        .read(behavioralEventServiceProvider)
        .log(
          'app_opened_post_notification',
          extra: {'activity_id': activityId},
        );
  }

  void _onResume() {
    _flushNotificationOpen();
    ref.invalidate(weatherDataProvider);
    ref.invalidate(dailyForecastProvider);
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps the weather-adaptive theme alive: this provider applies live
    // conditions to the theme notifier, and a provider nothing watches never
    // runs.
    ref.watch(weatherThemeSyncProvider);

    // Same reason: this one records today's matched days as opportunities, and
    // a provider nothing watches never runs. Without it the streak has a
    // numerator and no denominator.
    ref.watch(matchedDayRecorderProvider);

    // Starts the platform timezone lookup as early as anything is on screen.
    // It is an async channel call and every event's geographic_context wants
    // the result, so the sooner it resolves the fewer events fall back to the
    // abbreviation.
    ref.watch(deviceTimezoneProvider);

    // Same reason again: this one pushes today's summary to the home-screen
    // widget whenever the schedule changes, and a provider nothing watches
    // never runs.
    ref.watch(widgetSyncProvider);

    final themeData = ref.watch(themeDataProvider);

    final router = ref.watch(routerProvider);

    return AnimatedTheme(
      data: themeData,
      // The whole screen re-colours when the weather turns. That is the one
      // animation most likely to trigger discomfort, and it carries no
      // information the end state does not.
      duration: motionDuration(
        context,
        OutAboutAnimations.themeTransitionDuration,
      ),
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
