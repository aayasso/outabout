import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';
import 'package:outabout/core/theme.dart';
import 'package:outabout/core/weather_theme_provider.dart';
import 'package:outabout/data/models/category.dart';
import 'package:outabout/data/models/user_location.dart';
import 'package:outabout/features/home/home_providers.dart';
import 'package:outabout/data/models/behavioral_event.dart';
import 'package:outabout/services/behavioral_event_service.dart';
import 'package:outabout/widgets/find_and_book_sheet.dart';

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

  final List<({String type, Map<String, dynamic>? extra})> logged = [];

  @override
  Future<void> log(
    String eventType, {
    Map<String, dynamic>? extra,
    ConditionsAtEvent? conditions,
  }) async {
    logged.add((type: eventType, extra: extra));
  }
}

final _categories = [
  Category(id: 'cat-1', userId: 'user-1', name: 'Dining'),
  Category(id: 'cat-2', userId: 'user-1', name: 'Hiking'),
];

void main() {
  /// Captures the URL the sheet would have opened, without opening anything.
  late List<Uri> launched;
  late _RecordingEventService events;

  setUp(() {
    launched = <Uri>[];
    events = _RecordingEventService();
  });

  Widget harness({
    required String activityName,
    List<String> categoryNames = const [],
    String city = 'San Francisco, CA',
    bool launchSucceeds = true,
  }) {
    return ProviderScope(
      overrides: [
        weatherThemeProvider.overrideWith(
          (ref) => WeatherThemeNotifier(WeatherTheme.sunny),
        ),
        weatherThemeColorsProvider.overrideWithValue(WeatherThemeColors.sunny),
        categoriesProvider.overrideWith((ref) async => _categories),
        userLocationProvider.overrideWith(
          (ref) async => UserLocation(
            userId: 'user-1',
            latitude: 37.77,
            longitude: -122.42,
            city: city,
          ),
        ),
        urlLauncherProvider.overrideWithValue((Uri url) async {
          launched.add(url);
          return launchSucceeds;
        }),
        behavioralEventServiceProvider.overrideWithValue(events),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showFindAndBookSheet(
                  context,
                  ref,
                  activityName: activityName,
                  activityId: 'act-1',
                  categoryNames: categoryNames,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers the mapped providers for a dining activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(activityName: 'Dinner out', categoryNames: ['Dining']),
    );
    await openSheet(tester);

    expect(find.text('OpenTable'), findsOneWidget);
    expect(find.text('Yelp'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
  });

  testWidgets('falls back to Google Maps alone when nothing matches', (
    tester,
  ) async {
    await tester.pumpWidget(harness(activityName: 'Stargazing'));
    await openSheet(tester);

    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Yelp'), findsNothing);
    expect(find.text('OpenTable'), findsNothing);
  });

  testWidgets('leads with AllTrails for hiking, Google Maps second', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(activityName: 'Trail hike', categoryNames: ['Hiking']),
    );
    await openSheet(tester);

    expect(find.text('AllTrails'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);

    // Order matters: AllTrails answers the question better, but Google Maps
    // has to be right underneath it because an AllTrails city page can 404.
    final allTrailsY = tester.getCenter(find.text('AllTrails')).dy;
    final mapsY = tester.getCenter(find.text('Google Maps')).dy;
    expect(allTrailsY, lessThan(mapsY));
  });

  testWidgets('hides AllTrails when the city is not a US city', (tester) async {
    await tester.pumpWidget(
      harness(
        activityName: 'Trail hike',
        categoryNames: ['Hiking'],
        city: 'Toronto, ON',
      ),
    );
    await openSheet(tester);

    expect(find.text('AllTrails'), findsNothing);
    expect(find.text('Google Maps'), findsOneWidget);
  });

  testWidgets('hides AllTrails when no city has resolved yet', (tester) async {
    await tester.pumpWidget(
      harness(activityName: 'Trail hike', categoryNames: ['Hiking'], city: ''),
    );
    await openSheet(tester);

    expect(find.text('AllTrails'), findsNothing);
    expect(find.text('Google Maps'), findsOneWidget);
  });

  testWidgets('GolfNow is still absent for golf', (tester) async {
    await tester.pumpWidget(harness(activityName: 'Saturday golf'));
    await openSheet(tester);

    expect(find.text('GolfNow'), findsNothing);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Yelp'), findsOneWidget);
  });

  testWidgets('tapping AllTrails launches its city page', (tester) async {
    await tester.pumpWidget(
      harness(activityName: 'Trail hike', categoryNames: ['Hiking']),
    );
    await openSheet(tester);

    await tester.tap(find.text('AllTrails'));
    await tester.pumpAndSettle();

    expect(launched.single.host, 'www.alltrails.com');
    expect(launched.single.path, '/us/california/san-francisco');
    expect(events.logged.single.extra?['provider'], 'allTrails');
  });

  testWidgets('tapping a provider launches the constructed URL', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(activityName: 'Dinner out', categoryNames: ['Dining']),
    );
    await openSheet(tester);

    await tester.tap(find.text('OpenTable'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.host, 'www.opentable.com');
    expect(
      launched.single.queryParameters['term'],
      'Dinner out San Francisco, CA',
    );

    // The outcome signal: which provider, for which activity.
    expect(events.logged, hasLength(1));
    expect(events.logged.single.type, 'affiliate_link_clicked');
    expect(events.logged.single.extra?['provider'], 'openTable');
    expect(events.logged.single.extra?['activity_id'], 'act-1');
  });

  testWidgets('logs the click even when the launch fails', (tester) async {
    await tester.pumpWidget(
      harness(activityName: 'Stargazing', launchSucceeds: false),
    );
    await openSheet(tester);

    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();

    // Tapping is the behaviour worth recording; whether the handset had a
    // browser to hand is not a fact about the user.
    expect(events.logged.single.type, 'affiliate_link_clicked');
    expect(events.logged.single.extra?['provider'], 'googleMaps');
  });

  testWidgets('closes itself once the link opens', (tester) async {
    await tester.pumpWidget(harness(activityName: 'Stargazing'));
    await openSheet(tester);

    expect(find.text('Find & book'), findsOneWidget);
    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();

    expect(find.text('Find & book'), findsNothing);
  });

  testWidgets('reports a failed launch instead of closing silently', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(activityName: 'Stargazing', launchSucceeds: false),
    );
    await openSheet(tester);

    await tester.tap(find.text('Google Maps'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open Google Maps.'), findsOneWidget);
  });

  testWidgets('omits the city from the subtitle when location is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(harness(activityName: 'Stargazing', city: ''));
    await openSheet(tester);

    // The subtitle is the bare activity name; 'X near Y' only appears once a
    // city is known. ('Search nearby places' is a provider subtitle, so match
    // on the full phrase rather than the word.)
    expect(find.text('Stargazing'), findsOneWidget);
    expect(find.textContaining('Stargazing near'), findsNothing);
  });

  testWidgets('every provider row is a 48dp semantic link', (tester) async {
    await tester.pumpWidget(
      harness(activityName: 'Dinner out', categoryNames: ['Dining']),
    );
    await openSheet(tester);

    for (final label in ['OpenTable', 'Yelp', 'Google Maps']) {
      final size = tester.getSize(
        find
            .ancestor(of: find.text(label), matching: find.byType(Container))
            .first,
      );
      expect(size.height, greaterThanOrEqualTo(48.0), reason: label);
    }
  });
}
