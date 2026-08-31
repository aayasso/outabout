// Reads affiliate_links, and writes the monetization_events that make partner
// activity countable in money rather than only in taps.
//
// Both halves have existed in the schema since the beginning and neither has
// ever been used: affiliate_links has never had a row, and monetization_events
// has never had an insert. behavioral_events carries partner_impression_viewed
// and affiliate_link_clicked, which answer "did anyone tap", but they live in
// the intelligence dataset and know nothing about commission type or which
// link was responsible. monetization_events is the table that does, and
// behavioral_events.monetization_event_id is the join that was designed to
// connect them.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../models/affiliate_link.dart';

class AffiliateLinkRepository {
  AffiliateLinkRepository(this._client);

  final SupabaseClient _client;

  /// Every active link, newest configuration first.
  ///
  /// Fetched whole rather than per provider: the table is configuration, not
  /// user data — a handful of rows, one per partner program — and one request
  /// per sheet is cheaper than one per row rendered in it.
  Future<List<AffiliateLink>> active() async {
    final rows = await _client
        .from('affiliate_links')
        .select('id, provider, url, label, commission_type, priority')
        .eq('is_active', true);
    return (rows as List)
        .map((r) => AffiliateLink.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Records a partner impression or click, returning the new row's id.
  ///
  /// Returns null on failure and never throws. The same rule
  /// BehavioralEventService.log follows, for the same reason: a user tapping
  /// "OpenTable" must reach OpenTable whatever the analytics layer is doing.
  /// The cost of that choice is an undercount, which is the right direction to
  /// be wrong in — a revenue number that overstates itself is worse than one
  /// that is quietly conservative.
  Future<String?> logMonetizationEvent({
    required String eventType,
    required String? affiliateLinkId,
    required String? activityId,
    required String? activityCategory,
    required Map<String, dynamic> conditions,
    required String? region,
    required DateTime now,
  }) async {
    try {
      final row = await _client
          .from('monetization_events')
          .insert({
            'event_type': eventType,
            'affiliate_link_id': ?affiliateLinkId,
            'activity_id': ?activityId,
            'activity_category': ?activityCategory,
            // Flattened out of the conditions snapshot rather than stored as
            // jsonb: these are the columns aggregate_insights averages over,
            // and a rollup that has to reach into jsonb to find temperature
            // cannot use an index.
            'weather_temp_c': ?conditions['temp_c'],
            'weather_condition': ?conditions['weather_theme'],
            'weather_wind_kph': ?conditions['wind_kph'],
            'weather_uv_index': ?conditions['uv_index'],
            'region': ?region,
            'country': 'US',
            'hour_of_day': now.hour,
            // Postgres and Dart disagree on where the week starts: Dart's
            // DateTime.weekday is 1..7 from Monday, and every other temporal
            // context in this codebase stores 0..6 from Sunday, matching
            // JavaScript's getDay() in the edge function. Converted here so
            // the two halves of the dataset can be compared without a lookup
            // table that only exists in someone's head.
            'day_of_week': now.weekday % 7,
            'month_of_year': now.month,
            'user_id': _client.auth.currentUser?.id,
          })
          .select('id')
          .single();
      return row['id'] as String?;
    } catch (e) {
      debugPrint('logMonetizationEvent: $eventType not recorded — $e');
      return null;
    }
  }
}

final affiliateLinkRepositoryProvider = Provider<AffiliateLinkRepository>((ref) {
  return AffiliateLinkRepository(ref.watch(supabaseClientProvider));
});

/// The active links, fetched once per app session.
///
/// Configuration changes when Evan is approved by a network, not while a user
/// is deciding where to eat, so a session-lifetime cache is generous. An error
/// resolves to an empty list rather than propagating: no affiliate rows is the
/// app's normal state today, and it must never be the reason a sheet fails to
/// open.
final affiliateLinksProvider = FutureProvider<List<AffiliateLink>>((ref) async {
  try {
    return await ref.watch(affiliateLinkRepositoryProvider).active();
  } catch (e) {
    debugPrint('affiliateLinksProvider: falling back to unattributed links — $e');
    return const [];
  }
});
