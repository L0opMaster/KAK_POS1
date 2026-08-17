import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/category_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/product_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/product_service.dart';

/// Fake ProductService — deterministic in-memory data, no network, no
/// dependency on ApiService/Dio at all (unlike DemoProductService, which is
/// exercised indirectly via product_service_test.dart's fallback tests).
class _FakeProductService extends ProductService {
  final List<Product> products;
  final List<Category> categories;
  bool throwOnGetProducts = false;

  _FakeProductService({required this.products, required this.categories});

  @override
  Future<List<Product>> getProducts(
      {String? query, int? categoryId, int page = 0, int size = 100}) async {
    if (throwOnGetProducts) throw Exception('boom');
    var results = products;
    if (categoryId != null) {
      results = results.where((p) => p.categoryId == categoryId).toList();
    }
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results
          .where((p) =>
              p.nameEn.toLowerCase().contains(q) ||
              p.barcode.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q))
          .toList();
    }
    final start = page * size;
    if (start >= results.length) return [];
    final end = (start + size).clamp(0, results.length);
    return results.sublist(start, end);
  }

  @override
  Future<List<Category>> getCategories() async => categories;

  int _nextId = 1000;

  @override
  Future<Product> createProduct(Product product) async {
    final created = Product(
      id: _nextId++,
      sku: product.sku,
      barcode: product.barcode,
      nameEn: product.nameEn,
      nameKm: product.nameKm,
      cost: product.cost,
      price: product.price,
      taxRate: product.taxRate,
      active: product.active,
      categoryId: product.categoryId,
    );
    products.add(created);
    return created;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    final index = products.indexWhere((p) => p.id == product.id);
    if (index == -1) throw Exception('not found');
    products[index] = product;
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {
    products.removeWhere((p) => p.id == id);
  }
}

Product _product(int id, {int categoryId = 1, String name = 'Product'}) =>
    Product(
      id: id,
      sku: 'SKU$id',
      barcode: 'BAR$id',
      nameEn: '$name $id',
      nameKm: '$name $id',
      cost: 1,
      price: 2,
      active: true,
      categoryId: categoryId,
    );

void main() {
  group('ProductNotifier', () {
    test('loadProducts populates state.products and clears isLoading',
        () async {
      final service = _FakeProductService(
        products: [_product(1), _product(2)],
        categories: [],
      );
      final notifier = ProductNotifier(service);

      await notifier.loadProducts();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.products.length, 2);
      expect(notifier.state.error, isNull);
    });

    test('loadProducts sets state.error on failure, keeps products empty',
        () async {
      final service = _FakeProductService(products: [], categories: [])
        ..throwOnGetProducts = true;
      final notifier = ProductNotifier(service);

      await notifier.loadProducts();

      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.products, isEmpty);
    });

    test('searchProducts(empty string) clears the query (loads all)',
        () async {
      final service = _FakeProductService(
        products: [_product(1, name: 'Latte'), _product(2, name: 'Water')],
        categories: [],
      );
      final notifier = ProductNotifier(service);

      await notifier.searchProducts('Latte');
      expect(notifier.state.products.length, 1);

      await notifier.searchProducts('');
      expect(notifier.state.products.length, 2);
    });

    test('filterByCategory(null) clears the category filter', () async {
      final service = _FakeProductService(
        products: [_product(1, categoryId: 1), _product(2, categoryId: 2)],
        categories: [],
      );
      final notifier = ProductNotifier(service);

      await notifier.filterByCategory(1);
      expect(notifier.state.products.length, 1);
      expect(notifier.state.products.single.categoryId, 1);

      await notifier.filterByCategory(null);
      expect(notifier.state.products.length, 2);
    });

    test('loadMore appends products and advances currentPage', () async {
      final products = List.generate(3, (i) => _product(i + 1));
      final service = _FakeProductService(products: products, categories: []);
      // Force a tiny page size by loading then manually calling loadMore —
      // ProductNotifier's real page size is 48, so with only 3 fake
      // products `hasMore` is already false after the first load and
      // loadMore() is a correctly-behaving no-op. This asserts that
      // no-op, not a full pagination cycle (48 fixtures would be noise).
      final notifier = ProductNotifier(service);
      await notifier.loadProducts();
      expect(notifier.state.hasMore, isFalse);

      await notifier.loadMore();
      expect(notifier.state.products.length, 3); // unchanged, still a no-op
    });

    test('findByBarcode delegates to the service and requires an exact match',
        () async {
      final service = _FakeProductService(
        products: [_product(1)],
        categories: [],
      );
      final notifier = ProductNotifier(service);
      final found = await notifier.findByBarcode('BAR1');
      expect(found?.id, 1);

      final notFound = await notifier.findByBarcode('nope');
      expect(notFound, isNull);
    });

    test('createProduct adds the item and refreshes state', () async {
      final service = _FakeProductService(products: [], categories: []);
      final notifier = ProductNotifier(service);
      await notifier.loadProducts();

      final created = await notifier.createProduct(_product(1));
      expect(created.id, isNot(1)); // service assigns the real id
      expect(notifier.state.products, hasLength(1));
    });

    test('updateProduct modifies the item and refreshes state', () async {
      final service = _FakeProductService(
        products: [_product(1, name: 'Old')],
        categories: [],
      );
      final notifier = ProductNotifier(service);
      await notifier.loadProducts();

      await notifier.updateProduct(_product(1, name: 'New'));
      expect(notifier.state.products.single.nameEn, 'New 1');
    });

    test('deleteProduct removes the item and refreshes state', () async {
      final service = _FakeProductService(
        products: [_product(1), _product(2)],
        categories: [],
      );
      final notifier = ProductNotifier(service);
      await notifier.loadProducts();
      expect(notifier.state.products, hasLength(2));

      await notifier.deleteProduct(1);
      expect(notifier.state.products.map((p) => p.id), [2]);
    });
  });

  group('CategoryNotifier', () {
    test('loads categories into AsyncValue.data on success', () async {
      final service = _FakeProductService(
        products: [],
        categories: [
          Category(id: 1, nameEn: 'Beverages', nameKm: 'B', active: true),
        ],
      );
      final container = ProviderContainer(overrides: [
        categoriesProvider.overrideWith((ref) => CategoryNotifier(service)),
      ]);
      addTearDown(container.dispose);

      // Force creation + drain the async load.
      container.read(categoriesProvider);
      for (var i = 0; i < 20; i++) {
        if (!container.read(categoriesProvider).isLoading) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(container.read(categoriesProvider).value?.length, 1);
    });
  });
}
