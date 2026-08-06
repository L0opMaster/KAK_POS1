import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/product_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';

// fake cart service used by tests
class FakeCartService extends CartService {
  @override
  Future<void> clearCart() async {}
  @override
  Future<List<CartItem>> getCartItems() async => [];
  @override
  Future<void> removeCartItem(final String id) async {}
  @override
  Future<void> saveCartItems(final List<CartItem> items) async {}
}

// fake product service just returns a fixed list (categories optional)
class FakeProductService extends ProductService {
  final List<Product> list;
  final List<Category> categories;
  FakeProductService(this.list, {this.categories = const []});

  @override
  Future<List<Product>> getProducts({
    final String? query,
    final int? categoryId,
    final int page = 0,
    final int size = 100,
  }) async =>
      list;
  @override
  Future<List<Category>> getCategories() async => categories;
  @override
  Future<List<Product>> getPopularProducts({final int limit = 10}) async =>
      list.take(limit).toList();
  @override
  Future<List<Product>> getLowStockProducts() async => list;

  @override
  Future<Product> createProduct(final Product product) async => product;
  @override
  Future<Product> updateProduct(final Product product) async => product;
  @override
  Future<void> deleteProduct(final int id) async {}
}

// Helper for tests: add product to cart by barcode
void addProductToCartByBarcode(
  T Function<T>(ProviderListenable<T>) read,
  final String barcode,
) {
  final CartNotifier notifier = read(cartProvider.notifier);
  final List<Product> products = read(productsProvider).products;
  final Product product = products.firstWhere(
    (final Product p) => p.barcode == barcode,
    orElse: () => throw StateError('Product not found'),
  );
  notifier.addItemFromProduct(product);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('addProductToCartByBarcode adds matching product', () async {
    final List<Product> products = [
      Product.sample().copyWith(barcode: 'ABC123')
    ];
    final ProviderContainer container = ProviderContainer(overrides: [
      productServiceProvider.overrideWithValue(FakeProductService(products)),
      cartProvider.overrideWith(
          (final StateNotifierProviderRef<CartNotifier, CartState> ref) =>
              CartNotifier(FakeCartService(), ref)),
    ]);

    final ref = container.read;
    await container.read(productsProvider.notifier).loadProducts();

    expect(container.read(cartProvider).items, isEmpty);

    addProductToCartByBarcode(ref, 'ABC123');
    expect(container.read(cartProvider).items.length, 1);
    expect(container.read(cartProvider).items.first.product.barcode, 'ABC123');
  });

  test('addProductToCartByBarcode throws if no product found', () async {
    final ProviderContainer container = ProviderContainer(overrides: [
      productServiceProvider.overrideWithValue(FakeProductService([])),
      cartProvider.overrideWith(
          (final StateNotifierProviderRef<CartNotifier, CartState> ref) =>
              CartNotifier(FakeCartService(), ref)),
    ]);
    final ref = container.read;
    await container.read(productsProvider.notifier).loadProducts();
    expect(() => addProductToCartByBarcode(ref, 'X'), throwsStateError);
  });
}
