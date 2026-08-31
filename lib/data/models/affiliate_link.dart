// Affiliate attribution — turning a search URL into an attributed one.
//
// The Find & book sheet has always built plain public search URLs: the
// OpenTable link is `opentable.com/s?term=...`, which any browser would
// produce and which earns nothing. `affiliate_link_clicked` recorded the
// intent faithfully and the click was worth zero, because nothing in the URL
// said who sent the user. Every partner click since launch has been given
// away.
//
// This file is the missing half. It does not invent a single partner
// identifier: every value comes from the `affiliate_links` table, which was
// designed for exactly this and has never had a row in it. Until Evan is
// approved by a network and inserts one, [resolveAffiliateUrl] returns the
// destination untouched and the app behaves exactly as it does today. That
// degradation is the point — the plumbing ships now, the credentials arrive
// whenever the applications clear, and no release is needed in between.

import 'booking_provider.dart';

/// One row of `affiliate_links`.
///
/// `url` is a template, not a fixed address. A search URL has to carry the
/// user's activity and city, and an affiliate network's tracking link has to
/// carry the destination, so neither works as a constant. See
/// [resolveAffiliateUrl] for the placeholders.
class AffiliateLink {
  const AffiliateLink({
    required this.id,
    required this.provider,
    required this.url,
    this.label = '',
    this.commissionType,
    this.priority = 0,
  });

  final String id;

  /// Matches [BookingProvider.name] — 'openTable', 'allTrails', and so on.
  final String provider;

  /// The template. See [resolveAffiliateUrl].
  final String url;

  final String label;

  /// Free text: 'cpa', 'cps', 'cpc'. Carried into monetization_events so
  /// revenue can be modelled per click type without another join.
  final String? commissionType;

  /// Higher wins when a provider has more than one active row — which is how
  /// a network migration is done without downtime: insert the new link at a
  /// higher priority, watch it, retire the old one.
  final int priority;

  factory AffiliateLink.fromJson(Map<String, dynamic> json) => AffiliateLink(
        id: json['id'] as String,
        provider: (json['provider'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        label: (json['label'] as String?) ?? '',
        commissionType: json['commission_type'] as String?,
        priority: (json['priority'] as num?)?.toInt() ?? 0,
      );
}

/// Applies [link] to [destination].
///
/// Three placeholders, all optional, each URL-encoded on substitution:
///
///   `{url}`   the destination this app would otherwise have opened, encoded
///             whole. This is the shape every affiliate network uses — the
///             tracking domain takes the real URL as a parameter, records the
///             click, and redirects. Impact, CJ and ShareASale all work this
///             way, which covers OpenTable, AllTrails and Eventbrite.
///   `{q}`     the activity name, for a network that wants a bare search term.
///   `{city}`  the user's "City, State".
///
/// A template with no placeholder at all is used verbatim — some programs
/// issue a single storefront link and do their own landing.
///
/// Returns [destination] unchanged when [link] is null or its template is
/// blank, so an unconfigured provider is exactly as good as it is today and
/// never worse. A template that will not parse is also treated as absent: a
/// bad row in a table nobody looks at must not cost the user their link.
Uri resolveAffiliateUrl({
  required Uri destination,
  required AffiliateLink? link,
  required String activityName,
  required String city,
}) {
  final template = link?.url.trim() ?? '';
  if (template.isEmpty) return destination;

  final substituted = template
      .replaceAll('{url}', Uri.encodeComponent(destination.toString()))
      .replaceAll('{q}', Uri.encodeComponent(activityName.trim()))
      .replaceAll('{city}', Uri.encodeComponent(city.trim()));

  final parsed = Uri.tryParse(substituted);
  // A relative or schemeless result would be launched as a file path by the
  // OS. Only an absolute http(s) URL is worth handing to the browser.
  if (parsed == null ||
      !(parsed.isScheme('https') || parsed.isScheme('http'))) {
    return destination;
  }
  return parsed;
}

/// The highest-priority active link for [provider], or null.
///
/// Ties break on id so the choice is stable: two rows at the same priority
/// must not alternate between launches, or click-through per link becomes
/// uninterpretable.
AffiliateLink? linkFor(
  BookingProvider provider,
  List<AffiliateLink> links,
) {
  final matches = links.where((l) => l.provider == provider.name).toList()
    ..sort((a, b) =>
        b.priority.compareTo(a.priority) != 0
            ? b.priority.compareTo(a.priority)
            : a.id.compareTo(b.id));
  return matches.isEmpty ? null : matches.first;
}
