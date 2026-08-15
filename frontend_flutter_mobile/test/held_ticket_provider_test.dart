import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/held_ticket_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/held_ticket_service.dart';

class _FakeCartService extends CartService {
  List<CartItem> saved = [];

  @override
  Future<List<CartItem>> getCartItems() async => saved;
  @override
  Future<void> saveCartItems(List<CartItem> items) async => saved = items;
  @override
  Future<void> clearCart() async => saved = [];
  @override
  Future<void> removeCartItem(String id) async {}
}

/// In-memory fake — same contract as `LocalHeldTicketService` but without
/// touching SharedPreferences, so tests are deterministic regardless of
/// mock state.
class _FakeHeldTicketService extends HeldTicketService {
  _FakeHeldTicketService(super.api, super.cartService);

  final Map<String, Map<String, dynamic>> store = {};
  int _nextId = 1;
  bool throwOnHold = false;

  @override
  Future<List<Map<String, dynamic>>> fetchHeldTickets() async =>
      store.values.toList();

  @override
  Future<Map<String, dynamic>?> holdTicket({
    required Map<String, dynamic> ticketData,
  }) async {
    if (throwOnHold) throw Exception('backend unreachable');
    final providedId = ticketData['id']?.toString();
    final id = providedId ?? (_nextId++).toString();
    final copy = Map<String, dynamic>.from(ticketData)..['id'] = id;
    store[id] = copy;
    return copy;
  }

  @override
  Future<bool> releaseTicket({required String ticketId}) async {
    store.remove(ticketId);
    return true;
  }
}

Product _product(int id) => Product(
  id: id,
  sku: 'SKU$id',
  barcode: 'BAR$id',
  nameEn: 'Product $id',
  nameKm: 'Product $id',
  cost: 1,
  price: 5,
  active: true,
  categoryId: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HeldTicketNotifier', () {
    test(
      'holdCurrentCart creates a new ticket and clears the working cart',
      () async {
        final container = ProviderContainer(
          overrides: [
            cartServiceProvider.overrideWithValue(_FakeCartService()),
            heldTicketServiceProvider.overrideWith(
              (ref) => _FakeHeldTicketService(
                ref.read(apiServiceProvider),
                ref.read(cartServiceProvider),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final cartNotifier = container.read(cartProvider.notifier);
        for (var i = 0; i < 20; i++) {
          if (!cartNotifier.state.loading) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await cartNotifier.addItemFromProduct(_product(1));
        expect(cartNotifier.state.items, isNotEmpty);

        final heldNotifier = container.read(heldTicketProvider.notifier);
        final ticketId = await heldNotifier.holdCurrentCart(
          cartNotifier.state.items,
        );

        expect(ticketId, isNotNull);
        expect(cartNotifier.state.items, isEmpty); // working cart cleared
        expect(container.read(heldTicketProvider).tickets, isNotEmpty);
      },
    );

    test(
      'holdCurrentCart returns null and records an error on failure',
      () async {
        final service = _FakeHeldTicketService(ApiService(), _FakeCartService())
          ..throwOnHold = true;
        final container = ProviderContainer(
          overrides: [
            cartServiceProvider.overrideWithValue(_FakeCartService()),
            heldTicketServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(heldTicketProvider.notifier)
            .holdCurrentCart([
              CartItem(id: '1', product: _product(1), qty: 1, addedAt: 0),
            ]);

        expect(result, isNull);
        expect(container.read(heldTicketProvider).error, isNotNull);
      },
    );

    test('restoreTicket loads the ticket into the active cart and marks it '
        'in-progress (hidden from loadHeldTickets)', () async {
      final service = _FakeHeldTicketService(ApiService(), _FakeCartService());
      final container = ProviderContainer(
        overrides: [
          cartServiceProvider.overrideWithValue(_FakeCartService()),
          heldTicketServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartProvider.notifier);
      for (var i = 0; i < 20; i++) {
        if (!cartNotifier.state.loading) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final ticket = HeldOrder(
        id: 1,
        status: 'open',
        cartItems: [
          CartItem(id: 'x', product: _product(1), qty: 3, addedAt: 0),
        ],
      );
      service.store['1'] = ticket.toJson();

      await container.read(heldTicketProvider.notifier).restoreTicket(ticket);

      expect(cartNotifier.state.items.single.qty, 3);
      expect(cartNotifier.state.heldTicketId, 1);

      await container.read(heldTicketProvider.notifier).loadHeldTickets();
      expect(
        container.read(heldTicketProvider).tickets,
        isEmpty,
      ); // in_progress, hidden
    });

    test('cancelResume puts an in-progress ticket back to open and clears '
        'the cart', () async {
      final service = _FakeHeldTicketService(ApiService(), _FakeCartService());
      final container = ProviderContainer(
        overrides: [
          cartServiceProvider.overrideWithValue(_FakeCartService()),
          heldTicketServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartProvider.notifier);
      for (var i = 0; i < 20; i++) {
        if (!cartNotifier.state.loading) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final ticket = HeldOrder(
        id: 5,
        status: 'open',
        cartItems: [
          CartItem(id: 'y', product: _product(1), qty: 1, addedAt: 0),
        ],
      );
      service.store['5'] = ticket.toJson();
      await container.read(heldTicketProvider.notifier).restoreTicket(ticket);
      expect(cartNotifier.state.heldTicketId, 5);

      await container.read(heldTicketProvider.notifier).cancelResume();

      expect(cartNotifier.state.items, isEmpty);
      expect(service.store['5']?['status'], 'open'); // put back, not deleted
    });

    test('cancelResume with no resumed ticket just clears the cart', () async {
      final container = ProviderContainer(
        overrides: [
          cartServiceProvider.overrideWithValue(_FakeCartService()),
          heldTicketServiceProvider.overrideWith(
            (ref) => _FakeHeldTicketService(
              ref.read(apiServiceProvider),
              ref.read(cartServiceProvider),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartProvider.notifier);
      for (var i = 0; i < 20; i++) {
        if (!cartNotifier.state.loading) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      await cartNotifier.addItemFromProduct(_product(1));

      await container.read(heldTicketProvider.notifier).cancelResume();

      expect(cartNotifier.state.items, isEmpty);
    });

    test('cancelCurrentTicket voids the resumed ticket on the backend '
        '(not put back on hold) and clears the cart', () async {
      final service = _FakeHeldTicketService(ApiService(), _FakeCartService());
      final container = ProviderContainer(
        overrides: [
          cartServiceProvider.overrideWithValue(_FakeCartService()),
          heldTicketServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartProvider.notifier);
      for (var i = 0; i < 20; i++) {
        if (!cartNotifier.state.loading) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      final ticket = HeldOrder(
        id: 7,
        status: 'open',
        cartItems: [
          CartItem(id: 'z', product: _product(1), qty: 1, addedAt: 0),
        ],
      );
      service.store['7'] = ticket.toJson();
      await container.read(heldTicketProvider.notifier).restoreTicket(ticket);
      expect(cartNotifier.state.heldTicketId, 7);

      await container.read(heldTicketProvider.notifier).cancelCurrentTicket();

      expect(cartNotifier.state.items, isEmpty);
      // Unlike cancelResume (put back to 'open'), cancelCurrentTicket
      // permanently releases the ticket — it must be gone entirely.
      expect(service.store.containsKey('7'), isFalse);
    });

    test(
      'cancelCurrentTicket with no resumed ticket just clears the cart',
      () async {
        final container = ProviderContainer(
          overrides: [
            cartServiceProvider.overrideWithValue(_FakeCartService()),
            heldTicketServiceProvider.overrideWith(
              (ref) => _FakeHeldTicketService(
                ref.read(apiServiceProvider),
                ref.read(cartServiceProvider),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final cartNotifier = container.read(cartProvider.notifier);
        for (var i = 0; i < 20; i++) {
          if (!cartNotifier.state.loading) break;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        await cartNotifier.addItemFromProduct(_product(1));

        await container.read(heldTicketProvider.notifier).cancelCurrentTicket();

        expect(cartNotifier.state.items, isEmpty);
      },
    );

    test(
      'deleteTicket removes it from the service and the loaded list',
      () async {
        final service = _FakeHeldTicketService(
          ApiService(),
          _FakeCartService(),
        );
        final ticket = HeldOrder(id: 9, status: 'open');
        service.store['9'] = ticket.toJson();

        final container = ProviderContainer(
          overrides: [
            cartServiceProvider.overrideWithValue(_FakeCartService()),
            heldTicketServiceProvider.overrideWithValue(service),
          ],
        );
        addTearDown(container.dispose);

        await container.read(heldTicketProvider.notifier).loadHeldTickets();
        expect(container.read(heldTicketProvider).tickets, isNotEmpty);

        await container.read(heldTicketProvider.notifier).deleteTicket(ticket);

        expect(service.store.containsKey('9'), isFalse);
        expect(container.read(heldTicketProvider).tickets, isEmpty);
      },
    );
  });
}
