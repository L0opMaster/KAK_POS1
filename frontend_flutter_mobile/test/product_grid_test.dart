import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/services/settings_service.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/product_grid.dart';

import 'test_l10n_helper.dart';

/// Regression coverage for connecting `ProductGrid` to
/// `posSettingsProvider`'s `saleScreenLayout`/`productGridColumns` — added
/// after a report that "the grid doesn't work." The grid must render every
/// product regardless of what shape `posSettingsProvider` resolves to,
/// including values a live backend could plausibly send that don't match
/// the expected Dart types exactly (the concrete bug class a raw `as
/// String?`/`as num?` cast would have silently turned into a crash — this
/// widget must never throw building its `gridDelegate` from that data).
Product _product(int id) => Product(
      id: id,
      sku: 'SKU$id',
      barcode: 'BAR$id',
      nameEn: 'Product $id',
      nameKm: 'Product $id',
      cost: 1,
      price: 5.0,
      active: true,
      categoryId: 1,
    );

Widget _wrap(Widget child, {required AsyncValue<Map<String, dynamic>> settings}) {
  return ProviderScope(
    overrides: [
      posSettingsProvider.overrideWith((ref) {
        return settings.when(
          data: (d) => Future.value(d),
          loading: () => Completer<Map<String, dynamic>>().future,
          error: (e, st) => Future<Map<String, dynamic>>.error(e, st),
        );
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

ProductGrid _grid(List<Product> products) => ProductGrid(
      products: products,
      onLoadMore: () {},
      onProductTap: (_) {},
      onProductQuickAdd: (_) {},
    );

void main() {
  testWidgets('renders all products with the default GRID layout',
      (tester) async {
    await tester.pumpWidget(_wrap(
      _grid([_product(1), _product(2), _product(3)]),
      settings: const AsyncValue.data({
        'saleScreenLayout': 'GRID',
        'productGridColumns': 5,
      }),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 2'), findsOneWidget);
    expect(find.text('Product 3'), findsOneWidget);
  });

  testWidgets('renders correctly with LIST layout', (tester) async {
    await tester.pumpWidget(_wrap(
      _grid([_product(1), _product(2)]),
      settings: const AsyncValue.data({
        'saleScreenLayout': 'LIST',
        'productGridColumns': 5,
      }),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Product 1'), findsOneWidget);
    expect(find.text('Product 2'), findsOneWidget);
  });

  testWidgets('renders correctly with COMPACT layout and a custom column count',
      (tester) async {
    await tester.pumpWidget(_wrap(
      _grid([_product(1), _product(2)]),
      settings: const AsyncValue.data({
        'saleScreenLayout': 'COMPACT',
        'productGridColumns': 8,
      }),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets(
      'never throws when the backend sends unexpected value types (e.g. a '
      'String for productGridColumns, a non-String saleScreenLayout)',
      (tester) async {
    await tester.pumpWidget(_wrap(
      _grid([_product(1)]),
      settings: const AsyncValue.data({
        'saleScreenLayout': 42, // not a String
        'productGridColumns': '5', // a String, not a num
      }),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('falls back to defaults and still renders when settings fail to load',
      (tester) async {
    await tester.pumpWidget(_wrap(
      _grid([_product(1)]),
      settings: AsyncValue.error(Exception('boom'), StackTrace.empty),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Product 1'), findsOneWidget);
  });

  testWidgets('still renders products while settings are loading',
      (tester) async {
    await tester.pumpWidget(_wrap(
      _grid([_product(1)]),
      settings: const AsyncValue.loading(),
    ));
    // Don't settle — the settings future never resolves in this case;
    // one frame is enough to prove the grid itself doesn't hang/throw.
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Product 1'), findsOneWidget);
  });
}
