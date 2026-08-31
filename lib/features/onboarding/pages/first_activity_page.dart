import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/motion.dart';
import '../../../core/providers.dart';
import '../../../core/theme.dart';
import '../../../core/weather_theme_provider.dart';
import '../../../data/repositories/category_repository.dart';
import '../../home/home_providers.dart';
import '../../../services/behavioral_event_service.dart';
import '../widgets/onboarding_button.dart';

// ---------------------------------------------------------------------------
// Category data
// ---------------------------------------------------------------------------

class _Category {
  final IconData icon;
  final String label;

  const _Category({required this.icon, required this.label});
}

const _categories = [
  _Category(icon: Icons.hiking, label: 'Hiking'),
  _Category(icon: Icons.directions_bike, label: 'Cycling'),
  _Category(icon: Icons.directions_run, label: 'Running'),
  _Category(icon: Icons.lunch_dining, label: 'Picnic'),
  _Category(icon: Icons.beach_access, label: 'Beach'),
  _Category(icon: Icons.camera_alt, label: 'Photography'),
  _Category(icon: Icons.yard, label: 'Gardening'),
  _Category(icon: Icons.nights_stay, label: 'Stargazing'),
];

// ---------------------------------------------------------------------------
// FirstActivityPage
// ---------------------------------------------------------------------------

class FirstActivityPage extends ConsumerStatefulWidget {
  const FirstActivityPage({super.key});

  @override
  ConsumerState<FirstActivityPage> createState() => _FirstActivityPageState();
}

class _FirstActivityPageState extends ConsumerState<FirstActivityPage> {
  final _nameController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String category) {
    OutAboutHaptics.onConditionToggle();
    setState(() {
      _selectedCategory = category;
      _nameController.text = category;
    });
  }

  Future<void> _handleAddToWishlist() async {
    if (_selectedCategory == null) return;

    setState(() => _isLoading = true);

    final supabase = ref.read(supabaseClientProvider);
    final userId = supabase.auth.currentUser?.id;
    final name = _nameController.text.trim().isEmpty
        ? _selectedCategory!
        : _nameController.text.trim();

    // Insert activity into Supabase. Requires a valid auth session —
    // the auth page ensures one exists (email or anonymous) before
    // reaching this screen. Insert failure is non-blocking so the user
    // always completes onboarding.
    var activitySaved = false;
    if (userId != null) {
      try {
        await supabase.from('activities').insert({
          'user_id': userId,
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
        });
        activitySaved = true;
      } catch (e) {
        debugPrint('FirstActivityPage: activities insert failed — $e');
      }
    } else {
      debugPrint('FirstActivityPage: no auth session — skipping insert');
    }

    // Onboarding still completes either way — stranding the user on this page
    // because a write failed is worse — but the failure is no longer silent.
    // An RLS denial, a foreign-key violation or a dropped socket all produced
    // the same outcome before this: the user named an activity, tapped Add to
    // Wishlist, and landed on the empty-state schedule with nothing to explain
    // where it went.
    if (!activitySaved && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            "We couldn't save that yet. You can add it again from the "
            'Activities tab.',
          ),
        ),
      );
    }

    // Log behavioral events (fire-and-forget, never throws)
    final eventService = ref.read(behavioralEventServiceProvider);
    eventService.log(
      'wishlist_added',
      extra: {'activity_name': name, 'category': _selectedCategory!},
    );
    eventService.log(
      'onboarding_completed',
      extra: {'step': 6},
    );

    // Mark onboarding complete
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('onboarding_complete', true);

    // Seed default categories — fire-and-forget; failure never
    // blocks onboarding. Flag only set on success so the
    // existing-user migration (Task 5) can retry if needed.
    if (userId != null) {
      try {
        await CategoryRepository(supabase)
            .seedDefaults(userId);
        await prefs.setBool('categories_seeded', true);
      } catch (e) {
        log(
          'Category seed failed',
          error: e,
          name: 'FirstActivityPage',
        );
      }
    }

    OutAboutHaptics.onActivitySave();

    // The activity and seeded categories were written after these providers
    // may already have resolved — the sign-in on the previous page
    // invalidates them, so without this the schedule opens on its empty
    // state until the user pulls to refresh.
    ref.invalidate(activitiesProvider);
    ref.invalidate(categoriesProvider);

    // Navigate to home
    if (mounted) {
      GoRouter.of(context).go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(weatherThemeColorsProvider);
    final weatherTheme = ref.watch(weatherThemeProvider);
    final isDark = weatherTheme.brightness == Brightness.dark;

    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: OutAboutSpacing.xl),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: OutAboutSpacing.xxxl),

                // Headline
                Text(
                  'What do you love doing outside?',
                  style: OutAboutTypography.displayLarge(colors),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: OutAboutSpacing.sm),

                // Body
                Text(
                  'Pick one to get started. You can always add more later.',
                  style: OutAboutTypography.bodyLarge(colors),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: OutAboutSpacing.xl),

                // Category grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: OutAboutSpacing.md,
                    crossAxisSpacing: OutAboutSpacing.md,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final isSelected =
                        _selectedCategory == category.label;

                    return Semantics(
                      label: '${category.label} category',
                      selected: isSelected,
                      button: true,
                      child: GestureDetector(
                        onTap: () => _onCategorySelected(category.label),
                        child: AnimatedContainer(
                          duration: OutAboutAnimations.standardDuration,
                          curve: OutAboutAnimations.standardCurve,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary
                                : colors.cardBackground,
                            borderRadius: BorderRadius.circular(
                                OutAboutRadius.cards),
                            boxShadow: isDark
                                ? OutAboutShadows.cardDark
                                : OutAboutShadows.card,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                category.icon,
                                size: 32,
                                color: isSelected
                                    ? colors.onPrimary
                                    : colors.text,
                              ),
                              const SizedBox(height: OutAboutSpacing.sm),
                              Text(
                                category.label,
                                style: OutAboutTypography.labelLarge(colors)
                                    .copyWith(
                                  color: isSelected
                                      ? colors.onPrimary
                                      : colors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: OutAboutSpacing.lg),

                // Activity name field
                Semantics(
                  label: 'Activity name',
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Activity name',
                      hintText: 'Give it a name',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(OutAboutRadius.buttons),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),

                const SizedBox(height: OutAboutSpacing.lg),

                // CTA
                OnboardingButton(
                  label: 'Add to Wishlist',
                  onPressed:
                      _selectedCategory == null ? null : _handleAddToWishlist,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: OutAboutSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    )
        .animateSafely(context)
        .fadeIn(duration: OutAboutAnimations.standardDuration)
        .slideY(
          begin: 0.05,
          end: 0,
          duration: OutAboutAnimations.standardDuration,
          curve: Curves.easeOutCubic,
        );
  }
}
