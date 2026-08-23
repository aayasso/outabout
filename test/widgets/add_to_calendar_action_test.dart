import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/behavioral_event.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/services/calendar_service.dart';
import 'package:outabout/widgets/add_to_calendar_action.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// Records what would have been logged, without touching Supabase.
class _RecordingEventService extends BehavioralEventService {
  _RecordingEventService()
    : super(
        supabase: _MockSupabaseClient(),
        activeThemeName: () => 'sunny',
        geographicContext: () => const GeographicContext(
          metro: '',
          city: '',
          state: '',
          country: '',
          latBucketed: 0.0,
          lngBucketed: 0.0,
          timezone: '',
        ),
        appVersion: 'test',
      );

  final List<
    ({String type, Map<String, dynamic>? extra, ConditionsAtEvent? conditions})
  >
  logged = [];

  @override
  Future<void> log(
    String eventType, {
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
  }) async {
    logged.add((type: eventType, extra: extra, conditions: conditions));
  }
}

/// A CalendarService that answers with whatever the test wants, and records
/// whether the app tried to send the user to Settings.
class _FakeCalendarService implements CalendarService {
  _FakeCalendarService(this.result);

  CalendarAddResult result;
  int settingsOpened = 0;
  final List<({String title, DateTime day, String notes})> added = [];

  @override
  Future<CalendarAddResult> addAllDayEvent({
    required String title,
    required DateTime day,
    required String notes,
  }) async {
    added.add((title: title, day: day, notes: notes));
    return result;
  }

  @override
  Future<void> openSettings() async => settingsOpened++;
}

final _forecast = DailyForecast(
  date: DateTime(2026, 8, 24),
  temperatureMax: 22.2,
  temperatureMin: 12.8,
  precipitationProbability: 10,
  windSpeedMax: 12,
  weatherCode: 1000,
);

void main() {
  late SharedPreferences prefs;
  late _RecordingEventService events;
  late _FakeCalendarService calendar;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    events = _RecordingEventService();
    calendar = _FakeCalendarService(CalendarAddResult.added);
  });

  Widget harness() => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      weatherThemeProvider.overrideWith(
        (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
      ),
      weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
      profileProvider.overrideWith((ref) async => null),
      userLocationProvider.overrideWith((ref) async => null),
      behavioralEventServiceProvider.overrideWithValue(events),
      calendarServiceProvider.overrideWithValue(calendar),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => addActivityToCalendar(
                context,
                ref,
                activityName: 'Morning run',
                activityId: 'act-1',
                forecast: _forecast,
              ),
              child: const Text('add'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> tapAdd(WidgetTester tester) async {
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
  }

  group('success', () {
    testWidgets('creates an all-day event titled with the activity', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tapAdd(tester);

      expect(calendar.added, hasLength(1));
      expect(calendar.added.single.title, 'Morning run');
      expect(calendar.added.single.day, DateTime(2026, 8, 24));
      expect(
        calendar.added.single.notes,
        'H 72°F / L 55°F, Clear — matched your conditions in OutAbout',
      );
    });

    testWidgets('logs calendar_event_added with the conditions snapshot', (
      tester,
    ) async {
      await tester.pumpWidget(harness());
      await tapAdd(tester);

      final logged = events.logged.where(
        (e) => e.type == 'calendar_event_added',
      );
      expect(logged, hasLength(1));
      expect(logged.single.extra?['activity_id'], 'act-1');
      expect(logged.single.extra?['matched_day'], '2026-08-24');
      expect(
        logged.single.conditions,
        isNotNull,
        reason: 'same shape as affiliate_link_clicked',
      );
    });

    testWidgets('confirms in the UI, naming the day', (tester) async {
      await tester.pumpWidget(harness());
      await tapAdd(tester);

      expect(find.textContaining('Aug 24'), findsOneWidget);
    });
  });

  group('permission denied — quiet, once', () {
    testWidgets('a recoverable refusal says nothing at all', (tester) async {
      // The user just declined the system prompt. Repeating it back is the
      // nagging this path exists to avoid, and the prompt can still be shown
      // again next time.
      calendar.result = CalendarAddResult.permissionDenied;
      await tester.pumpWidget(harness());
      await tapAdd(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(events.logged, isEmpty);
    });

    testWidgets('a terminal refusal explains once, with a Settings route', (
      tester,
    ) async {
      calendar.result = CalendarAddResult.permissionPermanentlyDenied;
      await tester.pumpWidget(harness());
      await tapAdd(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Calendar access is off'), findsOneWidget);
      expect(find.textContaining('never reads your calendar'), findsOneWidget);

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();
      expect(calendar.settingsOpened, 1);
    });

    testWidgets('and never explains a second time', (tester) async {
      calendar.result = CalendarAddResult.permissionPermanentlyDenied;
      await tester.pumpWidget(harness());

      await tapAdd(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      await tapAdd(tester);
      expect(
        find.byType(AlertDialog),
        findsNothing,
        reason: 'the user has already been told where the switch is',
      );
      expect(find.text('Calendar access is off for OutAbout.'), findsOneWidget);
    });

    testWidgets('the explainer flag survives a fresh widget tree', (
      tester,
    ) async {
      // It is persisted, not held in the widget — a relaunch must not
      // re-explain.
      calendar.result = CalendarAddResult.permissionPermanentlyDenied;
      await tester.pumpWidget(harness());
      await tapAdd(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(harness());
      await tapAdd(tester);

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a restricted device is never sent to Settings', (
      tester,
    ) async {
      // Screen Time or MDM: the user cannot grant this even if willing.
      calendar.result = CalendarAddResult.permissionRestricted;
      await tester.pumpWidget(harness());
      await tapAdd(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Calendar access is blocked on this device.'),
        findsOneWidget,
      );
      expect(calendar.settingsOpened, 0);
    });
  });

  group('failure', () {
    testWidgets('says so, and logs nothing', (tester) async {
      calendar.result = CalendarAddResult.failed;
      await tester.pumpWidget(harness());
      await tapAdd(tester);

      expect(find.text('Could not add to your calendar.'), findsOneWidget);
      expect(events.logged, isEmpty);
    });
  });
}
