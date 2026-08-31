// Tests for affiliate attribution.
//
// The property that matters most here is the one that is easiest to lose:
// with no affiliate_links rows configured — which is the app's state today and
// for as long as the partner applications take — every link must be byte-for-
// byte what it was before this feature existed. A revenue feature that
// degrades a working link while earning nothing is strictly worse than not
// shipping it.

import 'package:flutter_test/flutter_test.dart';
import 'package:outabout/data/models/affiliate_link.dart';
import 'package:outabout/data/models/booking_provider.dart';

void main() {
  final destination = Uri.https('www.opentable.com', '/s', {
    'term': 'Dinner Pittsburgh, PA',
    'covers': '2',
  });

  AffiliateLink link(String url, {String provider = 'openTable', int priority = 0, String id = 'l1'}) =>
      AffiliateLink(id: id, provider: provider, url: url, priority: priority);

  group('resolveAffiliateUrl', () {
    test('an unconfigured provider is left exactly as it is today', () {
      // The whole degradation guarantee, in one assertion.
      expect(
        resolveAffiliateUrl(
          destination: destination,
          link: null,
          activityName: 'Dinner',
          city: 'Pittsburgh, PA',
        ),
        destination,
      );
    });

    test('a blank or whitespace template is treated as absent', () {
      for (final template in ['', '   ']) {
        expect(
          resolveAffiliateUrl(
            destination: destination,
            link: link(template),
            activityName: 'Dinner',
            city: 'Pittsburgh, PA',
          ),
          destination,
        );
      }
    });

    test('{url} carries the whole destination, encoded', () {
      // The shape every affiliate network uses: the tracking domain takes the
      // real URL, records the click, and redirects.
      final result = resolveAffiliateUrl(
        destination: destination,
        link: link('https://goto.example.com/c/123?u={url}'),
        activityName: 'Dinner',
        city: 'Pittsburgh, PA',
      );
      expect(result.host, 'goto.example.com');
      expect(result.queryParameters['u'], destination.toString());
    });

    test('{q} and {city} are substituted and encoded', () {
      final result = resolveAffiliateUrl(
        destination: destination,
        link: link('https://partner.example.com/s?term={q}&loc={city}'),
        activityName: 'Sunday Brunch',
        city: 'Pittsburgh, PA',
      );
      expect(result.queryParameters['term'], 'Sunday Brunch');
      expect(result.queryParameters['loc'], 'Pittsburgh, PA');
    });

    test('a template with no placeholder is used verbatim', () {
      // Some programs issue one storefront link and do their own landing.
      final result = resolveAffiliateUrl(
        destination: destination,
        link: link('https://partner.example.com/outabout'),
        activityName: 'Dinner',
        city: 'Pittsburgh, PA',
      );
      expect(result.toString(), 'https://partner.example.com/outabout');
    });

    test('a template that will not parse falls back rather than breaking', () {
      // A bad row in a table nobody looks at must not cost the user their link.
      for (final template in ['not a url', 'ftp://files.example.com/x', '/relative/path']) {
        expect(
          resolveAffiliateUrl(
            destination: destination,
            link: link(template),
            activityName: 'Dinner',
            city: 'Pittsburgh, PA',
          ),
          destination,
          reason: 'template "$template" should fall back',
        );
      }
    });

    test('an empty city does not leave a literal placeholder in the URL', () {
      final result = resolveAffiliateUrl(
        destination: destination,
        link: link('https://partner.example.com/s?loc={city}'),
        activityName: 'Dinner',
        city: '',
      );
      expect(result.toString(), isNot(contains('{city}')));
      expect(result.queryParameters['loc'], '');
    });
  });

  group('linkFor', () {
    test('returns null when no row names this provider', () {
      expect(linkFor(BookingProvider.openTable, const []), isNull);
      expect(
        linkFor(BookingProvider.openTable, [link('https://x.test', provider: 'yelp')]),
        isNull,
      );
    });

    test('the highest priority wins, which is how a link is migrated', () {
      final chosen = linkFor(BookingProvider.openTable, [
        link('https://old.test', id: 'a', priority: 0),
        link('https://new.test', id: 'b', priority: 10),
      ]);
      expect(chosen!.url, 'https://new.test');
    });

    test('a tie is broken stably, so click-through stays interpretable', () {
      final rows = [
        link('https://b.test', id: 'b', priority: 5),
        link('https://a.test', id: 'a', priority: 5),
      ];
      expect(linkFor(BookingProvider.openTable, rows)!.id, 'a');
      expect(linkFor(BookingProvider.openTable, rows.reversed.toList())!.id, 'a');
    });

    test('provider names match BookingProvider.name exactly', () {
      // The join between a config row and a rendered button. A rename on
      // either side silently stops attributing, and earns nothing while
      // looking fine.
      for (final provider in BookingProvider.values) {
        final rows = [link('https://x.test/{url}', provider: provider.name)];
        expect(linkFor(provider, rows), isNotNull, reason: provider.name);
      }
    });
  });

  group('AffiliateLink.fromJson', () {
    test('reads a row and tolerates the nullable columns', () {
      final l = AffiliateLink.fromJson({
        'id': 'l1',
        'provider': 'allTrails',
        'url': 'https://goto.test/{url}',
        'label': 'AllTrails via Impact',
        'commission_type': 'cps',
        'priority': 3,
      });
      expect(l.provider, 'allTrails');
      expect(l.commissionType, 'cps');
      expect(l.priority, 3);
    });

    test('a row missing its optional columns still constructs', () {
      final l = AffiliateLink.fromJson({'id': 'l2', 'url': 'https://x.test'});
      expect(l.provider, '');
      expect(l.commissionType, isNull);
      expect(l.priority, 0);
    });
  });
}
