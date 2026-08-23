import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:outabout/core/providers.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('supabaseClientProvider', () {
    test('resolves to the client it is overridden with', () {
      // `isA<Provider<SupabaseClient>>()` on a Provider<SupabaseClient> is a
      // tautology. What matters is that reading it hands back the injected
      // client — that is what every repository depends on.
      final mockClient = _MockSupabaseClient();
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(mockClient)],
      );
      addTearDown(container.dispose);

      expect(container.read(supabaseClientProvider), same(mockClient));
    });
  });

  group('packageInfoProvider', () {
    test(
      'can be overridden in a ProviderContainer with a mock PackageInfo',
      () async {
        // Avoid hitting the real platform channel by overriding the provider
        // with a known PackageInfo value.
        final mockInfo = PackageInfo(
          appName: 'OutAbout',
          packageName: 'com.outabout',
          version: '1.0.0',
          buildNumber: '1',
        );

        final container = ProviderContainer(
          overrides: [packageInfoProvider.overrideWith((_) async => mockInfo)],
        );
        addTearDown(container.dispose);

        final result = await container.read(packageInfoProvider.future);
        // isA<PackageInfo> restates the type the test itself constructed.
        expect(result.appName, 'OutAbout');
        expect(result.version, '1.0.0');
      },
    );
  });
}
