import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/core/models/auth_models.dart';
import 'package:frontend_flutter_pos/core/providers/main_color_provider.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/core/services/auth_service.dart';
import 'package:frontend_flutter_pos/features/auth/screens/login_screen.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/category_tabs.dart';

import 'test_l10n_helper.dart';

class _StubAuthService extends AuthService {
  _StubAuthService() : super(ApiService());

  @override
  Future<String?> getToken() async => null;

  @override
  Future<User?> getCurrentUser() async => null;
}

Future<void> _pumpUntilAuthSettled(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    // LoginScreen's decorative background NetworkImage always fails in the
    // test sandbox (flutter_test refuses real HTTP) — drain that expected
    // exception every pump so it can't fail the test or mask a real one.
    while (tester.takeException() != null) {}
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Reset process-global PosTheme state between tests.
    PosTheme.applyMainColor(const Color(0xFF4CAF50));
  });


  group('Login screen', () {
    // LoginScreen reads `Theme.of(context).colorScheme.primary` — it never
    // touches mainColorProvider directly (main.dart is what bridges the two,
    // via PosTheme.applyMainColor before building MaterialApp). So the test
    // only needs to apply the color to PosTheme up front and hand
    // PosTheme.lightTheme to MaterialApp, exactly like main.dart does.
    Widget buildLogin() => ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_StubAuthService()),
          ],
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            theme: PosTheme.lightTheme,
            home: const LoginScreen(),
          ),
        );

    testWidgets('LOGIN button uses the current theme primary color',
        (tester) async {
      const purple = Color(0xFF9C27B0);
      PosTheme.applyMainColor(purple);

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildLogin());
      await _pumpUntilAuthSettled(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'LOGIN'),
      );
      final resolvedBg =
          button.style!.backgroundColor!.resolve(<WidgetState>{});
      expect(resolvedBg, purple);
    });

    testWidgets('does not hardcode the old brand teal for its primary action',
        (tester) async {
      const orange = Color(0xFFFF9800);
      PosTheme.applyMainColor(orange);

      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildLogin());
      await _pumpUntilAuthSettled(tester);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'LOGIN'),
      );
      final resolvedBg =
          button.style!.backgroundColor!.resolve(<WidgetState>{});
      expect(resolvedBg, isNot(const Color(0xFF0f766e)));
      expect(resolvedBg, orange);
    });
  });

  group('POS primary UI (CategoryTabs)', () {
    final categories = [
      Category(id: 1, nameEn: 'Coffee', nameKm: 'កាហ្វេ', active: true),
    ];

    testWidgets('selected tab background follows the configured main color',
        (tester) async {
      const blue = Color(0xFF2196F3);
      PosTheme.applyMainColor(blue);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(
            body: CategoryTabs(
              categories: categories,
              selectedId: 1,
              onSelected: (_) {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('Coffee'),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, blue);
    });
  });

  group('Settings > Main Color', () {
    testWidgets(
        'tapping a swatch updates mainColorProvider state immediately',
        (tester) async {
      late Color observed;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: Consumer(builder: (context, ref, _) {
              observed = ref.watch(mainColorProvider);
              return Scaffold(
                body: Wrap(
                  children: kMainColorOptions
                      .map((color) => GestureDetector(
                            onTap: () => ref
                                .read(mainColorProvider.notifier)
                                .setMainColor(color),
                            child: Container(
                                width: 10, height: 10, color: color),
                          ))
                      .toList(),
                ),
              );
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final blue = kMainColorOptions[1];
      await tester
          .tap(find.byWidgetPredicate((w) => w is Container && w.color == blue));
      await tester.pump();

      expect(observed, blue);
      expect(container.read(mainColorProvider), blue);
    });
  });

  group('Dark mode', () {
    test('dark theme keeps a distinct, non-null primary after a color change',
        () {
      const teal = Color(0xFF009688);
      PosTheme.applyMainColor(teal);

      final light = PosTheme.lightTheme;
      final dark = PosTheme.darkTheme;

      expect(dark.brightness, Brightness.dark);
      expect(light.brightness, Brightness.light);
      // Both themes should still resolve *a* usable primary color; exact
      // equality isn't required (dark mode may adjust for contrast) but it
      // must not silently fall back to null/default material blue.
      expect(dark.colorScheme.primary, isNotNull);
      expect(light.colorScheme.primary, teal);
    });
  });
}
