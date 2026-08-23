import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/data/models/user_location.dart';
import 'package:outabout/data/models/behavioral_event.dart';
import 'package:outabout/data/models/daily_forecast.dart';
import 'package:outabout/data/models/weather_data.dart';
import 'package:outabout/services/behavioral_event_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ConditionsAtEvent', () {
    test('toJson() includes all 8 fields with correct snake_case keys', () {
      const conditions = ConditionsAtEvent(
        tempC: 22.5,
        tempF: 72.5,
        precipitationProbability: 30,
        windKph: 15.2,
        uvIndex: 6,
        airQualityIndex: 42,
        weatherTheme: 'sunny',
        forecastWindowHours: 4,
      );

      final json = conditions.toJson();

      expect(json.length, 8);
      expect(json['temp_c'], 22.5);
      expect(json['temp_f'], 72.5);
      expect(json['precipitation_probability'], 30);
      expect(json['wind_kph'], 15.2);
      expect(json['uv_index'], 6);
      expect(json['air_quality_index'], 42);
      expect(json['weather_theme'], 'sunny');
      expect(json['forecast_window_hours'], 4);

      // No null values.
      expect(json.values.any((v) => v == null), isFalse);
    });
  });

  group('buildConditionsSnapshot', () {
    final forecastDay = DailyForecast(
      date: DateTime(2026, 8, 23),
      temperatureMax: 26.0,
      temperatureMin: 14.0,
      precipitationProbability: 18.6,
      windSpeedMax: 12.0,
      weatherCode: 1000,
    );

    const current = WeatherData(
      weatherCode: 1101,
      temperature: 21.0,
      windSpeed: 9.5,
      humidity: 55.0,
      precipitationIntensity: 0.0,
      uvIndex: 5.4,
    );

    test('emits the server-compatible keys when a forecast is supplied', () {
      final json = buildConditionsSnapshot(
        weatherTheme: 'sunny',
        current: current,
        forecastDay: forecastDay,
        forecastWindowHours: 24,
      ).toJson();

      // The four keys that mirror check-weather's buildConditionsSnapshot,
      // so client and server rows can be queried together.
      expect(json['weather_code'], 1000);
      expect(json['temp_max_c'], 26.0);
      expect(json['temp_min_c'], 14.0);
      expect(json['forecast_date'], '2026-08-23T00:00:00.000');
      expect(json.length, 12);
    });

    test('prefers live conditions for the right-now fields', () {
      final snapshot = buildConditionsSnapshot(
        weatherTheme: 'sunny',
        current: current,
        forecastDay: forecastDay,
      );

      expect(snapshot.tempC, 21.0);
      expect(snapshot.windKph, 9.5);
      expect(snapshot.uvIndex, 5);
    });

    test('converts to Fahrenheit rather than reporting zero', () {
      final snapshot = buildConditionsSnapshot(
        weatherTheme: 'sunny',
        current: current,
      );

      expect(snapshot.tempF, closeTo(69.8, 0.01));
    });

    test('falls back to the day midpoint when live weather is missing', () {
      final snapshot = buildConditionsSnapshot(
        weatherTheme: 'overcast',
        forecastDay: forecastDay,
      );

      // (26 + 14) / 2
      expect(snapshot.tempC, 20.0);
      expect(snapshot.windKph, 12.0);
      // No live reading to take a code from, so the day's applies.
      expect(snapshot.weatherCode, 1000);
    });

    test('rounds precipitation probability to an integer percentage', () {
      final snapshot = buildConditionsSnapshot(
        weatherTheme: 'rainy',
        forecastDay: forecastDay,
      );

      expect(snapshot.precipitationProbability, 19);
    });

    test('with neither source it degrades to zeros, not to nulls', () {
      final snapshot = buildConditionsSnapshot(weatherTheme: 'night');
      final json = snapshot.toJson();

      expect(snapshot.tempC, 0.0);
      expect(snapshot.windKph, 0.0);
      expect(json['weather_theme'], 'night');
      // The optional server keys are omitted entirely rather than sent null.
      expect(json.length, 8);
      expect(json.values.any((v) => v == null), isFalse);
    });

    test(
      'takes the weather code from live conditions when no day is given',
      () {
        final snapshot = buildConditionsSnapshot(
          weatherTheme: 'overcast',
          current: current,
        );

        expect(snapshot.weatherCode, 1101);
      },
    );
  });

  group('GeographicContext', () {
    test('toJson() includes all 7 fields with correct snake_case keys', () {
      const geo = GeographicContext(
        metro: 'San Francisco',
        city: 'San Francisco',
        state: 'CA',
        country: 'US',
        latBucketed: 37.77,
        lngBucketed: -122.42,
        timezone: 'America/Los_Angeles',
      );

      final json = geo.toJson();

      expect(json.length, 7);
      expect(json['metro'], 'San Francisco');
      expect(json['city'], 'San Francisco');
      expect(json['state'], 'CA');
      expect(json['country'], 'US');
      expect(json['lat_bucketed'], 37.77);
      expect(json['lng_bucketed'], -122.42);
      expect(json['timezone'], 'America/Los_Angeles');

      expect(json.values.any((v) => v == null), isFalse);
    });
  });

  group('TemporalContext', () {
    test('toJson() includes all 9 fields with correct snake_case keys', () {
      const temporal = TemporalContext(
        hourOfDay: 14,
        dayOfWeek: 3,
        weekOfMonth: 2,
        monthOfYear: 7,
        season: 'summer',
        weekOfSeason: 5,
        daysSinceLastMatch: 3,
        daysSinceActivityCreated: 10,
        consecutiveMatchCount: 2,
      );

      final json = temporal.toJson();

      expect(json.length, 9);
      expect(json['hour_of_day'], 14);
      expect(json['day_of_week'], 3);
      expect(json['week_of_month'], 2);
      expect(json['month_of_year'], 7);
      expect(json['season'], 'summer');
      expect(json['week_of_season'], 5);
      expect(json['days_since_last_match'], 3);
      expect(json['days_since_activity_created'], 10);
      expect(json['consecutive_match_count'], 2);

      expect(json.values.any((v) => v == null), isFalse);
    });
  });

  group('SessionContext', () {
    test('toJson() includes all 3 fields with correct snake_case keys', () {
      const session = SessionContext(
        platform: 'ios',
        appVersion: '1.0.0',
        activeTheme: 'sunny',
      );

      final json = session.toJson();

      expect(json.length, 3);
      expect(json['platform'], 'ios');
      expect(json['app_version'], '1.0.0');
      expect(json['active_theme'], 'sunny');

      expect(json.values.any((v) => v == null), isFalse);
    });
  });

  group('Coordinate bucketing', () {
    test('37.7749 buckets to 37.77', () {
      expect(bucket(37.7749), 37.77);
    });

    test('-122.4194 buckets to -122.42', () {
      expect(bucket(-122.4194), -122.42);
    });

    test('0.0 buckets to 0.0', () {
      expect(bucket(0.0), 0.0);
    });

    test('negative coordinate near zero', () {
      expect(bucket(-0.005), -0.01);
    });
  });

  group('Season calculation', () {
    test('month 1 → winter', () {
      expect(seasonForMonth(1), 'winter');
    });

    test('month 2 → winter', () {
      expect(seasonForMonth(2), 'winter');
    });

    test('month 3 → spring', () {
      expect(seasonForMonth(3), 'spring');
    });

    test('month 4 → spring', () {
      expect(seasonForMonth(4), 'spring');
    });

    test('month 5 → spring', () {
      expect(seasonForMonth(5), 'spring');
    });

    test('month 6 → summer', () {
      expect(seasonForMonth(6), 'summer');
    });

    test('month 7 → summer', () {
      expect(seasonForMonth(7), 'summer');
    });

    test('month 10 → fall', () {
      expect(seasonForMonth(10), 'fall');
    });

    test('month 12 → winter', () {
      expect(seasonForMonth(12), 'winter');
    });
  });

  group('BehavioralEventService', () {
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;

    const testUserId = '11111111-2222-3333-4444-555555555555';

    /// Puts an authenticated user behind the mocked client.
    void signIn() {
      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn(testUserId);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
    }

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();

      when(() => mockSupabase.auth).thenReturn(mockAuth);
      // Default: signed out. Tests needing a session call signIn().
      when(() => mockAuth.currentUser).thenReturn(null);
    });

    test('skips the insert entirely when there is no session', () async {
      final service = BehavioralEventService(
        supabase: mockSupabase,
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
        appVersion: '1.0.0',
      );

      // Valid event type, but no authenticated user.
      await service.log('wishlist_added');

      // Must not attempt an insert — user_id is a uuid column and there is
      // no id to attribute the event to.
      verifyNever(() => mockSupabase.from(any()));
    });

    test('rejects unknown event types without calling Supabase', () async {
      final service = BehavioralEventService(
        supabase: mockSupabase,
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
        appVersion: '1.0.0',
      );

      await service.log('unknown_event_type');

      // Should never call from() for an invalid event type.
      verifyNever(() => mockSupabase.from(any()));
    });

    test('never throws — catches errors internally', () async {
      signIn();
      // Make from() throw to simulate Supabase failure.
      when(
        () => mockSupabase.from(any()),
      ).thenThrow(Exception('Supabase error'));

      final service = BehavioralEventService(
        supabase: mockSupabase,
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
        appVersion: '1.0.0',
      );

      // Should not throw.
      await expectLater(service.log('wishlist_added'), completes);
    });

    test('calls from(behavioral_events) for valid event types', () async {
      signIn();
      // Make from() throw so we can verify it was called
      // (we can't easily mock the full insert chain).
      when(
        () => mockSupabase.from('behavioral_events'),
      ).thenThrow(Exception('Expected — verifying table name'));

      final service = BehavioralEventService(
        supabase: mockSupabase,
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
        appVersion: '1.0.0',
      );

      await service.log('wishlist_added');

      // Verify from() was called with correct table name.
      verify(() => mockSupabase.from('behavioral_events')).called(1);
    });

    test('builds correct insert payload via buildPayload', () {
      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: () => 'rainy',
        geographicContext: () => const GeographicContext(
          metro: '',
          city: '',
          state: '',
          country: '',
          latBucketed: 0.0,
          lngBucketed: 0.0,
          timezone: '',
        ),
        appVersion: '2.0.0',
      );

      final payload = service.buildPayload(
        'activity_viewed',
        userId: testUserId,
        extra: {'activity_id': 'abc-123'},
      );

      expect(payload['event_type'], 'activity_viewed');
      expect(payload['user_id'], testUserId);

      // Verify all 4 context objects present.
      expect(payload['conditions_at_event'], isA<Map<String, dynamic>>());
      expect(payload['geographic_context'], isA<Map<String, dynamic>>());
      expect(payload['temporal_context'], isA<Map<String, dynamic>>());
      expect(payload['session_context'], isA<Map<String, dynamic>>());

      // Verify session context.
      final sessionCtx = payload['session_context'] as Map<String, dynamic>;
      expect(sessionCtx['active_theme'], 'rainy');
      expect(sessionCtx['app_version'], '2.0.0');

      // Verify conditions context has theme.
      final conditionsCtx =
          payload['conditions_at_event'] as Map<String, dynamic>;
      expect(conditionsCtx['weather_theme'], 'rainy');

      // Verify extra fields merged into session_context.
      expect(sessionCtx['activity_id'], 'abc-123');
    });

    test('buildPayload sets correct temporal context from DateTime.now()', () {
      final service = BehavioralEventService(
        supabase: mockSupabase,
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
        appVersion: '1.0.0',
      );

      final payload = service.buildPayload(
        'wishlist_added',
        userId: testUserId,
      );
      final temporal = payload['temporal_context'] as Map<String, dynamic>;

      // These should be populated from DateTime.now().
      expect(temporal['hour_of_day'], isA<int>());
      expect(temporal['day_of_week'], isA<int>());
      expect(temporal['week_of_month'], isA<int>());
      expect(temporal['month_of_year'], isA<int>());
      expect(temporal['season'], isA<String>());
      expect(temporal['week_of_season'], isA<int>());
      expect(temporal['days_since_last_match'], 0);
      expect(temporal['days_since_activity_created'], 0);
      expect(temporal['consecutive_match_count'], 0);

      // Verify season matches current month.
      final now = DateTime.now();
      expect(temporal['season'], seasonForMonth(now.month));
      expect(temporal['month_of_year'], now.month);
    });

    test('buildPayload carries the geographic context it is given', () {
      // This used to be hardcoded inside buildPayload — every row the app
      // wrote had lat/lng 0.0 and a flat country 'US'. The context is now
      // supplied by the caller, so this asserts it is actually threaded
      // through rather than re-fabricated.
      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: () => 'sunny',
        geographicContext: () => const GeographicContext(
          metro: 'Bay Area',
          city: 'San Francisco',
          state: 'CA',
          country: 'US',
          latBucketed: 37.77,
          lngBucketed: -122.42,
          timezone: 'PST',
        ),
        appVersion: '1.0.0',
      );

      final payload = service.buildPayload(
        'wishlist_added',
        userId: testUserId,
      );
      final geo = payload['geographic_context'] as Map<String, dynamic>;

      expect(geo['city'], 'San Francisco');
      expect(geo['state'], 'CA');
      expect(geo['country'], 'US');
      expect(geo['lat_bucketed'], 37.77);
      expect(geo['lng_bucketed'], -122.42);
      expect(geo['timezone'], 'PST');
    });

    test('buildGeographicContext buckets coordinates to ~1.1km', () {
      final geo = buildGeographicContext(
        const UserLocation(
          userId: 'u1',
          city: 'San Francisco, CA',
          latitude: 37.774929,
          longitude: -122.419418,
        ),
      );

      // Two decimal places. Full precision must not leave the device.
      expect(geo.latBucketed, 37.77);
      expect(geo.lngBucketed, -122.42);
      expect(geo.city, 'San Francisco');
      expect(geo.state, 'CA');
    });

    test('buildGeographicContext reports absence as empty, not as US', () {
      final geo = buildGeographicContext(null);

      // "Not collected" and "United States" must not look the same.
      expect(geo.country, '');
      expect(geo.city, '');
      expect(geo.latBucketed, 0.0);
      expect(geo.lngBucketed, 0.0);
    });

    test('all approved event types are in the const list', () {
      expect(approvedEventTypes, contains('wishlist_added'));
      expect(approvedEventTypes, contains('wishlist_removed'));
      expect(approvedEventTypes, contains('activity_viewed'));
      expect(approvedEventTypes, contains('condition_profile_updated'));
      expect(approvedEventTypes, contains('condition_match_notified'));
      expect(approvedEventTypes, contains('notification_opened'));
      expect(approvedEventTypes, contains('app_opened_post_notification'));
      expect(approvedEventTypes, contains('activity_confirmed'));
      expect(approvedEventTypes, contains('condition_match_ignored'));
      expect(approvedEventTypes, contains('affiliate_link_clicked'));
      expect(approvedEventTypes, contains('partner_impression_viewed'));
      expect(approvedEventTypes, contains('partner_cta_clicked'));
      expect(approvedEventTypes, contains('theme_override_set'));
      expect(approvedEventTypes, contains('booking_integration_viewed'));
      expect(approvedEventTypes, contains('auth_completed'));
      expect(approvedEventTypes, contains('auth_skipped'));
      expect(approvedEventTypes, contains('onboarding_completed'));
      // Added in behavioral event audit (Feature 5)
      expect(approvedEventTypes, contains('category_created'));
      expect(approvedEventTypes, contains('category_selected'));
      expect(approvedEventTypes, contains('category_deselected'));
      expect(approvedEventTypes, contains('filter_applied'));
      expect(approvedEventTypes, contains('filter_cleared'));
      expect(approvedEventTypes, contains('weather_refreshed'));
      expect(approvedEventTypes, contains('settings_changed'));
      // Added for account deletion
      expect(approvedEventTypes, contains('account_deletion_requested'));
      // Present in the DB CHECK constraint since 20260520000000 but missing
      // from this list until the dataset-outcomes sprint, so calls were
      // dropped client-side before reaching Postgres.
      expect(approvedEventTypes, contains('notification_preference_changed'));
      expect(approvedEventTypes.length, 26);
    });

    test('the outcome-stage event types are all loggable', () {
      // These four close the funnel. Before this sprint every one of them was
      // approved but had no call site; the guard in log() silently drops
      // anything absent from this list, so keep them asserted.
      for (final eventType in const [
        'activity_confirmed',
        'condition_match_ignored',
        'affiliate_link_clicked',
        'activity_viewed',
      ]) {
        expect(approvedEventTypes, contains(eventType), reason: eventType);
      }
    });

    test(
      'buildPayload carries a supplied snapshot instead of the zero one',
      () {
        final service = BehavioralEventService(
          supabase: mockSupabase,
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
          appVersion: '1.0.0',
        );

        final payload = service.buildPayload(
          'activity_confirmed',
          userId: testUserId,
          conditions: buildConditionsSnapshot(
            weatherTheme: 'sunny',
            forecastDay: DailyForecast(
              date: DateTime(2026, 8, 23),
              temperatureMax: 26.0,
              temperatureMin: 14.0,
              precipitationProbability: 18.6,
              windSpeedMax: 12.0,
              weatherCode: 1000,
            ),
          ),
        );

        final conditions =
            payload['conditions_at_event'] as Map<String, dynamic>;

        expect(conditions['temp_c'], 20.0);
        expect(conditions['weather_code'], 1000);
        expect(conditions['temp_max_c'], 26.0);
      },
    );

    test('buildPayload without a snapshot keeps the historical zero shape', () {
      final service = BehavioralEventService(
        supabase: mockSupabase,
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
        appVersion: '1.0.0',
      );

      final conditions =
          service.buildPayload(
                'wishlist_added',
                userId: testUserId,
              )['conditions_at_event']
              as Map<String, dynamic>;

      // The many existing call sites that have no weather in scope must be
      // byte-for-byte unchanged.
      expect(conditions.length, 8);
      expect(conditions['temp_c'], 0.0);
      expect(conditions.containsKey('weather_code'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // Pre-auth buffering
  //
  // Onboarding logs `onboarding_completed` from steps 1, 2 and 3 — all of
  // which run before the auth page at step 5. Five of the six call sites were
  // therefore silent no-ops on every first run, and log() did not even
  // debugPrint on the no-session path, so the loss was invisible.
  // -------------------------------------------------------------------------

  group('BehavioralEventService pre-auth buffering', () {
    const testUserId = '11111111-2222-3333-4444-555555555555';
    late MockSupabaseClient mockSupabase;
    late MockGoTrueClient mockAuth;

    BehavioralEventService build() => BehavioralEventService(
      supabase: mockSupabase,
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
      appVersion: '1.0.0',
    );

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();
      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(null);
    });

    test('an event logged without a session is held, not dropped', () async {
      final service = build();

      await service.log('onboarding_completed', extra: {'step': 3});

      expect(service.pendingCount, 1);
    });

    test('an unapproved type is still rejected, not buffered', () async {
      final service = build();

      await service.log('not_a_real_event');

      expect(service.pendingCount, 0);
    });

    test('no placeholder user id is ever invented', () async {
      final service = build();
      await service.log('onboarding_completed', extra: {'step': 1});

      // Nothing may reach the table while there is no real user id — the
      // user_id column is a uuid and a stand-in would corrupt the dataset.
      verifyNever(() => mockSupabase.from(any()));
    });

    test('the buffer is bounded and keeps the most recent events', () async {
      final service = build();

      for (var i = 0; i < BehavioralEventService.maxPendingEvents + 10; i++) {
        await service.log('onboarding_completed', extra: {'step': i});
      }

      expect(
        service.pendingCount,
        BehavioralEventService.maxPendingEvents,
        reason: 'a user who never signs in must not grow this without bound',
      );
    });

    test('flushPending does nothing while there is still no session', () async {
      final service = build();
      await service.log('onboarding_completed', extra: {'step': 2});

      await service.flushPending();

      expect(service.pendingCount, 1, reason: 'still nothing to attribute to');
      verifyNever(() => mockSupabase.from(any()));
    });

    test('flushPending drains the queue once a session exists', () async {
      final service = build();
      await service.log('onboarding_completed', extra: {'step': 1});
      await service.log('onboarding_completed', extra: {'step': 2});
      expect(service.pendingCount, 2);

      final mockUser = MockUser();
      when(() => mockUser.id).thenReturn(testUserId);
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      // The insert chain is not mockable end to end here; the flush swallows
      // the resulting error by design, which is what this asserts about.
      when(() => mockSupabase.from(any())).thenThrow(
        Exception('Expected — verifying the flush reaches the table'),
      );

      await service.flushPending();

      expect(service.pendingCount, 0, reason: 'drained, never retried');
      verify(() => mockSupabase.from('behavioral_events')).called(2);
    });

    test('a buffered event keeps the time it happened, not the flush time', () {
      final service = build();
      final happenedAt = DateTime(2026, 8, 23, 9, 15);

      final payload = service.buildPayload(
        'onboarding_completed',
        userId: testUserId,
        occurredAt: happenedAt,
      );
      final temporal = payload['temporal_context'] as Map<String, dynamic>;

      // A flush can land several screens later; the funnel has to describe
      // when the step was taken.
      expect(temporal['hour_of_day'], 9);
      expect(temporal['month_of_year'], 8);
    });
  });
}
