import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/services/waiting_number_service.dart';

/// Covers the queue-board methods added to `WaitingNumberService`
/// (`getWaitingTickets`/`saveWaitingTicket`/`markTicketReady`/
/// `completeWaitingTicket`) — everything is SharedPreferences-backed, so
/// `SharedPreferences.setMockInitialValues({})` in `setUp` matches the
/// pattern used by `cart_provider_test.dart`/`held_ticket_provider_test
/// .dart`. Does NOT touch/re-test `issueNumber`/`releaseNumber`/
/// `bindToOrder`/`getNumberForOrder`/`completeOrder` — those are exercised
/// elsewhere (e.g. `cart_provider_test.dart`) and are unchanged here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Product product(int id) => Product(
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

  List<CartItem> items() => [
        CartItem(id: 'i1', product: product(1), qty: 2, addedAt: 0),
      ];

  group('WaitingNumberService queue board', () {
    test('getWaitingTickets returns empty list when nothing is stored',
        () async {
      final service = WaitingNumberService();
      expect(await service.getWaitingTickets(), isEmpty);
    });

    test('saveWaitingTicket persists a new ticket, retrievable via '
        'getWaitingTickets', () async {
      final service = WaitingNumberService();

      final saved = await service.saveWaitingTicket(
        waitingNumber: 7,
        items: items(),
        orderMode: OrderMode.takeaway,
        status: WaitingTicketStatus.held,
        total: 10,
      );

      expect(saved.waitingNumber, 7);
      expect(saved.status, WaitingTicketStatus.held);

      final tickets = await service.getWaitingTickets();
      expect(tickets, hasLength(1));
      expect(tickets.single.id, saved.id);
      expect(tickets.single.waitingNumber, 7);
      expect(tickets.single.orderMode, OrderMode.takeaway);
      expect(tickets.single.total, 10);
    });

    test('saveWaitingTicket with an existing waiting number updates that '
        'ticket in place instead of creating a second one', () async {
      final service = WaitingNumberService();

      final first = await service.saveWaitingTicket(
        waitingNumber: 3,
        items: items(),
        orderMode: OrderMode.dineIn,
        status: WaitingTicketStatus.held,
        total: 5,
      );

      final updated = await service.saveWaitingTicket(
        waitingNumber: 3,
        items: items(),
        orderMode: OrderMode.dineIn,
        status: WaitingTicketStatus.paid,
        total: 8,
      );

      expect(updated.id, first.id);

      final tickets = await service.getWaitingTickets();
      expect(tickets, hasLength(1));
      expect(tickets.single.status, WaitingTicketStatus.paid);
      expect(tickets.single.total, 8);
    });

    test('markTicketReady changes the ticket status to ready', () async {
      final service = WaitingNumberService();

      final ticket = await service.saveWaitingTicket(
        waitingNumber: 12,
        items: items(),
        orderMode: OrderMode.delivery,
        status: WaitingTicketStatus.held,
        total: 20,
      );

      await service.markTicketReady(ticket.id);

      final tickets = await service.getWaitingTickets();
      expect(tickets.single.status, WaitingTicketStatus.ready);
    });

    test('completeWaitingTicket removes the ticket and releases its '
        'waiting number back into the pool', () async {
      final service = WaitingNumberService();

      final issued = await service.issueNumber();
      final ticket = await service.saveWaitingTicket(
        waitingNumber: issued,
        items: items(),
        orderMode: OrderMode.takeaway,
        status: WaitingTicketStatus.ready,
        total: 15,
      );

      await service.completeWaitingTicket(ticket.id);

      expect(await service.getWaitingTickets(), isEmpty);

      // If the number weren't released, only maxNumber - 1 more numbers
      // could be issued before the 1-100 pool is exhausted. Issuing a full
      // maxNumber more without a StateError proves the pool had room for
      // all 100, i.e. the completed ticket's number was freed.
      for (var i = 0; i < WaitingNumberService.maxNumber; i++) {
        await service.issueNumber();
      }
    });

    test('completeWaitingTicket with an unknown ticket id is a no-op',
        () async {
      final service = WaitingNumberService();

      await service.saveWaitingTicket(
        waitingNumber: 1,
        items: items(),
        orderMode: OrderMode.dineIn,
        status: WaitingTicketStatus.held,
        total: 1,
      );

      await service.completeWaitingTicket('does-not-exist');

      expect(await service.getWaitingTickets(), hasLength(1));
    });

    test('upsertWaitingTicket behaves as a compatibility alias for '
        'saveWaitingTicket', () async {
      final service = WaitingNumberService();

      final ticket = await service.upsertWaitingTicket(
        waitingNumber: 9,
        items: items(),
        orderMode: OrderMode.dineIn,
        status: WaitingTicketStatus.held,
        total: 4,
      );

      expect(ticket.waitingNumber, 9);
      expect(await service.getWaitingTickets(), hasLength(1));
    });

    test('resetAllWaitingNumbers wipes stored tickets', () async {
      final service = WaitingNumberService();

      await service.saveWaitingTicket(
        waitingNumber: 1,
        items: items(),
        orderMode: OrderMode.dineIn,
        status: WaitingTicketStatus.held,
        total: 1,
      );

      await service.resetAllWaitingNumbers();

      expect(await service.getWaitingTickets(), isEmpty);
    });
  });
}
