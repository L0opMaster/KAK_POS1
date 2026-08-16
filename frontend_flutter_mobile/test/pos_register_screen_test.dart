import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/pos_register_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/product_grid.dart';

import 'test_l10n_helper.dart';

/// Exercises `PosRegisterScreen` against the DemoProductService fallback
/// (the real `productServiceProvider` tries the API first, but
/// `flutter_test`'s sandbox always 400s any real HTTP call — see
/// product_service_test.dart's file comment) — this is deliberately NOT
/// mocked away, since it's the same fallback path a real offline/
/// backend-unreachable mobile device exercises.
///
/// `setUp`'s `SharedPreferences.setMockInitialValues({})` is required, not
/// decorative: without it, `appLanguageProvider` (read by `CategoryTabs`)
/// throws a `MissingPluginException` on the unmocked platform channel,
/// which stalls the whole widget tree's async chain — `productsProvider`
/// never leaves `isLoading: true` and `pumpAndSettle()` times out. Every
/// other test file in this suite already sets this up; this one is called
/// out explicitly because omitting it here manifested as a confusing
/// "product grid never loads" failure rather than an obvious plugin error.
Widget _wrap() => const ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: PosRegisterScreen()),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('loads and shows the demo product grid', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.byType(ProductGrid), findsOneWidget);
    expect(find.text('Coffee Latte'), findsOneWidget);
  });

  testWidgets('search filters the grid after the debounce', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Coffee Latte'), findsOneWidget);
    expect(find.text('Potato Chips'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'chips');
    // Debounce is 300ms, plus the demo service's own simulated 300ms delay.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Potato Chips'), findsOneWidget);
    expect(find.text('Coffee Latte'), findsNothing);
  });

  testWidgets('category tab filters the grid', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();
    expect(find.text('Coffee Latte'), findsOneWidget);
    expect(find.text('Potato Chips'), findsOneWidget);

    await tester.tap(find.text('Snacks'));
    await tester.pumpAndSettle();

    expect(find.text('Potato Chips'), findsOneWidget);
    expect(find.text('Coffee Latte'), findsNothing);
  });

  testWidgets(
      'tapping a product adds it to the real cart',
      (tester) async {
    // Cart access itself (CartFab) is hosted on MobileShellScreen's
    // Scaffold, not PosRegisterScreen — see cart_fab_test.dart for that
    // widget's own coverage (hidden when empty, shows count/total).
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: PosRegisterScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    expect(container.read(cartProvider).items, isEmpty);

    await tester.tap(find.text('Coffee Latte'));
    // Product card has its own 120ms press-animation delay before the tap
    // actually fires.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items.length, 1);
    expect(container.read(cartProvider).items.single.product.nameEn,
        'Coffee Latte');
  });

  testWidgets('tapping the same product twice increments its quantity',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: PosRegisterScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coffee Latte'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee Latte'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(container.read(cartProvider).items.length, 1);
    expect(container.read(cartProvider).items.single.qty, 2);
  });
}
