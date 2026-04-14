import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'core/weather_theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
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
    final router = ref.watch(routerProvider);

    return AnimatedTheme(
      data: themeData,
      duration: OutAboutAnimations.themeTransitionDuration,
      curve: OutAboutAnimations.standardCurve,
      child: MaterialApp.router(
        title: 'OutAbout',
        debugShowCheckedModeBanner: false,
        theme: themeData,
        routerConfig: router,
      ),
    );
  }
}
