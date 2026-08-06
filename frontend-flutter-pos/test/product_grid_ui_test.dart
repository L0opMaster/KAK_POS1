import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/product_grid.dart';

import 'test_l10n_helper.dart';

void main() {
  testWidgets('ProductCard shows placeholder icon, stock badge and quick-add',
      (tester) async {
    // choose a name that will map to a specific placeholder icon so the test
    // is deterministic
    final product = Product.sample().copyWith(
      imageUrl: '',
      stock: 3,
      nameEn: 'coffee bean',
    );

    bool tapped = false;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: ProductGrid(
          products: [product],
          onLoadMore: () {},
          onProductTap: (_) {
            tapped = true;
          },
        ),
      ),
    )));
    await tester.pumpAndSettle();

    // placeholder icon for category 1 (coffee) is a Material icon, not text
    expect(find.byIcon(Icons.local_cafe), findsOneWidget);
    expect(find.text('coffee bean'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // quick-add button exists and tapping it invokes callback
    final addButton = find.byIcon(Icons.add);
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    expect(tapped, isTrue);
  });

  testWidgets('ProductCard overlays out-of-stock message when stock is zero',
      (tester) async {
    final product = Product.sample().copyWith(
      imageUrl: '',
      stock: 0,
      nameEn: 'SoldOut',
    );

    bool tapped = false;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: ProductGrid(
          products: [product],
          onLoadMore: () {},
          onProductTap: (_) {
            tapped = true;
          },
        ),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Out of Stock'), findsOneWidget);
    // quick-add should not appear
    expect(find.byIcon(Icons.add), findsNothing);
    // tapping product should also not trigger callback
    await tester.tap(find.text('SoldOut'));
    expect(tapped, isFalse);
  });
}
