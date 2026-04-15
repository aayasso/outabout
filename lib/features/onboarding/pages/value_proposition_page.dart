import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/behavioral_event_service.dart';
import '../widgets/onboarding_page_wrapper.dart';

class ValuePropositionPage extends ConsumerWidget {
  final VoidCallback onNext;

  const ValuePropositionPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPageWrapper(
      icon: Icons.wb_sunny_outlined,
      title: 'Never miss perfect weather for the things you love',
      body:
          'OutAbout watches the forecast and lets you know when conditions match your favorite activities.',
      ctaLabel: 'Get Started',
      onCtaPressed: () {
        ref.read(behavioralEventServiceProvider).log(
          'onboarding_completed',
          extra: {'step': 1},
        );
        onNext();
      },
    );
  }
}
