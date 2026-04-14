import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'core/weather_theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: 'https://tswxxjwqnppqlfcbfowt.supabase.co',
    anonKey: 'sb_publishable_o_0mfKjLVbJWZZCFVVuvJA_V3x0e3OX',
  );

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const OutAboutApp(),
    ),
  );
}

class OutAboutApp extends ConsumerWidget {
  const OutAboutApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeData = ref.watch(themeDataProvider);

    return AnimatedTheme(
      data: themeData,
      duration: OutAboutAnimations.themeTransitionDuration,
      curve: OutAboutAnimations.standardCurve,
      child: MaterialApp(
        title: 'OutAbout',
        debugShowCheckedModeBanner: false,
        theme: themeData,
        home: const DesignSystemPreview(),
      ),
    );
  }
}

class DesignSystemPreview extends ConsumerWidget {
  const DesignSystemPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherTheme = ref.watch(weatherThemeProvider);
    final colors = ref.watch(weatherThemeColorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('OutAbout'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ready to build.', style: OutAboutTypography.displayMedium(colors)),
              const SizedBox(height: OutAboutSpacing.sm),
              Text(
                'Design system loaded — ${weatherTheme.displayName} theme active.',
                style: OutAboutTypography.bodyLarge(colors).copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: OutAboutSpacing.lg),

              // Theme switcher
              Text('Theme', style: OutAboutTypography.headingSmall(colors)),
              const SizedBox(height: OutAboutSpacing.sm),
              Wrap(
                spacing: OutAboutSpacing.sm,
                runSpacing: OutAboutSpacing.sm,
                children: WeatherTheme.values.map((theme) {
                  final isActive = theme == weatherTheme;
                  final themeColors = WeatherThemeColors.forTheme(theme);
                  return GestureDetector(
                    onTap: () {
                      ref.read(userThemeOverrideProvider.notifier).setOverride(theme);
                    },
                    child: AnimatedContainer(
                      duration: OutAboutAnimations.standardDuration,
                      curve: OutAboutAnimations.standardCurve,
                      padding: const EdgeInsets.symmetric(
                        horizontal: OutAboutSpacing.md,
                        vertical: OutAboutSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isActive ? themeColors.primary : colors.surface,
                        borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
                        border: Border.all(
                          color: isActive ? themeColors.primary : colors.divider,
                          width: isActive ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        theme.displayName,
                        style: OutAboutTypography.labelMedium(colors).copyWith(
                          color: isActive
                              ? (theme.brightness == Brightness.dark ? Colors.black : Colors.white)
                              : colors.text,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: OutAboutSpacing.xl),

              // Color swatches
              Text('Colors', style: OutAboutTypography.headingSmall(colors)),
              const SizedBox(height: OutAboutSpacing.md),
              Row(
                children: [
                  _Swatch(color: colors.primary, label: 'Primary', textColor: colors.textSecondary),
                  const SizedBox(width: OutAboutSpacing.sm),
                  _Swatch(color: colors.accent, label: 'Accent', textColor: colors.textSecondary),
                  const SizedBox(width: OutAboutSpacing.sm),
                  _Swatch(color: OutAboutColors.success, label: 'Success', textColor: colors.textSecondary),
                  const SizedBox(width: OutAboutSpacing.sm),
                  _Swatch(color: OutAboutColors.errorColor, label: 'Error', textColor: colors.textSecondary),
                ],
              ),
              const SizedBox(height: OutAboutSpacing.xl),

              // Buttons
              Text('Buttons', style: OutAboutTypography.headingSmall(colors)),
              const SizedBox(height: OutAboutSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('Get Outside'),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Maybe Later'),
                ),
              ),
              const SizedBox(height: OutAboutSpacing.xl),

              // Card
              Text('Cards', style: OutAboutTypography.headingSmall(colors)),
              const SizedBox(height: OutAboutSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: colors.cardBackground,
                  borderRadius: BorderRadius.circular(OutAboutRadius.cards),
                  boxShadow: weatherTheme.brightness == Brightness.dark
                      ? OutAboutShadows.cardDark
                      : OutAboutShadows.card,
                ),
                padding: const EdgeInsets.all(OutAboutSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(OutAboutRadius.buttons),
                      ),
                      child: Icon(Icons.directions_bike, color: colors.primary),
                    ),
                    const SizedBox(width: OutAboutSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rent bikes at the park', style: OutAboutTypography.headingSmall(colors)),
                          const SizedBox(height: 2),
                          Text(
                            'Conditions looking good today',
                            style: OutAboutTypography.bodySmall(colors).copyWith(color: OutAboutColors.success),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;
  const _Swatch({required this.color, required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(OutAboutRadius.sm),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: textColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
