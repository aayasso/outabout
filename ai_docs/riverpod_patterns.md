# OutAbout — Riverpod Patterns
# ai_docs/riverpod_patterns.md
# Living document. Update when patterns evolve.
# Last updated: 2026-04-28

## Critical: Hand-Written Providers Only

OutAbout uses Riverpod WITHOUT code generation.
- No `riverpod_annotation` package
- No `riverpod_generator` package
- No `@riverpod` annotations
- No `build_runner` for state management
- Write all providers manually

---

## Provider Type Selection

| Situation | Provider Type |
|---|---|
| Async data from Supabase / Tomorrow.io | `FutureProvider` |
| Mutable state with methods | `StateNotifierProvider` |
| Simple single-value state | `StateProvider` |
| Derived/computed value | `Provider` |
| Async stream (Supabase Realtime) | `StreamProvider` |
| Singleton service/repository | `Provider` (keepAlive via autoDispose:false) |

---

## Standard Patterns

### FutureProvider — async data fetch

```dart
final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return [];
  return ref.watch(activityRepositoryProvider).fetchForUser(userId);
});
```

### StateNotifierProvider — mutable state with methods

```dart
final activityNotifierProvider =
    StateNotifierProvider<ActivityNotifier, AsyncValue<List<Activity>>>((ref) {
  return ActivityNotifier(ref.watch(activityRepositoryProvider));
});

class ActivityNotifier extends StateNotifier<AsyncValue<List<Activity>>> {
  ActivityNotifier(this._repository) : super(const AsyncLoading()) {
    _load();
  }

  final ActivityRepository _repository;

  Future<void> _load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.fetchForUser(userId));
  }

  Future<void> add(Activity activity) async {
    final newActivity = await _repository.insert(activity);
    state = AsyncData([...state.value ?? [], newActivity]);
    OutAboutHaptics.onActivitySave();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    state = AsyncData(
      state.value?.where((a) => a.id != id).toList() ?? [],
    );
  }
}
```

### StateProvider — simple UI state

```dart
final selectedTabProvider = StateProvider<int>((ref) => 0);
final isLoadingProvider = StateProvider<bool>((ref) => false);
```

### Provider — derived/computed value

```dart
// Repository providers — always this pattern
final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseClientProvider));
});

// Derived from other providers
final hasActivitiesProvider = Provider<bool>((ref) {
  final activities = ref.watch(activitiesProvider);
  return activities.valueOrNull?.isNotEmpty ?? false;
});
```

### StreamProvider — Supabase Realtime

```dart
final reminderStreamProvider = StreamProvider<List<Reminder>>((ref) {
  final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;
  if (userId == null) return const Stream.empty();
  return ref.watch(supabaseClientProvider)
      .from('reminders')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((data) => data.map(Reminder.fromJson).toList());
});
```

---

## Weather Theme Providers (existing — do not modify)

```dart
// Read-only — observe active theme colors
final colors = ref.watch(weatherThemeColorsProvider);
final weatherTheme = ref.watch(weatherThemeProvider);

// Trigger adaptive theme change (from Tomorrow.io response)
ref.read(weatherThemeProvider.notifier).setThemeFromConditions(weatherCode);
ref.read(weatherThemeProvider.notifier).setThemeFromTimeOfDay(DateTime.now());

// User manual override
ref.read(userThemeOverrideProvider.notifier).setOverride(WeatherTheme.rainy);
ref.read(userThemeOverrideProvider.notifier).setOverride(null); // clear
```

---

## Onboarding Provider (existing pattern)

```dart
// onboarding_provider.dart — follow this pattern for step-based flows
final onboardingStepProvider =
    StateNotifierProvider<OnboardingStepNotifier, int>((ref) {
  return OnboardingStepNotifier();
});

class OnboardingStepNotifier extends StateNotifier<int> {
  OnboardingStepNotifier() : super(0);

  void next() {
    if (state < totalSteps - 1) state = state + 1;
  }

  void goTo(int index) => state = index;

  static const int totalSteps = 6;
}
```

---

## Consumer Widget Patterns

### ConsumerWidget (stateless + Riverpod)

```dart
class ActivityCard extends ConsumerWidget {
  const ActivityCard({super.key, required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final weatherTheme = ref.watch(weatherThemeProvider);
    final isDark = weatherTheme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(OutAboutRadius.cards),
        boxShadow: isDark ? OutAboutShadows.cardDark : OutAboutShadows.card,
      ),
      child: Text(activity.name, style: OutAboutTypography.headingSmall(colors)),
    );
  }
}
```

### ConsumerStatefulWidget (local state + Riverpod)

Use when you need both local state (TextEditingController, PageController,
AnimationController) AND Riverpod state.

```dart
class AddActivitySheet extends ConsumerStatefulWidget {
  const AddActivitySheet({super.key});

  @override
  ConsumerState<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends ConsumerState<AddActivitySheet> {
  final _nameController = TextEditingController();  // local
  bool _isSaving = false;                           // local ephemeral

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await ref.read(activityNotifierProvider.notifier).add(
      Activity(name: _nameController.text),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    // ...
  }
}
```

---

## Async State Handling in Widgets

```dart
// Standard when() pattern
ref.watch(activitiesProvider).when(
  loading: () => _buildShimmer(colors),
  error: (error, stack) => _buildError(colors, error),
  data: (activities) => _buildList(colors, activities),
);

// Shimmer loading
Widget _buildShimmer(WeatherThemeColors colors) {
  return Shimmer.fromColors(
    baseColor: colors.surface,
    highlightColor: colors.divider,
    child: // skeleton layout
  );
}

// Error state
Widget _buildError(WeatherThemeColors colors, Object error) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.cloud_off, color: colors.textSecondary, size: 48),
        const SizedBox(height: OutAboutSpacing.md),
        Text('Something went wrong',
            style: OutAboutTypography.bodyMedium(colors)),
        TextButton(
          onPressed: () => ref.invalidate(activitiesProvider),
          child: const Text('Try again'),
        ),
      ],
    ),
  );
}
```

---

## ref.listen — Side Effects

Use `ref.listen` for navigation, snackbars, and haptics triggered by state changes.
Never use `ref.watch` for side effects.

```dart
ref.listen<int>(onboardingStepProvider, (prev, next) {
  // sync PageController — matches existing onboarding pattern
  _pageController.animateToPage(
    next,
    duration: OutAboutAnimations.standardDuration,
    curve: Curves.easeOutCubic,
  );
});
```

---

## Naming Conventions

| Type | Pattern | Example |
|---|---|---|
| FutureProvider (data) | `[entity]Provider` | `activitiesProvider` |
| StateNotifierProvider | `[entity]NotifierProvider` | `activityNotifierProvider` |
| Notifier class | `[Entity]Notifier` | `ActivityNotifier` |
| Repository provider | `[entity]RepositoryProvider` | `activityRepositoryProvider` |
| Simple StateProvider | `[description]Provider` | `selectedTabProvider` |
| StreamProvider | `[entity]StreamProvider` | `reminderStreamProvider` |

Always: camelCase, descriptive, ends in `Provider`.
Never: `dataProvider`, `stateProvider`, `myProvider`.

---

## Invalidation

```dart
// Force refetch
ref.invalidate(activitiesProvider);

// From a notifier (self-invalidate)
ref.invalidateSelf();

// Refresh and await
await ref.refresh(activitiesProvider.future);
```
