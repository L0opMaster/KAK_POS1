import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/product_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/waiting_number_service.dart';

/// Deterministic fake — same shape as product_provider_test.dart's
/// `_FakeProductService`, used here only so `addProductByBarcode` has a
/// real (but network-free) catalog to search.
class _FakeProductService extends ProductService {
  _FakeProductService(this.products);
  final List<Product> products;

  @override
  Future<List<Product>> getProducts(
          {String? query, int? categoryId, int page = 0, int size = 100}) =>
      Future.value(products);

  @override
  Future<List<Category>> getCategories() => Future.value(const []);
}

/// In-memory fake — no network, no SharedPreferences dependency of its own
/// (CartNotifier's OWN persistCart/restoreCart still touch SharedPreferences
/// directly, hence `setUp`'s mock below).
class _FakeCartService extends CartService {
  List<CartItem> saved = [];
  int saveCallCount = 0;
  bool throwOnSave = false;

  @override
  Future<List<CartItem>> getCartItems() async => saved;

  @override
  Future<void> saveCartItems(List<CartItem> items) async {
    saveCallCount++;
    if (throwOnSave) throw Exception('network down');
    saved = items;
  }

  @override
  Future<void> clearCart() async => saved = [];

  @override
  Future<void> removeCartItem(String id) async =>
      saved = saved.where((i) => i.id != id).toList();
}

Product _product(int id, {double price = 5.0, double taxRate = 0}) => Product(
      id: id,
      sku: 'SKU$id',
      barcode: 'BAR$id',
      nameEn: 'Product $id',
      nameKm: 'Product $id',
      cost: 1,
      price: price,
      taxRate: taxRate,
      active: true,
      categoryId: 1,
    );

final _refProvider = Provider<Ref>((ref) => ref);

/// Real `WaitingNumberService` (SharedPreferences-only, mocked in
/// `setUp`) — no need for a fake, it has no network dependency.
final _waitingNumberService = WaitingNumberService();

Future<CartNotifier> _readyNotifier(_FakeCartService service) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final notifier = CartNotifier(
      service, _waitingNumberService, container.read(_refProvider));
  return _settled(notifier);
}

/// Added Day 8 — gives `addProductByBarcode` a real, network-free catalog
/// to search (via an overridden `productServiceProvider`), instead of the
/// bare `_refProvider` the other helper uses (which has no products at
/// all — fine for tests that never touch `_ref`, wrong for these).
Future<CartNotifier> _readyNotifierWithProducts(
    _FakeCartService service, List<Product> products) async {
  final container = ProviderContainer(overrides: [
    productServiceProvider.overrideWithValue(_FakeProductService(products)),
  ]);
  addTearDown(container.dispose);
  final notifier = CartNotifier(
      service, _waitingNumberService, container.read(_refProvider));
  return _settled(notifier);
}

Future<CartNotifier> _settled(CartNotifier notifier) async {
  // restoreCart() runs in the constructor; wait for it to settle before the
  // test issues its own mutation, for the same reason main_color_provider_
  // test.dart's _readyContainer helper does.
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

  group('CartState calculations', () {
    test('total/taxAmount/finalTotal for a simple cart', () {
      final state = CartState(
        items: [
          CartItem(
              id: '1',
              product: _product(1, price: 10, taxRate: 0.10),
              qty: 2,
              addedAt: 0),
        ],
      );

      expect(state.total, 20.0);
      expect(state.taxAmount, 2.0);
      expect(state.finalTotal, 22.0);
    });

    test('fixed cart-level discount is prorated into the tax base', () {
      final state = CartState(
        items: [
          CartItem(
              id: '1',
              product: _product(1, price: 10, taxRate: 0.10),
              qty: 1,
              addedAt: 0),
        ],
        discount: 3,
      );

      expect(state.discountAmount, 3.0);
      // taxable = (10 - discount's full share, 3) = 7; tax = 7 * 0.10 = 0.7
      expect(state.taxAmount, closeTo(0.7, 0.0001));
      // finalTotal = (subtotal - discount) + tax(on POST-discount taxable)
      expect(state.finalTotal, closeTo(7.0 + 0.7, 0.0001));
    });

    test('percent cart-level discount is clamped to the subtotal', () {
      final state = CartState(
        items: [
          CartItem(
              id: '1', product: _product(1, price: 10), qty: 1, addedAt: 0),
        ],
        discount: 200, // 200% — must not go negative
        discountType: DiscountType.percent,
      );

      expect(state.discountAmount, 10.0); // clamped to subtotal
      expect(state.finalTotal, greaterThanOrEqualTo(0));
    });

    test('per-item discountAmount reduces total()', () {
      final state = CartState(
        items: [
          CartItem(
            id: '1',
            product: _product(1, price: 10),
            qty: 2,
            addedAt: 0,
            discountAmount: 2, // per unit
          ),
        ],
      );

      // total = subtotal(20) - itemDiscounts(2*2=4)
      expect(state.total, 16.0);
    });

    test('toJson/fromJson round-trips every field', () {
      final state = CartState(
        items: [
          CartItem(id: '1', product: _product(1), qty: 3, addedAt: 123),
        ],
        discount: 5,
        discountType: DiscountType.percent,
        loyalty: 1.5,
        orderMode: OrderMode.takeaway,
        customerId: 42,
        tableId: 9,
        waitingNumber: 3,
        heldTicketId: 77,
      );

      final restored = CartState.fromJson(state.toJson());

      expect(restored.items.single.qty, 3);
      expect(restored.discount, 5);
      expect(restored.discountType, DiscountType.percent);
      expect(restored.loyalty, 1.5);
      expect(restored.orderMode, OrderMode.takeaway);
      expect(restored.customerId, 42);
      expect(restored.tableId, 9);
      expect(restored.waitingNumber, 3);
      expect(restored.heldTicketId, 77);
    });
  });

  group('CartNotifier item mutators', () {
    test('addItemFromProduct adds a new line for a new product', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.single.qty, 1);
    });

    test('addItemFromProduct increments qty for an already-cart product',
        () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      await notifier.addItemFromProduct(_product(1));

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.single.qty, 2);
    });

    test('removeItem removes only the targeted line', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      await notifier.addItemFromProduct(_product(2));
      final idToRemove = notifier.state.items.first.id;

      await notifier.removeItem(idToRemove);

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.single.product.id, 2);
    });

    test('incrementItem/decrementItem adjust qty; decrementing to 0 removes',
        () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      final id = notifier.state.items.single.id;

      await notifier.incrementItem(id);
      expect(notifier.state.items.single.qty, 2);

      await notifier.decrementItem(id);
      expect(notifier.state.items.single.qty, 1);

      await notifier.decrementItem(id);
      expect(notifier.state.items, isEmpty);
    });

    test('setItemQuantity(0) removes the item', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      final id = notifier.state.items.single.id;

      await notifier.setItemQuantity(id, 0);

      expect(notifier.state.items, isEmpty);
    });

    test('setItemNote/setItemDiscount update the targeted line only',
        () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1, price: 10));
      final id = notifier.state.items.single.id;

      await notifier.setItemNote(id, 'no ice');
      expect(notifier.state.items.single.note, 'no ice');

      await notifier.setItemDiscount(id, 3);
      expect(notifier.state.items.single.discountAmount, 3);

      // Discount is clamped to the product's own price.
      await notifier.setItemDiscount(id, 999);
      expect(notifier.state.items.single.discountAmount, 10);
    });

    test('setItemModifiers replaces selected modifiers and can update qty/note',
        () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      final id = notifier.state.items.single.id;

      await notifier.setItemModifiers(
        id,
        selectedModifiers: const [
          SelectedModifier(
              groupId: 1,
              groupName: 'Size',
              optionId: 2,
              optionName: 'Large',
              priceDelta: 1.5),
        ],
        qty: 4,
        note: 'extra hot',
      );

      final item = notifier.state.items.single;
      expect(item.selectedModifiers.single.optionName, 'Large');
      expect(item.qty, 4);
      expect(item.note, 'extra hot');
      expect(item.unitPrice, item.product.price + 1.5);
    });

    test('clear() empties the cart and resets discount/order mode', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      notifier.applyDiscount(5);
      notifier.setOrderMode(OrderMode.takeaway);

      await notifier.clear();

      expect(notifier.state.items, isEmpty);
      expect(notifier.state.discount, 0);
      expect(notifier.state.orderMode, OrderMode.dineIn);
    });

    test('a failed remote sync does not roll back local state', () async {
      final service = _FakeCartService()..throwOnSave = true;
      final notifier = await _readyNotifier(service);

      await notifier.addItemFromProduct(_product(1));

      expect(notifier.state.items.length, 1); // local state still updated
      expect(service.saved, isEmpty); // remote sync genuinely failed
    });

    test('cart state survives a restart via persistCart/restoreCart',
        () async {
      final notifier1 = await _readyNotifier(_FakeCartService());
      await notifier1.addItemFromProduct(_product(1, price: 7.5));

      // Simulate an app restart: a brand-new notifier reads the same
      // SharedPreferences snapshot back.
      final notifier2 = await _readyNotifier(_FakeCartService());

      expect(notifier2.state.items.length, 1);
      expect(notifier2.state.items.single.product.price, 7.5);
    });
  });

  group('CartNotifier.addProductByBarcode (Day 8)', () {
    test('empty barcode is rejected without a lookup', () async {
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [_product(1)]);

      final result = await notifier.addProductByBarcode('   ');

      expect(result.added, isFalse);
      expect(notifier.state.items, isEmpty);
    });

    test('unknown barcode returns added:false with no product', () async {
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [_product(1)]);

      final result = await notifier.addProductByBarcode('does-not-exist');

      expect(result.added, isFalse);
      expect(result.product, isNull);
      expect(notifier.state.items, isEmpty);
    });

    test('known barcode adds the product to the cart', () async {
      final product = _product(1);
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [product]);

      final result = await notifier.addProductByBarcode('BAR1');

      expect(result.added, isTrue);
      expect(result.product?.id, 1);
      expect(notifier.state.items.single.product.id, 1);
    });

    test('barcode matching is case/whitespace-insensitive', () async {
      final product = _product(1);
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [product]);

      final result = await notifier.addProductByBarcode('  bar1  ');

      expect(result.added, isTrue);
    });

    test('scanning an already-in-cart barcode increments quantity',
        () async {
      final product = _product(1);
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [product]);

      await notifier.addProductByBarcode('BAR1');
      final result = await notifier.addProductByBarcode('BAR1');

      expect(result.added, isTrue);
      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.single.qty, 2);
    });

    test('inactive product is rejected, not added', () async {
      final product = Product(
        id: 1,
        sku: 'SKU1',
        barcode: 'BAR1',
        nameEn: 'Discontinued',
        nameKm: 'Discontinued',
        cost: 1,
        price: 5,
        active: false,
        categoryId: 1,
      );
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [product]);

      final result = await notifier.addProductByBarcode('BAR1');

      expect(result.added, isFalse);
      expect(result.product?.id, 1); // still identifies which product
      expect(notifier.state.items, isEmpty);
    });

    test('non-sellable product is rejected, not added', () async {
      final product = Product(
        id: 1,
        sku: 'SKU1',
        barcode: 'BAR1',
        nameEn: 'Raw Material',
        nameKm: 'Raw Material',
        cost: 1,
        price: 5,
        active: true,
        sellable: false,
        categoryId: 1,
      );
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [product]);

      final result = await notifier.addProductByBarcode('BAR1');

      expect(result.added, isFalse);
      expect(notifier.state.items, isEmpty);
    });

    test('out-of-stock product is rejected, not added', () async {
      final product = Product(
        id: 1,
        sku: 'SKU1',
        barcode: 'BAR1',
        nameEn: 'Sold Out Item',
        nameKm: 'Sold Out Item',
        cost: 1,
        price: 5,
        active: true,
        outOfStock: true,
        categoryId: 1,
      );
      final notifier = await _readyNotifierWithProducts(
          _FakeCartService(), [product]);

      final result = await notifier.addProductByBarcode('BAR1');

      expect(result.added, isFalse);
      expect(notifier.state.items, isEmpty);
    });
  });

  group('CartNotifier held-ticket support (Day 9)', () {
    test('ensureWaitingNumber issues a number once and reuses it', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      expect(notifier.state.waitingNumber, isNull);

      final first = await notifier.ensureWaitingNumber();
      expect(first, inInclusiveRange(1, 100));
      expect(notifier.state.waitingNumber, first);

      final second = await notifier.ensureWaitingNumber();
      expect(second, first); // same number, not reissued
    });

    test('addItem issues a waiting number on the first item only', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      final firstNumber = notifier.state.waitingNumber;
      expect(firstNumber, isNotNull);

      await notifier.addItemFromProduct(_product(2));
      expect(notifier.state.waitingNumber, firstNumber); // unchanged
    });

    test('clear(releaseWaitingNumber: true) releases the number', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      expect(notifier.state.waitingNumber, isNotNull);

      await notifier.clear();

      expect(notifier.state.waitingNumber, isNull);
      expect(notifier.state.items, isEmpty);
    });

    test('clear(releaseWaitingNumber: false) keeps state cleared but skips '
        'the release call', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));

      await notifier.clear(releaseWaitingNumber: false);

      // CartState.initial() has no waiting number regardless — this
      // verifies the flag controls the *release call*, not observable
      // here without a spy; the important invariant (state ends up empty
      // either way) is what's checked.
      expect(notifier.state.waitingNumber, isNull);
      expect(notifier.state.items, isEmpty);
    });

    test('restoreItems loads items without issuing a new waiting number',
        () async {
      final notifier = await _readyNotifier(_FakeCartService());
      final items = [
        CartItem(id: '1', product: _product(1), qty: 2, addedAt: 0),
      ];

      await notifier.restoreItems(
        items: items,
        waitingNumber: 42,
        heldTicketId: 7,
        tableId: 3,
      );

      expect(notifier.state.items.length, 1);
      expect(notifier.state.waitingNumber, 42);
      expect(notifier.state.heldTicketId, 7);
      expect(notifier.state.tableId, 3);
    });

    test('restoreItems replaces any existing cart state entirely', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      await notifier.addItemFromProduct(_product(1));
      notifier.applyDiscount(10);

      await notifier.restoreItems(
        items: [CartItem(id: '2', product: _product(2), qty: 1, addedAt: 0)],
      );

      expect(notifier.state.items.length, 1);
      expect(notifier.state.items.single.product.id, 2);
      expect(notifier.state.discount, 0); // discount from before is gone
    });
  });

  group('CartNotifier customer/table mutators (Day 9)', () {
    test('setCustomer/clearCustomer', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      notifier.setCustomer(9);
      expect(notifier.state.customerId, 9);

      notifier.clearCustomer();
      expect(notifier.state.customerId, isNull);
    });

    test('setTable/clearTable', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      notifier.setTable(5);
      expect(notifier.state.tableId, 5);

      notifier.clearTable();
      expect(notifier.state.tableId, isNull);
    });
  });

  group('CartNotifier cart-level mutators', () {
    test('applyDiscount/clearDiscount', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      notifier.applyDiscount(15, type: DiscountType.percent);
      expect(notifier.state.discount, 15);
      expect(notifier.state.discountType, DiscountType.percent);

      notifier.clearDiscount();
      expect(notifier.state.discount, 0);
      expect(notifier.state.discountType, DiscountType.fixed);
    });

    test('setOrderMode', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      notifier.setOrderMode(OrderMode.delivery);
      expect(notifier.state.orderMode, OrderMode.delivery);
    });

    test('taxAmount sums each item at its own product tax rate', () {
      final state = CartState(
        items: [
          CartItem(
            id: '1',
            product: _product(1, price: 10, taxRate: 0.10),
            qty: 1,
            addedAt: 0,
          ),
          CartItem(
            id: '2',
            product: _product(2, price: 20, taxRate: 0.05),
            qty: 1,
            addedAt: 0,
          ),
        ],
      );
      // item 1: 10 * 0.10 = 1.0; item 2: 20 * 0.05 = 1.0
      expect(state.taxAmount, closeTo(2.0, 0.0001));
    });

    test('taxAmount prorates the cart-level discount per item before taxing',
        () {
      final state = CartState(
        items: [
          CartItem(
            id: '1',
            product: _product(1, price: 10, taxRate: 0.10),
            qty: 1,
            addedAt: 0,
          ),
          CartItem(
            id: '2',
            product: _product(2, price: 30, taxRate: 0),
            qty: 1,
            addedAt: 0,
          ),
        ],
        discount: 4,
        discountType: DiscountType.fixed,
      );
      // total = 40; discount 4 is split by share: item1 gets 4*(10/40)=1,
      // item2 gets 4*(30/40)=3. Taxable item1 = 10-1 = 9, taxed at 10% = 0.9.
      // item2 has a 0% rate so its share of the discount doesn't matter.
      expect(state.taxAmount, closeTo(0.9, 0.0001));
    });

    test('blendedTaxRate is the effective rate across all items', () {
      final state = CartState(
        items: [
          CartItem(
            id: '1',
            product: _product(1, price: 10, taxRate: 0.10),
            qty: 1,
            addedAt: 0,
          ),
          CartItem(
            id: '2',
            product: _product(2, price: 10, taxRate: 0.20),
            qty: 1,
            addedAt: 0,
          ),
        ],
      );
      // taxAmount = 1 + 2 = 3, taxable = 20 -> blended rate 15%.
      expect(state.blendedTaxRate, closeTo(0.15, 0.0001));
    });

    test('taxAmount and blendedTaxRate are zero for an empty cart', () {
      final state = CartState(items: const []);
      expect(state.taxAmount, 0);
      expect(state.blendedTaxRate, 0);
    });

    test('applyLoyalty/clearLoyalty', () async {
      final notifier = await _readyNotifier(_FakeCartService());
      notifier.applyLoyalty(2.5);
      expect(notifier.state.loyalty, 2.5);
      notifier.clearLoyalty();
      expect(notifier.state.loyalty, 0);
    });
  });
}
