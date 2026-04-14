import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';

void main() {
  group('supabaseClientProvider', () {
    test('is a Provider of SupabaseClient', () {
      // Verify the provider has the correct type without initialising Supabase,
      // which requires a live platform environment.
      expect(supabaseClientProvider, isA<Provider<SupabaseClient>>());
    });
  });

  group('packageInfoProvider', () {
    test('is a FutureProvider of PackageInfo', () {
      expect(packageInfoProvider, isA<FutureProvider<PackageInfo>>());
    });

    test('can be overridden in a ProviderContainer with a mock PackageInfo', () async {
      // Avoid hitting the real platform channel by overriding the provider
      // with a known PackageInfo value.
      final mockInfo = PackageInfo(
        appName: 'OutAbout',
        packageName: 'com.outabout',
        version: '1.0.0',
        buildNumber: '1',
      );

      final container = ProviderContainer(
        overrides: [
          packageInfoProvider.overrideWith((_) async => mockInfo),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(packageInfoProvider.future);
      expect(result, isA<PackageInfo>());
      expect(result.appName, 'OutAbout');
      expect(result.version, '1.0.0');
    });
  });
}
