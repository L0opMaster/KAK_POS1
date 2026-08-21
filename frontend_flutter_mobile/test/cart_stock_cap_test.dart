import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/waiting_number_service.dart';

/// Covers the cart-side stock cap added to `addItemFromProduct`/
/// `incrementItem`/`setItemQuantity` — a tracked product's cart quantity
/// (summed across every line) must never exceed `availableSaleQty ?? stock`,
/// and an untracked product must never be capped at all, matching the
/// backend's own `outOfStock = trackInventory && availableSaleQty <= 0`
/// formula. Mirrors `cart_provider_test.dart`'s `_readyNotifier` setup and
/// frontend-flutter-pos's `cart_stock_cap_test.dart`.
class _FakeCartService extends CartService {
  List<CartItem> saved = [];

  @override
  Future<List<CartItem>> getCartItems() async => saved;

  @override
  Future<void> saveCartItems(List<CartItem> items) async => saved = items;

  @override
  Future<void> clearCart() async => saved = [];

  @override
  Future<void> removeCartItem(String id) async =>
      saved = saved.where((i) => i.id != id).toList();
}

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
      price: 5,
      active: active,
      sellable: sellable,
      trackInventory: trackInventory,
      categoryId: 1,
      stock: stock,
      availableSaleQty: availableSaleQty,
    );

final _refProvider = Provider<Ref>((ref) => ref);
final _waitingNumberService = WaitingNumberService();

Future<CartNotifier> _readyNotifier() async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final notifier = CartNotifier(
      _FakeCartService(), _waitingNumberService, container.read(_refProvider));
  for (var i = 0; i < 20; i++) {
    if (!notifier.state.loading) break;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tracked product: cart quantity is capped at stock', () async {
    final notifier = await _readyNotifier();
    final product = _product(trackInventory: true, stock: 2);

    final r1 = await notifier.addItemFromProduct(product);
    expect(r1.ok, isTrue);
    final r2 = await notifier.addItemFromProduct(product);
    expect(r2.ok, isTrue);

    final r3 = await notifier.addItemFromProduct(product);
    expect(r3.ok, isFalse);
    expect(r3.stockCapAvailableQty, 2);

    expect(notifier.state.items.length, 1);
    expect(notifier.state.items.single.qty, 2);
  });

  test('tracked product: incrementItem blocked at the cap', () async {
    final notifier = await _readyNotifier();
    final product = _product(trackInventory: true, stock: 2);

    await notifier.addItemFromProduct(product);
    final String lineId = notifier.state.items.single.id;
    await notifier.incrementItem(lineId);
    expect(notifier.state.items.single.qty, 2);

    final result = await notifier.incrementItem(lineId);
    expect(result.ok, isFalse);
    expect(result.stockCapAvailableQty, 2);
    expect(notifier.state.items.single.qty, 2);
  });

  test('tracked product: setItemQuantity rejects a target above stock',
      () async {
    final notifier = await _readyNotifier();
    final product = _product(trackInventory: true, stock: 2);

    await notifier.addItemFromProduct(product);
    final String lineId = notifier.state.items.single.id;

    final result = await notifier.setItemQuantity(lineId, 5);
    expect(result.ok, isFalse);
    expect(result.stockCapAvailableQty, 2);
    expect(notifier.state.items.single.qty, 1);
  });

  test('tracked product: availableSaleQty is preferred over raw stock',
      () async {
    final notifier = await _readyNotifier();
    final product =
        _product(trackInventory: true, stock: 10, availableSaleQty: 1);

    final r1 = await notifier.addItemFromProduct(product);
    expect(r1.ok, isTrue);

    final r2 = await notifier.addItemFromProduct(product);
    expect(r2.ok, isFalse);
    expect(r2.stockCapAvailableQty, 1);
  });

  test('untracked product: never capped, even at stock 0', () async {
    final notifier = await _readyNotifier();
    final product = _product(trackInventory: false, stock: 0);

    for (int i = 0; i < 5; i++) {
      final result = await notifier.addItemFromProduct(product);
      expect(result.ok, isTrue);
    }
    expect(notifier.state.items.single.qty, 5);
  });

  test('inactive product is blocked on the new-line path', () async {
    final notifier = await _readyNotifier();
    final product = _product(active: false);

    final result = await notifier.addItemFromProduct(product);
    expect(result.ok, isFalse);
    expect(notifier.state.items, isEmpty);
  });

  test('unsellable product is blocked on the new-line path', () async {
    final notifier = await _readyNotifier();
    final product = _product(sellable: false);

    final result = await notifier.addItemFromProduct(product);
    expect(result.ok, isFalse);
    expect(notifier.state.items, isEmpty);
  });
}
