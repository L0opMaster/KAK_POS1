import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_models.dart';
import 'cart_provider.dart';

/// Backs the waiting-tickets "queue board" screen
/// (`mobile_waiting_tickets_screen.dart`) — a customer-facing-style list of
/// waiting numbers with Ready/Collected actions. Separate from the core
/// waiting-number issuing/hold-resume logic in `waitingNumberServiceProvider`
/// (declared in `cart_provider.dart`, reused here rather than duplicated).
///
/// No auto-refresh/polling — the screen re-fetches manually via
/// `ref.invalidate(waitingTicketsProvider)` after every Ready/Collected
/// action, matching `frontend-flutter-pos`'s `waitingTicketsProvider`.
final FutureProvider<List<WaitingTicket>> waitingTicketsProvider =
    FutureProvider<List<WaitingTicket>>((Ref ref) {
  return ref.watch(waitingNumberServiceProvider).getWaitingTickets();
});
