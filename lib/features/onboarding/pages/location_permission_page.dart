import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/behavioral_event_service.dart';
import '../../../services/location_service.dart';
import '../widgets/onboarding_page_wrapper.dart';

class LocationPermissionPage extends ConsumerWidget {
  final VoidCallback onNext;

  const LocationPermissionPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPageWrapper(
      icon: Icons.location_on_outlined,
      title: 'Know what\'s happening near you',
      body:
          'Weather changes block by block. Your location helps us give you the most accurate conditions for activities near you.',
      ctaLabel: 'Enable Location',
      onCtaPressed: () async {
        final result =
            await ref.read(locationServiceProvider).requestPermission();
        final granted = result == LocationPermissionResult.granted;
        ref.read(behavioralEventServiceProvider).log(
          'onboarding_completed',
          extra: {'step': 2, 'permission_granted': granted},
        );
        onNext();
      },
      skipLabel: 'Not Now',
      onSkipPressed: () {
        ref.read(behavioralEventServiceProvider).log(
          'onboarding_completed',
          extra: {'step': 2, 'permission_granted': false},
        );
        onNext();
      },
    );
  }
}
