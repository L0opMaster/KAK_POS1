import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';

/// Covers the cart-side stock cap added to `addItemFromProduct`/
/// `incrementItem`/`setItemQuantity` — a tracked product's cart quantity
/// (summed across every line) must never exceed `availableSaleQty ?? stock`,
/// and an untracked product must never be capped at all, matching the
/// backend's own `outOfStock = trackInventory && availableSaleQty <= 0`
/// formula. Uses the same `ProviderContainer` + real `CartNotifier` pattern
/// as `cart_provider_resilience_test.dart`.
Product _product({
  int id = 1,
  bool active = true,
  bool sellable = true,
  bool trackInventory = false,
  double stock = 0,
  double? availableSaleQty,
}) =>
    Product(
      id: id,
      sku: 'SKU-$id',
      barcode: 'BC-$id',
      nameEn: 'Test Product',
      nameKm: 'ផលិតផលសាកល្បង',
      cost: 1,
      taxRate: 0,
      price: 5,
      active: active,
      sellable: sellable,
      trackInventory: trackInventory,
      categoryId: 1,
      stock: stock,
      availableSaleQty: availableSaleQty,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('tracked product: cart quantity is capped at stock', () async {
    final container = makeContainer();
    final notifier = container.read(cartProvider.notifier);
    final product = _product(trackInventory: true, stock: 2);

    final r1 = await notifier.addItemFromProduct(product);
    expect(r1.ok, isTrue);
    final r2 = await notifier.addItemFromProduct(product);
    expect(r2.ok, isTrue);

    final r3 = await notifier.addItemFromProduct(product);
    expect(r3.ok, isFalse);
    expect(r3.stockCapAvailableQty, 2);

    final items = container.read(cartProvider).items;
    expect(items.length, 1);
    expect(items.single.qty, 2);
  });

  test('tracked product: incrementItem blocked at the cap', () async {
    final container = makeContainer();
    final notifier = container.read(cartProvider.notifier);
    final product = _product(trackInventory: true, stock: 2);

    await notifier.addItemFromProduct(product);
    final String lineId = container.read(cartProvider).items.single.id;
    await notifier.incrementItem(lineId);
    expect(container.read(cartProvider).items.single.qty, 2);

    final result = await notifier.incrementItem(lineId);
    expect(result.ok, isFalse);
    expect(result.stockCapAvailableQty, 2);
    expect(container.read(cartProvider).items.single.qty, 2);
  });

  test('tracked product: setItemQuantity rejects a target above stock',
      () async {
    final container = makeContainer();
    final notifier = container.read(cartProvider.notifier);
    final product = _product(trackInventory: true, stock: 2);

    await notifier.addItemFromProduct(product);
    final String lineId = container.read(cartProvider).items.single.id;

    final result = await notifier.setItemQuantity(lineId, 5);
    expect(result.ok, isFalse);
    expect(result.stockCapAvailableQty, 2);
    expect(container.read(cartProvider).items.single.qty, 1);
  });

  test('tracked product: availableSaleQty is preferred over raw stock',
      () async {
    final container = makeContainer();
    final notifier = container.read(cartProvider.notifier);
    final product =
        _product(trackInventory: true, stock: 10, availableSaleQty: 1);

    final r1 = await notifier.addItemFromProduct(product);
    expect(r1.ok, isTrue);

    final r2 = await notifier.addItemFromProduct(product);
    expect(r2.ok, isFalse);
    expect(r2.stockCapAvailableQty, 1);
  });

  test('untracked product: never capped, even at stock 0', () async {
    final container = makeContainer();
    final notifier = container.read(cartProvider.notifier);
    final product = _product(trackInventory: false, stock: 0);

    for (int i = 0; i < 5; i++) {
      final result = await notifier.addItemFromProduct(product);
      expect(result.ok, isTrue);
    }
    expect(container.read(cartProvider).items.single.qty, 5);
  });

  test('inactive product is blocked on the new-line path', () async {
    final container = makeContainer();
    final notifier = container.read(cartProvider.notifier);
    final product = _product(active: false);

    final result = await notifier.addItemFromProduct(product);
    expect(result.ok, isFalse);
    expect(container.read(cartProvider).items, isEmpty);
  });

  test('unsellable product is blocked on the new-line path', () async {
    final container = makeContainer();
    final notifier = container.read(cartProvider.notifier);
    final product = _product(sellable: false);

    final result = await notifier.addItemFromProduct(product);
    expect(result.ok, isFalse);
    expect(container.read(cartProvider).items, isEmpty);
  });
}
