import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/held_ticket_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_selection_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCartService extends CartService {
  FakeCartService() : super();

  @override
  Future<void> clearCart() async {}

  @override
  Future<List<CartItem>> getCartItems() async => <CartItem>[];

  @override
  Future<void> removeCartItem(final String id) async {}

  @override
  Future<void> saveCartItems(final List<CartItem> items) async {}
}

/// A tiny service implementation that simply records the last payload it was
/// given when holdTicket is called.
class RecordingHeldTicketService extends HeldTicketService {
  Map<String, dynamic>? lastData;

  RecordingHeldTicketService() : super(ApiService(), FakeCartService());

  @override
  Future<List<Map<String, dynamic>>> fetchHeldTickets() async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> holdTicket(
      {required final Map<String, dynamic> ticketData}) async {
    lastData = ticketData;
    return <String, dynamic>{...ticketData, 'id': ticketData['id'] ?? '1'};
  }

  @override
  Future<bool> releaseTicket({required final String ticketId}) async => true;
}

void main() {
  // shared_preferences plugin must be initialized even though we override
  // the notifier below; some providers still call getInstance during
  // container startup.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  test('holding cart includes selected table when present', () async {
    final List<Override> overrides = <Override>[
      cartProvider.overrideWith((final StateNotifierProviderRef<CartNotifier, CartState> ref) => CartNotifier(FakeCartService(), ref)),
      heldTicketServiceProvider.overrideWith((final ProviderRef<HeldTicketService> ref) => RecordingHeldTicketService()),
      // override the table selection notifier with a pre‑seeded value; use
      // `.overrideWith` since this is a StateNotifierProvider.
      tableSelectionProvider.overrideWith(
        (final StateNotifierProviderRef<TableSelectionNotifier, RestaurantTable?> ref) => TableSelectionNotifier.withValue(RestaurantTable.sample()),
      ),
    ];
    final ProviderContainer anotherContainer = ProviderContainer(overrides: overrides);
    addTearDown(anotherContainer.dispose);

    final List<CartItem> items = <CartItem>[CartItem.sample()];
    await anotherContainer.read(heldTicketProvider.notifier).holdCurrentCart(items);

    final RecordingHeldTicketService service = anotherContainer.read(heldTicketServiceProvider) as RecordingHeldTicketService;
    expect(service.lastData, isNotNull);
    expect(service.lastData!['tableName'], 'A1');
    expect(service.lastData!['cart'], isA<List>());
  });

  test('assignTable updates stored ticket and notifier state', () async {
    // start with a held ticket that already has a table
    final LocalHeldTicketService service = LocalHeldTicketService(ApiService(), FakeCartService());
    await service.holdTicket(ticketData: <String, dynamic>{
      'status': 'open',
      'cart': <CartItem>[],
      'tableName': 'A1',
    });

    final ProviderContainer container = ProviderContainer(overrides: <Override>[
      heldTicketServiceProvider.overrideWith((final ProviderRef<HeldTicketService> ref) => service),
      tableSelectionProvider.overrideWith((final StateNotifierProviderRef<TableSelectionNotifier, RestaurantTable?> ref) => TableSelectionNotifier.withValue(null)),
    ]);
    addTearDown(container.dispose);

    // load existing tickets into notifier
    await container.read(heldTicketProvider.notifier).loadHeldTickets();
    HeldOrder ticket = container.read(heldTicketProvider).tickets.first;
    expect(ticket.table?.displayText, 'Table A1');

    // perform assignment
    final RestaurantTable newTable = RestaurantTable.sample().copyWith(tableNumber: 'B2', displayName: 'Table B2');
    await container.read(heldTicketProvider.notifier).assignTable(ticket, newTable);

    // notifier state should reflect the change
    ticket = container.read(heldTicketProvider).tickets.first;
    expect(ticket.table?.displayText, 'Table B2');

    // underlying service should also have been updated
    final List<Map<String, dynamic>> fetched = await service.fetchHeldTickets();
    expect(fetched.first['tableName'], 'B2');
  });
}
