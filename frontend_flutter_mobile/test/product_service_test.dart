import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/services/product_service.dart';

/// Covers `DemoProductService` directly (the fallback data path a
/// disconnected mobile device would actually exercise) — the
/// API-first-then-demo-fallback wiring itself
/// (`productServiceProvider`/`_FallbackProductService`) is exercised
/// indirectly by every widget test that pumps `PosRegisterScreen` against
/// the test sandbox's always-400 HTTP stub (see
/// mobile_shell_screen_test.dart / product_grid_test.dart) — those tests
/// only pass because the fallback correctly kicks in.
void main() {
  group('DemoProductService', () {
    final service = DemoProductService();

    test('getProducts returns only active products by default', () async {
      final products = await service.getProducts();
      expect(products, isNotEmpty);
      expect(products.every((p) => p.active), isTrue);
    });

    test('getProducts filters by categoryId', () async {
      final beverages = await service.getProducts(categoryId: 1);
      expect(beverages, isNotEmpty);
      expect(beverages.every((p) => p.categoryId == 1), isTrue);
    });

    test('getProducts filters by query across name/sku/barcode', () async {
      final byName = await service.getProducts(query: 'latte');
      expect(byName, isNotEmpty);
      expect(byName.every((p) => p.nameEn.toLowerCase().contains('latte')),
          isTrue);

      final byBarcode = await service.getProducts(query: '880123456001');
      expect(byBarcode.single.nameEn, 'Coffee Latte');
    });

    test('getProducts paginates', () async {
      final all = await service.getProducts(size: 1000);
      final page0 = await service.getProducts(page: 0, size: 3);
      final page1 = await service.getProducts(page: 1, size: 3);

      expect(page0.length, 3);
      expect(page1.length, 3);
      expect(page0.map((p) => p.id), isNot(equals(page1.map((p) => p.id))));
      expect(all.length, greaterThan(page0.length));
    });

    test('getCategories returns the demo category list', () async {
      final categories = await service.getCategories();
      expect(categories, isNotEmpty);
      expect(categories.map((c) => c.nameEn), contains('Beverages'));
    });

    test('findByBarcode (from the abstract base) requires an exact match',
        () async {
      final match = await service.findByBarcode('880123456001');
      expect(match?.nameEn, 'Coffee Latte');

      final noMatch = await service.findByBarcode('does-not-exist');
      expect(noMatch, isNull);
    });
  });
}
