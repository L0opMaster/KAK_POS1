import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/held_ticket_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';

class InMemoryCartService extends CartService {
  List<CartItem> _items = <CartItem>[];

  @override
  Future<void> clearCart() async {
    _items = <CartItem>[];
  }

  @override
  Future<List<CartItem>> getCartItems() async => _items;

  @override
  Future<void> removeCartItem(String id) async {
    _items = _items.where((CartItem item) => item.id != id).toList();
  }

  @override
  Future<void> saveCartItems(List<CartItem> items) async {
    _items = List<CartItem>.from(items);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cashier golden flow: add -> hold -> reopen -> charge', () async {
    final InMemoryCartService cartService = InMemoryCartService();
    final LocalHeldTicketService heldService =
        LocalHeldTicketService(ApiService(), cartService);
    final Product product = Product.sample();

    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        cartServiceProvider.overrideWithValue(cartService),
        heldTicketServiceProvider.overrideWithValue(heldService),
      ],
    );
    addTearDown(container.dispose);

    final CartNotifier cartNotifier = container.read(cartProvider.notifier);
    final HeldTicketNotifier heldNotifier =
        container.read(heldTicketProvider.notifier);

    await cartNotifier.addItemFromProduct(product);
    expect(container.read(cartProvider).items.length, 1);

    await heldNotifier.holdCurrentCart(container.read(cartProvider).items);
    expect(container.read(heldTicketProvider).tickets.length, 1);

    await cartNotifier.clear();
    expect(container.read(cartProvider).items, isEmpty);

    heldNotifier.restoreTicket(container.read(heldTicketProvider).tickets.first);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(container.read(cartProvider).items.length, 1);

    await cartNotifier.clear();
    expect(container.read(cartProvider).items, isEmpty);
  });
}
