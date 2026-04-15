import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/models/behavioral_event.dart';
import 'package:outabout/services/behavioral_event_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

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

    setUp(() {
      mockSupabase = MockSupabaseClient();
      mockAuth = MockGoTrueClient();

      when(() => mockSupabase.auth).thenReturn(mockAuth);
      when(() => mockAuth.currentUser).thenReturn(null);
    });

    test('rejects unknown event types without calling Supabase', () async {
      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: 'sunny',
        appVersion: '1.0.0',
      );

      await service.log('unknown_event_type');

      // Should never call from() for an invalid event type.
      verifyNever(() => mockSupabase.from(any()));
    });

    test('never throws — catches errors internally', () async {
      // Make from() throw to simulate Supabase failure.
      when(() => mockSupabase.from(any()))
          .thenThrow(Exception('Supabase error'));

      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: 'sunny',
        appVersion: '1.0.0',
      );

      // Should not throw.
      await expectLater(
        service.log('wishlist_added'),
        completes,
      );
    });

    test('calls from(behavioral_events) for valid event types', () async {
      // Make from() throw so we can verify it was called
      // (we can't easily mock the full insert chain).
      when(() => mockSupabase.from('behavioral_events'))
          .thenThrow(Exception('Expected — verifying table name'));

      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: 'sunny',
        appVersion: '1.0.0',
      );

      await service.log('wishlist_added');

      // Verify from() was called with correct table name.
      verify(() => mockSupabase.from('behavioral_events')).called(1);
    });

    test('builds correct insert payload via buildPayload', () {
      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: 'rainy',
        appVersion: '2.0.0',
      );

      final payload = service.buildPayload(
        'activity_viewed',
        extra: {'activity_id': 'abc-123'},
      );

      expect(payload['event_type'], 'activity_viewed');
      expect(payload['user_id'], 'anonymous');

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

    test('buildPayload sets correct temporal context from DateTime.now()',
        () {
      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: 'sunny',
        appVersion: '1.0.0',
      );

      final payload = service.buildPayload('wishlist_added');
      final temporal =
          payload['temporal_context'] as Map<String, dynamic>;

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

    test('buildPayload sets geographic context defaults', () {
      final service = BehavioralEventService(
        supabase: mockSupabase,
        activeThemeName: 'sunny',
        appVersion: '1.0.0',
      );

      final payload = service.buildPayload('wishlist_added');
      final geo = payload['geographic_context'] as Map<String, dynamic>;

      expect(geo['country'], 'US');
      expect(geo['lat_bucketed'], 0.0);
      expect(geo['lng_bucketed'], 0.0);
      expect(geo['metro'], '');
      expect(geo['city'], '');
      expect(geo['state'], '');
      expect(geo['timezone'], '');
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
      expect(approvedEventTypes.length, 17);
    });
  });
}
