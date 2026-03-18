import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: 'https://tswxxjwqnppqlfcbfowt.supabase.co',
    anonKey: 'sb_publishable_o_0mfKjLVbJWZZCFVVuvJA_V3x0e3OX',
  );

  runApp(const OutAboutApp());
}

class OutAboutApp extends StatelessWidget {
  const OutAboutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OutAbout',
      debugShowCheckedModeBanner: false,
      theme: outAboutTheme(),
      home: const DesignSystemPreview(),
    );
  }
}

class DesignSystemPreview extends StatelessWidget {
  const DesignSystemPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OutAboutColors.background,
      appBar: AppBar(
        title: const Text('OutAbout'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OutAboutSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ready to build.', style: OutAboutTypography.displayMedium),
              const SizedBox(height: OutAboutSpacing.sm),
              Text('Design system loaded.', style: OutAboutTypography.bodyLarge.copyWith(color: OutAboutColors.textSecondary)),
              const SizedBox(height: OutAboutSpacing.xl),

              // Color swatches
              Text('Colors', style: OutAboutTypography.headingSmall),
              const SizedBox(height: OutAboutSpacing.md),
              Row(
                children: [
                  _Swatch(color: OutAboutColors.primary, label: 'Primary'),
                  const SizedBox(width: OutAboutSpacing.sm),
                  _Swatch(color: OutAboutColors.accent, label: 'Accent'),
                  const SizedBox(width: OutAboutSpacing.sm),
                  _Swatch(color: OutAboutColors.success, label: 'Success'),
                  const SizedBox(width: OutAboutSpacing.sm),
                  _Swatch(color: OutAboutColors.errorColor, label: 'Error'),
                ],
              ),
              const SizedBox(height: OutAboutSpacing.xl),

              // Button
              Text('Buttons', style: OutAboutTypography.headingSmall),
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
              Text('Cards', style: OutAboutTypography.headingSmall),
              const SizedBox(height: OutAboutSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: OutAboutColors.cardBackground,
                  borderRadius: BorderRadius.circular(OutAboutRadius.lg),
                  boxShadow: OutAboutShadows.card,
                ),
                padding: const EdgeInsets.all(OutAboutSpacing.md),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: OutAboutColors.primarySurface,
                        borderRadius: BorderRadius.circular(OutAboutRadius.md),
                      ),
                      child: const Icon(Icons.directions_bike, color: OutAboutColors.primary),
                    ),
                    const SizedBox(width: OutAboutSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rent bikes at the park', style: OutAboutTypography.headingSmall),
                        const SizedBox(height: 2),
                        Text('Conditions looking good today', style: OutAboutTypography.bodySmall.copyWith(color: OutAboutColors.success)),
                      ],
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
  const _Swatch({required this.color, required this.label});

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
          Text(label, style: OutAboutTypography.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}