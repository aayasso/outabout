import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingStepNotifier extends StateNotifier<int> {
  OnboardingStepNotifier() : super(0);

  void next() {
    if (state < 5) state = state + 1;
  }

  void back() {
    if (state > 0) state = state - 1;
  }

  void goTo(int step) {
    if (step >= 0 && step <= 5) state = step;
  }
}

final onboardingStepProvider =
    StateNotifierProvider<OnboardingStepNotifier, int>(
  (ref) => OnboardingStepNotifier(),
);
