import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/product_card.dart';

import 'test_l10n_helper.dart';

/// Regression coverage for a bug where `ProductCard` computed "has stock"
/// as `p.stock != 0` directly, ignoring `trackInventory` — every untracked
/// product (which defaults `stock` to 0, since it never sets a quantity)
/// showed the Out of Stock overlay and could never be tapped/added, even
/// though the backend's own `product.outOfStock` (which this now uses via
/// `!p.outOfStock`) is `trackInventory && stock <= 0` and is correctly
/// `false` for an untracked product regardless of `stock`.
Product _product({
  bool trackInventory = false,
  double stock = 0,
  bool outOfStock = false,
  bool lowStock = false,
}) =>
    Product(
      id: 1,
      sku: 'SKU-1',
      barcode: '111',
      nameEn: 'Test Product',
      nameKm: 'ផលិតផលសាកល្បង',
      cost: 1,
      price: 5,
      active: true,
      categoryId: 1,
      trackInventory: trackInventory,
      stock: stock,
      outOfStock: outOfStock,
      lowStock: lowStock,
    );

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: SizedBox(width: 160, height: 220, child: child)),
      ),
    );

void main() {
  testWidgets(
      'untracked product with stock=0 is tappable and shows no Out of Stock overlay',
      (tester) async {
    bool tapped = false;
    final product = _product(trackInventory: false, stock: 0);

    await tester.pumpWidget(_wrap(ProductCard(
      product: product,
      onTap: (_) => tapped = true,
    )));

    expect(find.text('Out of Stock'), findsNothing);

    await tester.tap(find.byType(ProductCard));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tapped, isTrue);
  });

  testWidgets(
      'tracked product with stock=0 shows Out of Stock overlay and blocks tap',
      (tester) async {
    bool tapped = false;
    final product =
        _product(trackInventory: true, stock: 0, outOfStock: true);

    await tester.pumpWidget(_wrap(ProductCard(
      product: product,
      onTap: (_) => tapped = true,
    )));

    expect(find.text('Out of Stock'), findsOneWidget);

    await tester.tap(find.byType(ProductCard));
    await tester.pump(const Duration(milliseconds: 150));
    expect(tapped, isFalse);
  });

  testWidgets('untracked product never shows a numeric stock count',
      (tester) async {
    final product = _product(trackInventory: false, stock: 0);

    await tester.pumpWidget(_wrap(ProductCard(product: product)));

    expect(find.text('0'), findsNothing);
  });

  testWidgets('tracked product shows its stock count next to the price',
      (tester) async {
    final product = _product(trackInventory: true, stock: 7);

    await tester.pumpWidget(_wrap(ProductCard(product: product)));

    expect(find.text('7'), findsOneWidget);
  });

  group('live cartQty reactivity (no payment/refetch needed)', () {
    testWidgets(
        'stock count next to the price is reduced by what is already in the cart',
        (tester) async {
      // stock=17 stays above the default lowStockThreshold (5) after
      // subtracting cartQty, so the low-stock badge doesn't also render
      // "14" and create a second match for the same text.
      final product = _product(trackInventory: true, stock: 17);

      await tester.pumpWidget(
          _wrap(ProductCard(product: product, cartQty: 3)));

      expect(find.text('14'), findsOneWidget);
      expect(find.text('17'), findsNothing);
    });

    testWidgets(
        'card goes Out of Stock once cartQty reaches the stock, with no server refresh',
        (tester) async {
      bool tapped = false;
      final product = _product(trackInventory: true, stock: 2);

      await tester.pumpWidget(_wrap(ProductCard(
        product: product,
        cartQty: 2,
        onTap: (_) => tapped = true,
      )));

      expect(find.text('Out of Stock'), findsOneWidget);

      await tester.tap(find.byType(ProductCard));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tapped, isFalse);
    });

    testWidgets(
        'card returns to available the moment cartQty drops below stock again',
        (tester) async {
      final product = _product(trackInventory: true, stock: 2);

      await tester.pumpWidget(
          _wrap(ProductCard(product: product, cartQty: 2)));
      expect(find.text('Out of Stock'), findsOneWidget);

      // Simulates the cart line's "-" stepper firing and cartQty dropping —
      // no new network fetch, just a rebuild with a smaller cartQty.
      await tester.pumpWidget(
          _wrap(ProductCard(product: product, cartQty: 1)));
      expect(find.text('Out of Stock'), findsNothing);
    });

    testWidgets(
        'availableSaleQty (not raw stock) is the base subtracted from cartQty',
        (tester) async {
      // Kept above the default lowStockThreshold (5) so the low-stock
      // badge doesn't also render the same number as the price-row count.
      final product = Product(
        id: 1,
        sku: 'SKU-1',
        barcode: '111',
        nameEn: 'Test Product',
        nameKm: 'ផលិតផលសាកល្បង',
        cost: 1,
        price: 5,
        active: true,
        categoryId: 1,
        trackInventory: true,
        stock: 50,
        availableSaleQty: 13,
      );

      await tester.pumpWidget(
          _wrap(ProductCard(product: product, cartQty: 1)));

      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('untracked product ignores cartQty entirely', (tester) async {
      bool tapped = false;
      final product = _product(trackInventory: false, stock: 0);

      await tester.pumpWidget(_wrap(ProductCard(
        product: product,
        cartQty: 500,
        onTap: (_) => tapped = true,
      )));

      expect(find.text('Out of Stock'), findsNothing);
      await tester.tap(find.byType(ProductCard));
      await tester.pump(const Duration(milliseconds: 150));
      expect(tapped, isTrue);
    });
  });
}
