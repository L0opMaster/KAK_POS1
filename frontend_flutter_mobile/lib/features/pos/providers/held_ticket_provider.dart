import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_models.dart';
import 'bill_print_status_provider.dart';
import 'cart_provider.dart';
import '../services/held_ticket_service.dart';
import 'table_selection_provider.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// held_ticket_provider.dart` — PARTIAL PORT. `loadHeldTickets`,
/// `holdCurrentCart`, `restoreTicket`, `cancelResume`, `cancelCurrentTicket`,
/// `deleteTicket`, `releaseTicketById` (added Day 11, now that
/// `payment_screen.dart` has a real caller for it — post-payment cleanup of
/// the ticket the sale was resumed from) are COPY/ADAPT NEARLY EXACTLY.
/// `assignTable` (re-assigning an existing held ticket's table without
/// resuming it first) remains dropped — confirmed unused by source's OWN UI
/// too, not just this port's, so unlike `releaseTicketById` there's no
/// future day expected to need it either.
class HeldTicketState {
  final bool loading;
  final String? error;
  final List<HeldOrder> tickets;
  final HeldOrder? selected;

  HeldTicketState({
    required this.loading,
    this.error,
    required this.tickets,
    this.selected,
  });

  factory HeldTicketState.initial() =>
      HeldTicketState(loading: false, tickets: [], error: null, selected: null);

  HeldTicketState copyWith({
    bool? loading,
    String? error,
    List<HeldOrder>? tickets,
    HeldOrder? selected,
  }) {
    return HeldTicketState(
      loading: loading ?? this.loading,
      error: error ?? this.error,
      tickets: tickets ?? this.tickets,
      selected: selected ?? this.selected,
    );
  }
}

class HeldTicketNotifier extends StateNotifier<HeldTicketState> {
  final HeldTicketService service;
  final Ref ref;

  HeldTicketNotifier(this.service, this.ref) : super(HeldTicketState.initial());

  /// Status used to mark a ticket as "checked out" into someone's active
  /// cart (see [restoreTicket]) — hidden from [loadHeldTickets] until it's
  /// either put back on hold ([cancelResume]) or re-held/paid.
  static const String _inProgressStatus = 'in_progress';

  /// Load the held tickets from backend, excluding ones currently checked
  /// out into an active cart (status [_inProgressStatus]) on this or any
  /// other terminal.
  Future<void> loadHeldTickets() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final raw = await service.fetchHeldTickets();
      final tickets = raw
          .map((e) => HeldOrder.fromJson(e))
          .where((t) => t.status.toLowerCase() != _inProgressStatus)
          .toList();
      state = state.copyWith(loading: false, tickets: tickets);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Hold the current cart items, creating a ticket entry — or, when
  /// [ticketId] is given (resuming an existing ticket), updating that same
  /// ticket in place. Returns the ticket's backend id, or null on failure.
  Future<int?> holdCurrentCart(List<CartItem> items, {int? ticketId}) async {
    try {
      final data = {
        if (ticketId != null) 'id': ticketId.toString(),
        'status': 'open',
        'cart': items.map((e) => e.toJson()).toList(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      final table = ref.read(tableSelectionProvider);
      if (table != null) {
        data['tableName'] = table.tableNumber;
      }
      final created = await service.holdTicket(ticketData: data);
      await loadHeldTickets();
      await ref.read(cartProvider.notifier).clear();
      ref.read(tableSelectionProvider.notifier).select(null);
      final rawId = created?['id'];
      return rawId == null ? null : int.tryParse(rawId.toString());
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Restore selected ticket into the active cart. The ticket is kept (not
  /// voided) — marked [_inProgressStatus] so it drops out of the held list
  /// until the cashier either re-holds it, pays it, or abandons the resume
  /// ([cancelResume]).
  Future<void> restoreTicket(HeldOrder ticket) async {
    try {
      if (ticket.cartItems == null) {
        state = state.copyWith(selected: ticket);
        return;
      }

      // Reuse the waiting number originally bound to this ticket instead
      // of letting the cart issue a new one.
      final waitingNumber = await ref
          .read(waitingNumberServiceProvider)
          .getNumberForOrder(ticket.id);
      final cartNotifier = ref.read(cartProvider.notifier);
      await cartNotifier.restoreItems(
        items: ticket.cartItems!,
        waitingNumber: waitingNumber,
        heldTicketId: ticket.id,
        tableId: ticket.table?.id,
      );

      ref.read(tableSelectionProvider.notifier).select(ticket.table);
      state = state.copyWith(selected: ticket);
      try {
        await service.holdTicket(
          ticketData: {
            'id': ticket.id.toString(),
            'status': _inProgressStatus,
            'cart': ticket.cartItems!.map((e) => e.toJson()).toList(),
            if (ticket.table != null) 'tableName': ticket.table!.tableNumber,
          },
        );
      } catch (e) {
        // Non-fatal: the ticket loaded into the cart regardless.
      }
      await loadHeldTickets();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Abandons an in-progress resume (the cashier hit "Clear" instead of
  /// re-holding or charging): puts the ticket back on hold — unchanged —
  /// so it reappears in the held list, then clears the working cart. Safe
  /// to call even when the cart wasn't resumed from a ticket.
  Future<void> cancelResume() async {
    final cartState = ref.read(cartProvider);
    final ticketId = cartState.heldTicketId;
    if (ticketId != null) {
      try {
        await service.holdTicket(
          ticketData: {
            'id': ticketId.toString(),
            'status': 'open',
            'cart': cartState.items.map((e) => e.toJson()).toList(),
          },
        );
        await loadHeldTickets();
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    }
    await ref.read(cartProvider.notifier).clear();
  }

  /// Cancels the ticket the active cart was resumed from (if any) — voids
  /// it on the backend and clears the working cart. Unlike [cancelResume],
  /// this permanently cancels the order rather than putting it back on
  /// hold. Safe to call even when the cart wasn't resumed from a ticket
  /// (just clears).
  Future<void> cancelCurrentTicket() async {
    final ticketId = ref.read(cartProvider).heldTicketId;
    if (ticketId != null) {
      try {
        await service.releaseTicket(ticketId: ticketId.toString());
        await loadHeldTickets();
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    }
    await ref.read(cartProvider.notifier).clear();
  }

  /// Releases a held ticket by id once it's been converted into a paid
  /// sale (see `payment_screen.dart`), so it doesn't linger as a phantom
  /// in-progress entry that can never be resumed again.
  Future<void> releaseTicketById(int ticketId) async {
    try {
      await service.releaseTicket(ticketId: ticketId.toString());
      await ref.read(billPrintStatusProvider.notifier).clear(ticketId);
    } catch (e) {
      // Non-fatal: the sale already succeeded — a leftover held-ticket row
      // is just clutter, not a lost order.
    }
  }

  /// Directly release (delete) a held ticket without restoring it.
  Future<void> deleteTicket(HeldOrder ticket) async {
    try {
      await service.releaseTicket(ticketId: ticket.id.toString());
      await ref.read(billPrintStatusProvider.notifier).clear(ticket.id);
      await loadHeldTickets();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final heldTicketProvider =
    StateNotifierProvider<HeldTicketNotifier, HeldTicketState>((ref) {
      final service = ref.read(heldTicketServiceProvider);
      return HeldTicketNotifier(service, ref);
    });
