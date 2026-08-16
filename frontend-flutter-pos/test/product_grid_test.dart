import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/product_grid.dart';

// simple fake cart service for tests
class FakeCartService extends CartService {
  @override
  Future<void> clearCart() async {}
  @override
  Future<List<CartItem>> getCartItems() async => [];
  @override
  Future<void> removeCartItem(String id) async {}
  @override
  Future<void> saveCartItems(List<CartItem> items) async {}
}

void main() {
  testWidgets('ProductGrid adjusts columns based on width',
      (WidgetTester tester) async {
    final products = List.generate(
      10,
      (i) {
        final p = Product.sample();
        return Product(
          id: i + 1,
          sku: p.sku,
          barcode: p.barcode,
          nameEn: p.nameEn,
          nameKm: p.nameKm,
          price: p.price,
          cost: p.cost,
          taxRate: 0,
          stock: p.stock,
          active: p.active,
          trackInventory: p.trackInventory,
          imageUrl: p.imageUrl,
          categoryId: p.categoryId,
        );
      },
    );

    final container = ProviderContainer();
    final cartNotifier =
        CartNotifier(FakeCartService(), container as Ref<Object?>);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        cartProvider.overrideWith((ref) => cartNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ProductGrid(
              products: products,
              onLoadMore: () {},
              onProductTap: (p) {
                cartNotifier.addItem(CartItem(
                  id: 'test',
                  product: p,
                  qty: 1,
                  addedAt: 0,
                ));
              },
            ),
          ),
        ),
      ),
    ));

    // ensure grid built and contains all products
    expect(find.byType(ProductGrid), findsOneWidget);

    // check that crossAxisCount is calculated based on width (300px should yield >1)
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, greaterThan(1));

    // each product has a name text
    expect(find.text('Sample Product'), findsNWidgets(10));

    // tap first tile to add to cart
    await tester.tap(find.text('Sample Product').first);
    await tester.pumpAndSettle();
    expect(cartNotifier.state.items.length, 1);
  });
}
