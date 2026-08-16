import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/features/pos/providers/product_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/category_provider.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';
// import 'package:frontend_flutter_pos/core/services/api_service.dart';
// import 'package:frontend_flutter_pos/pos/repositories/product_repository.dart';

// 1. Create a Fake Repository/Service to avoid complex mocking
// This simulates the backend response
class FakeProductRepository {
  Future<List<Product>> getProducts() async => <Product>[
        Product(
          id: 1,
          sku: 'SKU-1',
          barcode: '111111',
          nameEn: 'Coca Cola',
          nameKm: 'កូកា-កូឡា',
          price: 1.5,
          cost: 1.0,
          taxRate: 0,
          stock: 100,
          active: true,
          trackInventory: true,
          imageUrl: null,
          categoryId: 1,
        ),
        Product(
          id: 2,
          sku: 'SKU-2',
          barcode: '222222',
          nameEn: 'Pepsi',
          nameKm: 'ប៉ាប់ស៊ី',
          price: 1.5,
          cost: 1.0,
          taxRate: 0,
          stock: 100,
          active: true,
          trackInventory: true,
          imageUrl: null,
          categoryId: 1,
        ),
        Product(
          id: 3,
          sku: 'SKU-3',
          barcode: '333333',
          nameEn: 'Angkor Beer',
          nameKm: 'អង្គរ',
          price: 2.0,
          cost: 1.5,
          taxRate: 0,
          stock: 50,
          active: true,
          trackInventory: true,
          imageUrl: null,
          categoryId: 2,
        ),
        Product(
          id: 4,
          sku: 'SKU-4',
          barcode: '444444',
          nameEn: 'Water',
          nameKm: 'ទឹក',
          price: 0.5,
          cost: 0.2,
          taxRate: 0,
          stock: 200,
          active: true,
          trackInventory: true,
          imageUrl: null,
          categoryId: 1,
        ),
      ];
}

// Fake ProductService to avoid network calls in tests
class FakeProductService extends ProductService {
  final List<Category> _categories;
  FakeProductService({List<Category>? categories})
      : _categories = categories ?? [],
        super();

  @override
  Future<List<Product>> getProducts({
    final String? query,
    final int? categoryId,
    final int page = 0,
    final int size = 100,
  }) async {
    final all = await FakeProductRepository().getProducts();
    var filtered = all;
    if (categoryId != null) {
      filtered = filtered
          .where((final Product p) => p.categoryId == categoryId)
          .toList();
    }
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered
          .where(
            (final Product p) =>
                p.nameEn.toLowerCase().contains(q) ||
                p.nameKm.toLowerCase().contains(q),
          )
          .toList();
    }
    return filtered;
  }

  @override
  Future<List<Category>> getCategories() async => List.of(_categories);

  @override
  Future<List<Product>> getPopularProducts({final int limit = 10}) async =>
      (await FakeProductRepository().getProducts()).take(limit).toList();

  @override
  Future<List<Product>> getLowStockProducts() async =>
      (await FakeProductRepository().getProducts())
          .where((final Product p) => p.stock < 10)
          .toList();

  @override
  Future<Product> createProduct(Product product) async => product;
  @override
  Future<Product> updateProduct(Product product) async => product;
  @override
  Future<void> deleteProduct(int id) async {}
}

void main() {
  group('ProductProvider Search Logic', () {
    late ProviderContainer container;
    // Removed unused fakeRepository variable

    setUp(() {
      container = ProviderContainer(
        overrides: <Override>[
          // Override the product service provider to use our Fake service
          productServiceProvider.overrideWithValue(FakeProductService()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('searchProducts should filter by name (case insensitive)', () async {
      final notifier = container.read(productsProvider.notifier);

      // 1. Load initial data
      // We assume loadProducts populates the internal list
      await notifier.loadProducts();

      // 2. Perform Search
      await notifier.searchProducts('cola');

      // 3. Verify State
      final state = container.read(productsProvider);

      expect(state.products.length, 1);
      expect(state.products.first.nameEn, 'Coca Cola');
    });

    test('searchProducts should return all products when query is empty',
        () async {
      final notifier = container.read(productsProvider.notifier);
      await notifier.loadProducts();

      // Search then clear
      await notifier.searchProducts('cola');
      await notifier.searchProducts('');

      expect(container.read(productsProvider).products.length, 4);
    });

    test('categoriesProvider yields data from service', () async {
      final container2 = ProviderContainer(overrides: [
        productServiceProvider.overrideWithValue(
          FakeProductService(categories: [
            Category(
              id: 10,
              nameEn: 'Cats',
              nameKm: 'កាត',
              active: true,
            ),
          ]),
        ),
      ]);
      addTearDown(container2.dispose);

      final catsValue = container2.read(categoriesProvider);
      expect(catsValue.hasValue, true);
      final cats = catsValue.value;
      expect(cats, isNotNull);
      expect(cats, hasLength(1));
      expect(cats![0].nameEn, 'Cats');
    });
  });
}
