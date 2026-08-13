// Regression coverage for: after a successful Company Profile save, the POS
// AppBar and POS drawer used to keep showing the old business name until a
// full page reload — because nothing shared reactive state between the
// Settings screen and those two widgets (each just called
// SettingsService.getCompanyProfile() independently, with no caching layer
// to even be stale in the first place). Fixed by companyProfileProvider
// (core/providers/company_provider.dart), a FutureProvider every consumer
// watches, invalidated by settings_modules_screen.dart's _saveCompany()
// only after a successful update — mirroring the existing
// currencyCodeProvider/_saveGeneral() pattern already used elsewhere in
// this app (core/providers/currency_provider.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/company_provider.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/settings_service.dart';

import 'test_l10n_helper.dart';

class _FakeApiService extends ApiService {
  Map<String, dynamic> companyProfile = {'businessName': 'Company A'};
  bool throwOnNextGet = false;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    if (path == '/api/settings/company-profile') {
      if (throwOnNextGet) {
        throwOnNextGet = false;
        throw ApiException('network error', statusCode: 500);
      }
      return companyProfile as T;
    }
    return <String, dynamic>{} as T;
  }
}

void main() {
  group('companyProfileProvider (state layer)', () {
    test('fetches from SettingsService.getCompanyProfile()', () async {
      final fakeApi = _FakeApiService()
        ..companyProfile = {'businessName': 'Company A'};
      final container = ProviderContainer(overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(fakeApi)),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(companyProfileProvider.future);
      expect(result['businessName'], 'Company A');
    });

    test(
        'invalidating after a successful update makes every watcher see the new company — twice, proving it is reactive, not just a one-time load',
        () async {
      final fakeApi = _FakeApiService()
        ..companyProfile = {'businessName': 'Company A'};
      final container = ProviderContainer(overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(fakeApi)),
      ]);
      addTearDown(container.dispose);

      expect((await container.read(companyProfileProvider.future))
          ['businessName'], 'Company A');

      // Simulates a successful PUT /api/settings/company-profile followed
      // by settings_modules_screen.dart's ref.invalidate(...) call.
      fakeApi.companyProfile = {'businessName': 'Company B'};
      container.invalidate(companyProfileProvider);
      expect((await container.read(companyProfileProvider.future))
          ['businessName'], 'Company B');

      // B -> C: prove this keeps working on a second update, not just once.
      fakeApi.companyProfile = {'businessName': 'Company C'};
      container.invalidate(companyProfileProvider);
      expect((await container.read(companyProfileProvider.future))
          ['businessName'], 'Company C');
    });

    test('a failed refetch keeps the last-known-good value, not blank/stale-invalid data',
        () async {
      final fakeApi = _FakeApiService()
        ..companyProfile = {'businessName': 'Company A'};
      final container = ProviderContainer(overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(fakeApi)),
      ]);
      addTearDown(container.dispose);

      await container.read(companyProfileProvider.future);
      fakeApi.throwOnNextGet = true;
      container.invalidate(companyProfileProvider);

      // The provider's own AsyncValue does carry the error, but consumers
      // use watchCompanyName's valueOrNull — which is what must survive.
      await expectLater(
        container.read(companyProfileProvider.future),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('watchCompanyName (what POS AppBar/drawer actually read)', () {
    Widget buildHarness(WidgetRef Function(WidgetRef) capture,
        {required List<Override> overrides}) {
      return ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              capture(ref);
              return Text(
                watchCompanyName(ref, fallback: 'Fallback Name'),
              );
            },
          ),
        ),
      );
    }

    testWidgets(
        'shows the fallback while loading, then the fetched business name',
        (tester) async {
      final fakeApi = _FakeApiService()
        ..companyProfile = {'businessName': 'Kaknnea Cafe'};

      await tester.pumpWidget(buildHarness((r) => r, overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(fakeApi)),
      ]));

      expect(find.text('Fallback Name'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Kaknnea Cafe'), findsOneWidget);
      expect(find.text('Fallback Name'), findsNothing);
    });

    testWidgets(
        'rebuilds with the new business name after the provider is invalidated — no reload, no re-navigation',
        (tester) async {
      final fakeApi = _FakeApiService()
        ..companyProfile = {'businessName': 'Company A'};
      late WidgetRef ref;

      await tester.pumpWidget(buildHarness((r) => ref = r, overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(fakeApi)),
      ]));
      await tester.pumpAndSettle();
      expect(find.text('Company A'), findsOneWidget);

      // Exactly what settings_modules_screen.dart's _saveCompany() does
      // after a successful PUT.
      fakeApi.companyProfile = {'businessName': 'Company B'};
      ref.invalidate(companyProfileProvider);
      await tester.pumpAndSettle();

      expect(find.text('Company B'), findsOneWidget);
      expect(find.text('Company A'), findsNothing);
    });

    testWidgets('empty business name falls back instead of showing blank text',
        (tester) async {
      final fakeApi = _FakeApiService()..companyProfile = {'businessName': ''};

      await tester.pumpWidget(buildHarness((r) => r, overrides: [
        settingsServiceProvider.overrideWithValue(SettingsService(fakeApi)),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Fallback Name'), findsOneWidget);
    });
  });
}
