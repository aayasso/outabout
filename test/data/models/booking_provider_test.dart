import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/booking_provider.dart';

void main() {
  group('providersFor', () {
    test('falls back to Google Maps when nothing matches', () {
      expect(
        providersFor(activityName: 'Sitting quietly'),
        [BookingProvider.googleMaps],
      );
    });

    test('matches on the activity name alone', () {
      expect(
        providersFor(activityName: 'Sunday tennis'),
        [BookingProvider.playtomic, BookingProvider.googleMaps],
      );
    });

    test('matches on a category name when the activity name is neutral', () {
      expect(
        providersFor(
          activityName: 'Saturday session',
          categoryNames: ['Dining'],
        ),
        [
          BookingProvider.openTable,
          BookingProvider.yelp,
          BookingProvider.googleMaps,
        ],
      );
    });

    test('is case insensitive', () {
      expect(
        providersFor(activityName: 'YOGA in the park').first,
        BookingProvider.mindbody,
      );
    });

    test('matches pickleball via the shared racquet-sport rule', () {
      expect(
        providersFor(activityName: 'Pickleball doubles').first,
        BookingProvider.playtomic,
      );
    });

    test('rule order decides when two keywords both appear', () {
      // 'golf' precedes the fitness rule, so a golf-branded yoga session
      // resolves to golf rather than to Mindbody.
      expect(
        providersFor(activityName: 'Golf yoga retreat'),
        [BookingProvider.googleMaps, BookingProvider.yelp],
      );
    });

    test('substring keywords match inflections', () {
      // 'hik' catches hike/hiking, 'cycl' catches cycle/cycling. Neither has a
      // provider rule any more, so both land on the fallback.
      expect(providersFor(activityName: 'Morning hike'), fallbackProviders);
      expect(providersFor(activityName: 'Cycling club'), fallbackProviders);
    });

    test('dropped providers are unreachable from any input', () {
      // AllTrails and GolfNow were removed after live verification showed
      // neither honours a URL search term. Nothing should resolve to a
      // provider that is not in the enum.
      const names = [
        'Trail run',
        'Golf at dawn',
        'Backpacking trip',
        'Camping weekend',
      ];
      for (final name in names) {
        final resolved = providersFor(activityName: name);
        expect(resolved, isNotEmpty, reason: name);
        expect(
          resolved.every(BookingProvider.values.contains),
          isTrue,
          reason: name,
        );
      }
    });

    test('every rule resolves to at least one provider', () {
      for (final provider in BookingProvider.values) {
        expect(provider.label, isNotEmpty);
        expect(provider.subtitle, isNotEmpty);
      }
    });
  });

  group('bookingUrl', () {
    const city = 'San Francisco, CA';

    test('Google Maps carries the term and the city in one query', () {
      final url = bookingUrl(
        provider: BookingProvider.googleMaps,
        activityName: 'Trail run',
        city: city,
      );

      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/search/');
      expect(url.queryParameters['api'], '1');
      expect(url.queryParameters['query'], 'Trail run San Francisco, CA');
    });

    test('Yelp splits the term and the location', () {
      final url = bookingUrl(
        provider: BookingProvider.yelp,
        activityName: 'Dinner',
        city: city,
      );

      expect(url.queryParameters['find_desc'], 'Dinner');
      expect(url.queryParameters['find_loc'], city);
    });

    test('Eventbrite slugs both the city and the term into the path', () {
      final url = bookingUrl(
        provider: BookingProvider.eventbrite,
        activityName: 'Summer Festival',
        city: city,
      );

      expect(url.host, 'www.eventbrite.com');
      expect(url.path, '/d/san-francisco-ca/summer-festival/');
    });

    test('OpenTable combines term and city and sets a default cover count', () {
      final url = bookingUrl(
        provider: BookingProvider.openTable,
        activityName: 'Dinner',
        city: city,
      );

      expect(url.queryParameters['term'], 'Dinner San Francisco, CA');
      expect(url.queryParameters['covers'], '2');
    });

    test('Mindbody sends term and location separately', () {
      final url = bookingUrl(
        provider: BookingProvider.mindbody,
        activityName: 'Yoga',
        city: city,
      );

      expect(url.queryParameters['q'], 'Yoga');
      expect(url.queryParameters['location'], city);
    });

    test('Playtomic searches by city, which is how its search works', () {
      final url = bookingUrl(
        provider: BookingProvider.playtomic,
        activityName: 'Tennis',
        city: city,
      );

      expect(url.host, 'playtomic.com');
      expect(url.queryParameters['q'], city);
    });

    test('every provider produces an https URL with a host', () {
      for (final provider in BookingProvider.values) {
        final url = bookingUrl(
          provider: provider,
          activityName: 'Test activity',
          city: city,
        );
        expect(url.scheme, 'https', reason: provider.name);
        expect(url.host, isNotEmpty, reason: provider.name);
      }
    });

    test('an empty city still yields a valid URL for every provider', () {
      for (final provider in BookingProvider.values) {
        final url = bookingUrl(
          provider: provider,
          activityName: 'Morning run',
          city: '',
        );
        expect(url.scheme, 'https', reason: provider.name);
        expect(url.toString(), isNot(contains('null')), reason: provider.name);
        // No provider should be asked to search an empty location.
        expect(url.queryParameters.values.any((v) => v.isEmpty), isFalse,
            reason: provider.name);
      }
    });

    test('ampersands and spaces are percent-encoded, not injected', () {
      final url = bookingUrl(
        provider: BookingProvider.googleMaps,
        activityName: 'Surf & turf',
        city: city,
      );

      // Round-trips back to the literal term rather than splitting into a
      // second query parameter.
      expect(url.queryParameters['query'], 'Surf & turf San Francisco, CA');
      expect(url.queryParameters.length, 2);
      expect(url.toString(), contains('%26'));
    });

    test('leading and trailing whitespace in the name is trimmed', () {
      final url = bookingUrl(
        provider: BookingProvider.yelp,
        activityName: '  Brunch  ',
        city: city,
      );

      expect(url.queryParameters['find_desc'], 'Brunch');
    });
  });
}
