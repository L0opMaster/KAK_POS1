import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/product_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';

/// Simple in-memory implementation for provider unit tests.
class _InMemoryProductService extends ProductService {
  final List<Product> _store = [];

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 100,
  }) async {
    return List.of(_store);
  }

  @override
  Future<Product> createProduct(Product product) async {
    final created = product.copyWith(id: _store.length + 1);
    _store.add(created);
    return created;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    final idx = _store.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      _store[idx] = product;
    }
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {
    _store.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<Category>> getCategories() async => [];

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async => [];

  @override
  Future<List<Product>> getLowStockProducts() async => [];
}

void main() {
  test('ProductNotifier add/update/delete cycle', () async {
    final service = _InMemoryProductService();
    final container = ProviderContainer(overrides: [
      productServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);

    final notifier = container.read(productsProvider.notifier);

    // start empty
    await notifier.loadProducts();
    expect(container.read(productsProvider).products, isEmpty);

    // add new product
    final prod = Product.sample().copyWith(nameEn: 'Foo');
    await notifier.addProduct(prod);
    expect(container.read(productsProvider).products.length, 1);
    var fetched = container.read(productsProvider).products.first;
    expect(fetched.nameEn, 'Foo');

    // update
    final updated = fetched.copyWith(nameEn: 'Bar');
    await notifier.updateProduct(updated);
    fetched = container.read(productsProvider).products.first;
    expect(fetched.nameEn, 'Bar');

    // delete
    await notifier.deleteProduct(fetched.id);
    expect(container.read(productsProvider).products, isEmpty);
  });
}
