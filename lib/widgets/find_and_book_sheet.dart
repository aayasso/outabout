import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../core/theme.dart';
import '../core/weather_theme_provider.dart';
import '../data/models/booking_provider.dart';
import '../data/models/daily_forecast.dart';
import '../features/home/home_providers.dart';
import '../services/behavioral_event_service.dart';

/// Opens the Find & book sheet for an activity.
///
/// The action surface that turns "conditions are right" into somewhere to
/// actually go — and, because every tap is logged, the second source of
/// outcome signal alongside the Did-you-go prompt.
Future<void> showFindAndBookSheet(
  BuildContext context,
  WidgetRef ref, {
  required String activityName,
  String? activityId,
  List<String> categoryNames = const [],
  DailyForecast? forecastDay,
}) {
  final colors = ref.read(weatherThemeColorsProvider);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: colors.cardBackground,
    // The drag handle is the sheet's only dismiss affordance, and it carries
    // its own "Dismiss" semantics — without it a screen-reader user has no
    // announced way out but the escape gesture.
    showDragHandle: true,
    // Otherwise the sheet is capped at half the screen and the provider list
    // is unreachable at the accessibility text sizes.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(OutAboutRadius.bottomSheet),
      ),
    ),
    builder: (sheetContext) => _FindAndBookSheet(
      activityName: activityName,
      activityId: activityId,
      categoryNames: categoryNames,
      forecastDay: forecastDay,
    ),
  );
}

class _FindAndBookSheet extends ConsumerWidget {
  const _FindAndBookSheet({
    required this.activityName,
    required this.activityId,
    required this.categoryNames,
    required this.forecastDay,
  });

  final String activityName;
  final String? activityId;
  final List<String> categoryNames;
  final DailyForecast? forecastDay;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    BookingProvider provider,
    String city,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final colors = ref.read(weatherThemeColorsProvider);
    final navigator = Navigator.of(context);

    final url = bookingUrl(
      provider: provider,
      activityName: activityName,
      city: city,
    );

    // Logged before launching, and not awaited on the launch result: the
    // intent is the signal. Whether the handset had a browser to hand is not
    // a fact about the user's behaviour.
    await ref
        .read(behavioralEventServiceProvider)
        .log(
          'affiliate_link_clicked',
          extra: {
            'provider': provider.name,
            if (activityId != null) 'activity_id': activityId,
          },
          conditions: ref.read(conditionsSnapshotProvider)(
            forecastDay: forecastDay,
          ),
        );

    final opened = await ref.read(urlLauncherProvider)(url);
    if (opened) {
      navigator.pop();
      return;
    }

    messenger?.showSnackBar(
      SnackBar(
        backgroundColor: colors.cardBackground,
        content: Text(
          'Could not open ${provider.label}.',
          style: OutAboutTypography.bodyMedium(colors),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final city = ref.watch(userLocationProvider).valueOrNull?.city ?? '';

    final providers = providersFor(
      activityName: activityName,
      categoryNames: categoryNames,
      city: city,
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: OutAboutSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OutAboutSpacing.md,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  'Find & book',
                  style: OutAboutTypography.headingMedium(colors),
                ),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OutAboutSpacing.md,
              ),
              child: Text(
                city.isEmpty ? activityName : '$activityName near $city',
                style: OutAboutTypography.bodySmall(colors),
              ),
            ),
            const SizedBox(height: OutAboutSpacing.md),
            for (final provider in providers)
              _ProviderRow(
                provider: provider,
                colors: colors,
                onTap: () => _open(context, ref, provider, city),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({
    required this.provider,
    required this.colors,
    required this.onTap,
  });

  final BookingProvider provider;
  final WeatherThemeColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      link: true,
      // The row's own two Texts would merge into this node and repeat the
      // provider name; excluding them and naming both parts here keeps the
      // announcement in the order the row reads.
      label: '${provider.label}. ${provider.subtitle}. Opens in browser',
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: OutAboutSpacing.md,
            vertical: OutAboutSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.label,
                      style: OutAboutTypography.labelLarge(colors),
                    ),
                    Text(
                      provider.subtitle,
                      style: OutAboutTypography.bodySmall(colors),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, size: 18, color: colors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
