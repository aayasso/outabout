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
  allTrails('AllTrails', 'Trails and routes'),
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
/// Photography, picnics and parks have no rule and fall through to Google Maps
/// on purpose.
///
/// AllTrails is offered by city page rather than by search: its `/search?q=`
/// discards the term and redirects to a geolocated `/explore`, but
/// `/us/{state}/{city}` is a real, URL-addressable page. That page 404s for a
/// city AllTrails has never heard of, so [providersFor] drops it whenever the
/// city cannot be resolved, and Google Maps always follows it in the sheet so
/// a 404 is never a dead end.
const List<_ProviderRule> _providerRules = [
  // GolfNow stays out. It ignores both `q` and `searchterm` and keeps its own
  // default city, and its city pages are keyed by an opaque numeric id
  // (/course-directory/us/ca/17245-san-francisco) that cannot be derived from
  // a name. Only the state page is constructible, and "California golf
  // courses" is worse than what Google Maps and Yelp return for the user's
  // actual city.
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
    ['hik', 'trail', 'trek', 'backpack'],
    [BookingProvider.allTrails, BookingProvider.googleMaps],
  ),
  _ProviderRule(
    ['run', 'jog'],
    [BookingProvider.allTrails, BookingProvider.googleMaps],
  ),
  _ProviderRule(
    ['cycl', 'bike', 'biking', 'mtb'],
    [BookingProvider.allTrails, BookingProvider.googleMaps],
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
    [BookingProvider.allTrails, BookingProvider.googleMaps],
  ),
];

// ---------------------------------------------------------------------------
// US location parsing (AllTrails city pages)
// ---------------------------------------------------------------------------

/// US state and territory abbreviations to the names AllTrails uses in its
/// paths.
///
/// AllTrails will not accept the abbreviation — `/us/ca/san-francisco` 404s
/// while `/us/california/san-francisco` resolves — and `userLocationProvider`
/// gives us "San Francisco, CA", so the two have to be bridged. A static map
/// rather than a lookup: this is closed, well-known data that has not changed
/// in decades, and no network call belongs on a link tap.
const Map<String, String> usStateNames = {
  'al': 'alabama',
  'ak': 'alaska',
  'az': 'arizona',
  'ar': 'arkansas',
  'ca': 'california',
  'co': 'colorado',
  'ct': 'connecticut',
  'de': 'delaware',
  'dc': 'district-of-columbia',
  'fl': 'florida',
  'ga': 'georgia',
  'hi': 'hawaii',
  'id': 'idaho',
  'il': 'illinois',
  'in': 'indiana',
  'ia': 'iowa',
  'ks': 'kansas',
  'ky': 'kentucky',
  'la': 'louisiana',
  'me': 'maine',
  'md': 'maryland',
  'ma': 'massachusetts',
  'mi': 'michigan',
  'mn': 'minnesota',
  'ms': 'mississippi',
  'mo': 'missouri',
  'mt': 'montana',
  'ne': 'nebraska',
  'nv': 'nevada',
  'nh': 'new-hampshire',
  'nj': 'new-jersey',
  'nm': 'new-mexico',
  'ny': 'new-york',
  'nc': 'north-carolina',
  'nd': 'north-dakota',
  'oh': 'ohio',
  'ok': 'oklahoma',
  'or': 'oregon',
  'pa': 'pennsylvania',
  'ri': 'rhode-island',
  'sc': 'south-carolina',
  'sd': 'south-dakota',
  'tn': 'tennessee',
  'tx': 'texas',
  'ut': 'utah',
  'vt': 'vermont',
  'va': 'virginia',
  'wa': 'washington',
  'wv': 'west-virginia',
  'wi': 'wisconsin',
  'wy': 'wyoming',
};

/// One resolved US location, in the slug form AllTrails' paths want.
typedef UsCityPath = ({String citySlug, String stateSlug});

/// Parses `userLocationProvider`'s "City, State" string.
///
/// Returns null when the string is empty, has no state part, or names a state
/// this map does not cover — which includes every non-US location. Callers
/// treat null as "AllTrails cannot serve this user", never as "guess".
///
/// Accepts either the abbreviation ("CA") or the full name ("California"),
/// because the geocoder's `administrativeArea` is not guaranteed to be one or
/// the other across platforms.
UsCityPath? parseUsCityPath(String cityLine) {
  final separator = cityLine.lastIndexOf(',');
  if (separator <= 0) return null;

  final cityPart = cityLine.substring(0, separator).trim();
  final statePart = cityLine.substring(separator + 1).trim().toLowerCase();
  if (cityPart.isEmpty || statePart.isEmpty) return null;

  final stateSlug = usStateNames[statePart] ??
      (usStateNames.containsValue(_slug(statePart)) ? _slug(statePart) : null);
  if (stateSlug == null) return null;

  final citySlug = _slug(cityPart);
  if (citySlug.isEmpty) return null;

  return (citySlug: citySlug, stateSlug: stateSlug);
}

/// The universal fallback. Google Maps can answer "where near me" for anything.
const List<BookingProvider> fallbackProviders = [BookingProvider.googleMaps];

/// Resolves which providers to offer for an activity.
///
/// [categoryNames] are the activity's category names, [activityName] its own
/// name. Both are searched because a user who never assigns a category still
/// tells us what they are doing by naming it "Sunday tennis".
///
/// [city] is `userLocationProvider`'s "City, State" string. It is needed here,
/// not just when building the URL, because AllTrails can only be offered when
/// that city resolves to one of its city pages — offering it otherwise would
/// send the user to a guaranteed 404. Dropping it never empties the list:
/// every rule that names AllTrails also names Google Maps.
List<BookingProvider> providersFor({
  required String activityName,
  List<String> categoryNames = const [],
  String city = '',
}) {
  final haystack = [activityName, ...categoryNames].join(' ').toLowerCase();

  for (final rule in _providerRules) {
    if (rule.keywords.any(haystack.contains)) {
      return rule.providers.where((p) => _canServe(p, city)).toList();
    }
  }
  return fallbackProviders;
}

/// Whether [provider] can build a working link for [city].
///
/// Only AllTrails is city-gated; every other provider either takes a free-text
/// location or falls back to the browser's own.
bool _canServe(BookingProvider provider, String city) {
  if (provider != BookingProvider.allTrails) return true;
  return parseUsCityPath(city) != null;
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
    // Path-based, and only reachable when the city resolved — see
    // [providersFor]. The Google Maps fallback here is unreachable in
    // practice; it exists so this function stays total rather than throwing on
    // a caller that skipped the filter.
    BookingProvider.allTrails => switch (parseUsCityPath(city)) {
        final UsCityPath path => Uri.https(
            'www.alltrails.com',
            '/us/${path.stateSlug}/${path.citySlug}',
          ),
        null => Uri.https(
            'www.google.com',
            '/maps/search/',
            {'api': '1', 'query': withCity},
          ),
      },
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
