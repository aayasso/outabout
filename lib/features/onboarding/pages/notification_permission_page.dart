import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/behavioral_event_service.dart';
import '../../../services/notification_service.dart';
import '../widgets/onboarding_page_wrapper.dart';

class NotificationPermissionPage extends ConsumerWidget {
  final VoidCallback onNext;

  const NotificationPermissionPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OnboardingPageWrapper(
      icon: Icons.notifications_outlined,
      title: 'Get notified when conditions are perfect',
      body:
          "We'll send you a heads-up when the weather matches your favorite activities. No spam — only the moments that matter.",
      ctaLabel: 'Enable Notifications',
      onCtaPressed: () async {
        final granted =
            await ref.read(notificationServiceProvider).requestPermission();
        ref.read(behavioralEventServiceProvider).log(
          'onboarding_completed',
          extra: {'step': 3, 'permission_granted': granted},
        );
        onNext();
      },
      skipLabel: 'Not Now',
      onSkipPressed: () {
        ref.read(behavioralEventServiceProvider).log(
          'onboarding_completed',
          extra: {'step': 3, 'permission_granted': false},
        );
        onNext();
      },
    );
  }
}
