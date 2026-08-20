// Regression coverage for a reported bug: after successfully paying for a
// held ticket, the ticket kept showing up in the Held Tickets list as if
// nothing had happened. Root cause: `HeldTicketNotifier.releaseTicketById`
// (called from payment_screen.dart on payment success) was fire-and-forget
// (`unawaited`) and its own try/catch swallowed any failure completely
// silently — no log, no return value, nothing surfaced to the cashier or
// to logs. A failed DELETE request (network hiccup, etc.) therefore left a
// fully-paid ticket sitting in the held list forever with zero indication
// of why.
//
// The fix: `releaseTicketById` now returns `bool` (true = actually
// released) and logs on failure, and payment_screen.dart awaits it and
// warns the cashier instead of firing-and-forgetting. These tests lock in
// both halves: the happy path actually removes the ticket, and a backend
// failure is reported as `false` instead of being swallowed.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/held_ticket_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_selection_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/held_ticket_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/waiting_number_service.dart';

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

/// Always fails the release DELETE call — simulates the exact backend/
/// network failure mode that used to vanish without a trace.
class ReleaseFailingHeldTicketService extends HeldTicketService {
  ReleaseFailingHeldTicketService() : super(ApiService(), FakeCartService());

  @override
  Future<List<Map<String, dynamic>>> fetchHeldTickets() async => [];

  @override
  Future<Map<String, dynamic>?> holdTicket(
          {required Map<String, dynamic> ticketData}) async =>
      null;

  @override
  Future<bool> releaseTicket({required String ticketId}) async {
    throw Exception('simulated network failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
      'releaseTicketById actually removes the ticket from the held list on '
      'success (the "paid but still shows up" happy path)', () async {
    final overrides = [
      cartProvider.overrideWith((ref) =>
          CartNotifier(FakeCartService(), WaitingNumberService(), ref)),
      heldTicketServiceProvider.overrideWith(
          (ref) => LocalHeldTicketService(ApiService(), FakeCartService())),
      tableSelectionProvider
          .overrideWith((ref) => TableSelectionNotifier.withValue(null)),
    ];
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    final service =
        container.read(heldTicketServiceProvider) as LocalHeldTicketService;
    await service.holdTicket(ticketData: {'status': 'open', 'cart': []});
    await container.read(heldTicketProvider.notifier).loadHeldTickets();
    final ticket = container.read(heldTicketProvider).tickets.single;

    final released = await container
        .read(heldTicketProvider.notifier)
        .releaseTicketById(ticket.id);

    expect(released, isTrue);
    await container.read(heldTicketProvider.notifier).loadHeldTickets();
    expect(container.read(heldTicketProvider).tickets, isEmpty,
        reason: 'a released ticket must no longer appear in the held list');
  });

  test(
      'releaseTicketById returns false (not a thrown exception) when the '
      'backend call fails, instead of silently swallowing it', () async {
    final overrides = [
      cartProvider.overrideWith((ref) =>
          CartNotifier(FakeCartService(), WaitingNumberService(), ref)),
      heldTicketServiceProvider
          .overrideWith((ref) => ReleaseFailingHeldTicketService()),
      tableSelectionProvider
          .overrideWith((ref) => TableSelectionNotifier.withValue(null)),
    ];
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    final released = await container
        .read(heldTicketProvider.notifier)
        .releaseTicketById(1024);

    expect(released, isFalse,
        reason: 'a failed release must be reported to the caller, not '
            'swallowed as if it succeeded');
  });
}
