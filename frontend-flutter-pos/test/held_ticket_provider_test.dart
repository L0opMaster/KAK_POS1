import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/held_ticket_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_selection_provider.dart';

// trivial fake cart service for tests
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

// We can use the built-in LocalHeldTicketService directly; it behaves just
// like the earlier custom in-memory implementation.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // provide a fake shared preferences instance for any code that accesses it
  SharedPreferences.setMockInitialValues({});

  test('held ticket notifier can hold and restore', () async {
    final overrides = [
      cartProvider.overrideWith((ref) => CartNotifier(FakeCartService(), ref)),
      heldTicketServiceProvider.overrideWith(
          (ref) => LocalHeldTicketService(ApiService(), FakeCartService())),
      tableSelectionProvider
          .overrideWith((ref) => TableSelectionNotifier.withValue(null)),
    ];
    final anotherContainer = ProviderContainer(overrides: overrides);
    addTearDown(anotherContainer.dispose);

    // add an item to the cart
    final prod = Product.sample();
    final item = CartItem(
      id: 'id1',
      product: prod,
      qty: 1,
      addedAt: DateTime.now().millisecondsSinceEpoch,
    );
    anotherContainer.read(cartProvider.notifier).addItem(item);
    expect(anotherContainer.read(cartProvider).items, hasLength(1));

    // hold the current cart
    await anotherContainer
        .read(heldTicketProvider.notifier)
        .holdCurrentCart(anotherContainer.read(cartProvider).items);
    // cart should be cleared after hold (provider automatically clears?)
    expect(anotherContainer.read(cartProvider).items, isEmpty);

    // held tickets list should contain one ticket
    final tickets = anotherContainer.read(heldTicketProvider).tickets;
    expect(tickets, hasLength(1));

    // restore the ticket
    final ticket = tickets.first;
    await anotherContainer
        .read(heldTicketProvider.notifier)
        .restoreTicket(ticket);

    // cart should now have the item again
    expect(anotherContainer.read(cartProvider).items, hasLength(1));
    expect(anotherContainer.read(cartProvider).items.first.product.id, prod.id);
  });

  test('HeldOrder.fromJson handles string id', () {
    final map = {'id': '42', 'status': 'open', 'cart': []};
    final order = HeldOrder.fromJson(map);
    expect(order.id, 42);
  });

  test('deleteTicket removes entry from list', () async {
    final overrides = [
      cartProvider.overrideWith((ref) => CartNotifier(FakeCartService(), ref)),
      heldTicketServiceProvider.overrideWith(
          (ref) => LocalHeldTicketService(ApiService(), FakeCartService())),
      tableSelectionProvider
          .overrideWith((ref) => TableSelectionNotifier.withValue(null)),
    ];
    final anotherContainer = ProviderContainer(overrides: overrides);
    addTearDown(anotherContainer.dispose);

    // add a ticket manually to service store
    final service = anotherContainer.read(heldTicketServiceProvider)
        as LocalHeldTicketService;
    await service.holdTicket(ticketData: {'status': 'open', 'cart': []});

    // load into notifier
    await anotherContainer.read(heldTicketProvider.notifier).loadHeldTickets();
    expect(anotherContainer.read(heldTicketProvider).tickets, hasLength(1));

    // delete via notifier
    final ticket = anotherContainer.read(heldTicketProvider).tickets.first;
    await anotherContainer
        .read(heldTicketProvider.notifier)
        .deleteTicket(ticket);
    expect(anotherContainer.read(heldTicketProvider).tickets, isEmpty);
  });
}
