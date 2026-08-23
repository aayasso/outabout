// ---------------------------------------------------------------------------
// Booking providers — category/name keyword mapping and URL construction
// ---------------------------------------------------------------------------
//
// URL construction only. No APIs, no auth, no keys: every link is a public
// search URL the provider serves to anyone. Nothing here performs I/O, so the
// whole mapping is testable as plain functions.

/// A third-party site that can answer "where do I actually do this?".
enum BookingProvider {
  googleMaps('Google Maps', 'Search nearby places'),
  yelp('Yelp', 'Reviews and listings'),
  eventbrite('Eventbrite', 'Local events'),
  playtomic('Playtomic', 'Court bookings'),
  mindbody('Mindbody', 'Classes and studios'),
  openTable('OpenTable', 'Table reservations');

  const BookingProvider(this.label, this.subtitle);

  /// Shown as the row title in the Find & book sheet.
  final String label;

  /// One-line hint under the title.
  final String subtitle;
}

/// One row of the keyword map.
class _ProviderRule {
  const _ProviderRule(this.keywords, this.providers);
  final List<String> keywords;
  final List<BookingProvider> providers;
}

/// Keyword rules, evaluated in order — first match wins.
///
/// Categories in OutAbout are user-created free text (the eight seeded
/// defaults are Running, Hiking, Cycling, Photography, Beach, Skiing, Camping,
/// Picnic), so there is no fixed taxonomy to switch on. Matching is substring,
/// over the activity's category names *and* its own name.
///
/// Order is the tiebreak and is deliberate: the specific, bookable activities
/// come first so "Golf Yoga Retreat" resolves to golf rather than to fitness.
///
/// Hiking, running, cycling, photography, picnics and parks have no rule and
/// fall through to Google Maps on purpose. AllTrails was the natural provider
/// for the first three, but it has no URL-addressable search: `/search?q=`
/// redirects to a geolocated `/explore` and discards the term entirely, so a
/// link would always land the user on "trails near wherever the browser thinks
/// you are" no matter what they tapped. Google Maps answers the same question
/// and actually honours the query.
const List<_ProviderRule> _providerRules = [
  // GolfNow is absent for the same reason as AllTrails: it ignores both `q`
  // and `searchterm` and keeps its own default city, so the link would be
  // actively misleading.
  _ProviderRule(
    ['golf'],
    [BookingProvider.googleMaps, BookingProvider.yelp],
  ),
  _ProviderRule(
    ['tennis', 'pickle', 'padel', 'squash'],
    [BookingProvider.playtomic, BookingProvider.googleMaps],
  ),
  _ProviderRule(
    ['gym', 'fitness', 'yoga', 'pilates', 'workout', 'climb'],
    [BookingProvider.mindbody, BookingProvider.googleMaps],
  ),
  _ProviderRule(
    ['dining', 'restaurant', 'brunch', 'dinner', 'lunch', 'patio', 'coffee'],
    [
      BookingProvider.openTable,
      BookingProvider.yelp,
      BookingProvider.googleMaps,
    ],
  ),
  _ProviderRule(
    ['concert', 'festival', 'event', 'market', 'show'],
    [BookingProvider.eventbrite, BookingProvider.googleMaps],
  ),
  _ProviderRule(
    ['beach', 'surf', 'swim', 'kayak', 'paddle', 'sail'],
    [BookingProvider.googleMaps, BookingProvider.yelp],
  ),
  _ProviderRule(
    ['ski', 'snowboard', 'snow'],
    [BookingProvider.googleMaps, BookingProvider.yelp],
  ),
  _ProviderRule(
    ['camp'],
    [BookingProvider.googleMaps, BookingProvider.yelp],
  ),
];

/// The universal fallback. Google Maps can answer "where near me" for anything.
const List<BookingProvider> fallbackProviders = [BookingProvider.googleMaps];

/// Resolves which providers to offer for an activity.
///
/// [categoryNames] are the activity's category names, [activityName] its own
/// name. Both are searched because a user who never assigns a category still
/// tells us what they are doing by naming it "Sunday tennis".
List<BookingProvider> providersFor({
  required String activityName,
  List<String> categoryNames = const [],
}) {
  final haystack = [activityName, ...categoryNames].join(' ').toLowerCase();

  for (final rule in _providerRules) {
    if (rule.keywords.any(haystack.contains)) return rule.providers;
  }
  return fallbackProviders;
}

// ---------------------------------------------------------------------------
// URL construction
// ---------------------------------------------------------------------------

/// Lowercase, hyphenated slug for providers whose search lives in the path.
String _slug(String value) {
  final lowered = value.toLowerCase().trim();
  final cleaned = lowered.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Builds the search URL for [provider].
///
/// [city] is whatever `userLocationProvider` resolved, in "City, State" form;
/// it may be empty, and every URL below stays valid without it — the provider
/// then falls back to the browser's own location.
Uri bookingUrl({
  required BookingProvider provider,
  required String activityName,
  required String city,
}) {
  final term = activityName.trim();
  final withCity = city.isEmpty ? term : '$term $city';

  return switch (provider) {
    BookingProvider.googleMaps => Uri.https(
        'www.google.com',
        '/maps/search/',
        {'api': '1', 'query': withCity},
      ),
    BookingProvider.yelp => Uri.https(
        'www.yelp.com',
        '/search',
        {'find_desc': term, if (city.isNotEmpty) 'find_loc': city},
      ),
    BookingProvider.eventbrite => Uri.https(
        'www.eventbrite.com',
        '/d/${city.isEmpty ? 'online' : _slug(city)}/${_slug(term)}/',
      ),
    BookingProvider.playtomic => Uri.https(
        'playtomic.com',
        '/search',
        {'q': city.isEmpty ? term : city},
      ),
    BookingProvider.mindbody => Uri.https(
        'www.mindbodyonline.com',
        '/explore/search',
        {'q': term, if (city.isNotEmpty) 'location': city},
      ),
    BookingProvider.openTable => Uri.https(
        'www.opentable.com',
        '/s',
        {'term': withCity, 'covers': '2'},
      ),
  };
}
