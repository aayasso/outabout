import 'package:flutter_test/flutter_test.dart';

import 'package:outabout/data/models/booking_provider.dart';

void main() {
  group('providersFor', () {
    test('falls back to Google Maps when nothing matches', () {
      expect(providersFor(activityName: 'Sitting quietly'), [
        BookingProvider.googleMaps,
      ]);
    });

    test('matches on the activity name alone', () {
      expect(providersFor(activityName: 'Sunday tennis'), [
        BookingProvider.playtomic,
        BookingProvider.googleMaps,
      ]);
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
      expect(providersFor(activityName: 'Golf yoga retreat'), [
        BookingProvider.googleMaps,
        BookingProvider.yelp,
      ]);
    });

    test('substring keywords match inflections', () {
      // 'hik' catches hike/hiking, 'cycl' catches cycle/cycling.
      expect(
        providersFor(activityName: 'Morning hike', city: 'Boulder, CO').first,
        BookingProvider.allTrails,
      );
      expect(
        providersFor(activityName: 'Cycling club', city: 'Boulder, CO').first,
        BookingProvider.allTrails,
      );
    });

    test('outdoor activities lead with AllTrails, Google Maps second', () {
      for (final name in [
        'Trail run',
        'Morning jog',
        'Backpacking trip',
        'Camping weekend',
        'Mountain biking',
      ]) {
        expect(providersFor(activityName: name, city: 'Denver, CO'), [
          BookingProvider.allTrails,
          BookingProvider.googleMaps,
        ], reason: name);
      }
    });

    test('AllTrails is dropped when the city cannot be resolved', () {
      // A link to an AllTrails city page that does not exist is a guaranteed
      // 404, which is worse than the Google Maps result we already have.
      for (final city in ['', 'Toronto, ON', 'Paris', 'Berlin, Germany']) {
        expect(
          providersFor(activityName: 'Morning hike', city: city),
          [BookingProvider.googleMaps],
          reason: 'city: "$city"',
        );
      }
    });

    test('dropping AllTrails never leaves an empty sheet', () {
      for (final name in ['Trail run', 'Camping weekend', 'Cycling club']) {
        expect(
          providersFor(activityName: name, city: ''),
          isNotEmpty,
          reason: name,
        );
      }
    });

    test('GolfNow stays out — golf resolves to Google Maps and Yelp', () {
      expect(providersFor(activityName: 'Golf at dawn', city: 'Denver, CO'), [
        BookingProvider.googleMaps,
        BookingProvider.yelp,
      ]);
    });

    test('every rule resolves to at least one provider', () {
      // The body used to loop BookingProvider.values asserting labels were
      // non-empty — it never called providersFor at all, which is what the
      // name claims. A user must never open the sheet to an empty list.
      const activities = [
        'Golf at dawn',
        'Morning run',
        'Hiking the ridge',
        'Dinner out',
        'Kayaking',
        'Something with no rule at all',
      ];
      for (final name in activities) {
        expect(
          providersFor(activityName: name, city: 'Denver, CO'),
          isNotEmpty,
          reason: name,
        );
      }
      // And with no city, where the city-scoped providers drop out.
      for (final name in activities) {
        expect(
          providersFor(activityName: name, city: ''),
          isNotEmpty,
          reason: '$name (no city)',
        );
      }
    });
  });

  group('parseUsCityPath', () {
    test('splits the geocoder\'s "City, ST" into AllTrails slugs', () {
      final path = parseUsCityPath('San Francisco, CA');

      expect(path?.citySlug, 'san-francisco');
      expect(path?.stateSlug, 'california');
    });

    test('accepts a full state name as well as the abbreviation', () {
      expect(
        parseUsCityPath('Asheville, North Carolina')?.stateSlug,
        'north-carolina',
      );
      expect(parseUsCityPath('Asheville, NC')?.stateSlug, 'north-carolina');
    });

    test('is case insensitive on the state', () {
      expect(parseUsCityPath('Denver, co')?.stateSlug, 'colorado');
      expect(parseUsCityPath('Denver, CO')?.stateSlug, 'colorado');
    });

    test('handles multi-word states and DC', () {
      expect(parseUsCityPath('Newark, NJ')?.stateSlug, 'new-jersey');
      expect(
        parseUsCityPath('Washington, DC')?.stateSlug,
        'district-of-columbia',
      );
    });

    test('slugs multi-word city names', () {
      expect(parseUsCityPath('Salt Lake City, UT')?.citySlug, 'salt-lake-city');
      expect(parseUsCityPath("Coeur d'Alene, ID")?.citySlug, 'coeur-d-alene');
    });

    test('returns null rather than guessing', () {
      for (final input in [
        '',
        'Paris',
        'Toronto, ON',
        'Berlin, Germany',
        ', CA',
        'San Francisco, ',
        'San Francisco, ZZ',
      ]) {
        expect(parseUsCityPath(input), isNull, reason: 'input: "$input"');
      }
    });

    test('splits on the last comma, so a three-part line still resolves', () {
      final path = parseUsCityPath('Brooklyn, New York, NY');

      expect(path?.stateSlug, 'new-york');
      expect(path?.citySlug, 'brooklyn-new-york');
    });

    test('covers all 50 states plus DC', () {
      expect(usStateNames.length, 51);
      // Slugs are what goes into the path, so none may carry a space.
      for (final name in usStateNames.values) {
        expect(name, isNot(contains(' ')), reason: name);
        expect(name, equals(name.toLowerCase()), reason: name);
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
        expect(
          url.queryParameters.values.any((v) => v.isEmpty),
          isFalse,
          reason: provider.name,
        );
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

    test('AllTrails uses its city page, not a search query', () {
      final url = bookingUrl(
        provider: BookingProvider.allTrails,
        activityName: 'Morning hike',
        city: city,
      );

      // Verified live: /us/california/san-francisco renders "Best trails in
      // San Francisco". The abbreviation form (/us/ca/...) 404s.
      expect(url.host, 'www.alltrails.com');
      expect(url.path, '/us/california/san-francisco');
      expect(url.queryParameters, isEmpty);
    });

    test('AllTrails ignores the activity name — the page is the city', () {
      final hike = bookingUrl(
        provider: BookingProvider.allTrails,
        activityName: 'Morning hike',
        city: city,
      );
      final ride = bookingUrl(
        provider: BookingProvider.allTrails,
        activityName: 'Evening bike ride',
        city: city,
      );

      expect(hike, ride);
    });

    test('AllTrails degrades to Google Maps if the city never resolved', () {
      // providersFor filters this case out, so it is unreachable in the app.
      // Asserted so the function stays total rather than throwing.
      final url = bookingUrl(
        provider: BookingProvider.allTrails,
        activityName: 'Morning hike',
        city: 'Toronto, ON',
      );

      expect(url.host, 'www.google.com');
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
