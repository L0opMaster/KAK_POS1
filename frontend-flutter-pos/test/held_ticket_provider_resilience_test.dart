import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
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

class FailingHeldTicketService extends HeldTicketService {
  FailingHeldTicketService()
      : super(
          ApiService(),
          InMemoryCartService(),
        );

  @override
  Future<List<Map<String, dynamic>>> fetchHeldTickets() async {
    throw Exception('fetch failed');
  }

  @override
  Future<Map<String, dynamic>?> holdTicket(
      {required Map<String, dynamic> ticketData}) async {
    throw Exception('hold failed');
  }

  @override
  Future<bool> releaseTicket({required String ticketId}) async {
    throw Exception('release failed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('held ticket notifier records errors instead of crashing', () async {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        cartServiceProvider.overrideWithValue(InMemoryCartService()),
        heldTicketServiceProvider.overrideWithValue(FailingHeldTicketService()),
      ],
    );
    addTearDown(container.dispose);

    final HeldTicketNotifier notifier =
        container.read(heldTicketProvider.notifier);

    await notifier.loadHeldTickets();
    expect(container.read(heldTicketProvider).error, isNotNull);

    await notifier.holdCurrentCart(<CartItem>[CartItem.sample()]);
    expect(container.read(heldTicketProvider).error, isNotNull);
  });
}
