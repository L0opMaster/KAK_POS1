import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cart_models.dart';
import '../models/table_models.dart';
import 'bill_print_status_provider.dart';
import 'cart_provider.dart';
import '../services/held_ticket_service.dart';
import 'table_selection_provider.dart';

/// State for the held ticket list and selection.
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

  factory HeldTicketState.initial() => HeldTicketState(
        loading: false,
        tickets: [],
        error: null,
        selected: null,
      );

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

/// Notifier that manipulates the held ticket data.
class HeldTicketNotifier extends StateNotifier<HeldTicketState> {
  final HeldTicketService service;
  final Ref ref;

  HeldTicketNotifier(this.service, this.ref) : super(HeldTicketState.initial());

  /// Status used to mark a ticket as "checked out" into someone's active
  /// cart (see [restoreTicket]) — an open status recognized by the backend
  /// (`HeldTicketService.OPEN_STATUSES`), so the ticket stays updatable via
  /// its id, but hidden from [loadHeldTickets] on every terminal until it's
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
          .map((e) => HeldOrder.fromJson(e as Map<String, dynamic>))
          .where((t) => t.status.toLowerCase() != _inProgressStatus)
          .toList();
      state = state.copyWith(loading: false, tickets: tickets);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  /// Hold the current cart items, creating a ticket entry — or, when
  /// [ticketId] is given (resuming an existing ticket), updating that same
  /// ticket in place so its id/code/number never change across a
  /// resume-then-hold cycle. Returns the ticket's backend id (used by
  /// callers to bind the waiting number to it via
  /// `WaitingNumberService.bindToOrder`), or null on failure.
  Future<int?> holdCurrentCart(List<CartItem> items, {int? ticketId}) async {
    try {
      final data = {
        if (ticketId != null) 'id': ticketId.toString(),
        'status': 'open',
        'cart': items.map((e) => e.toJson()).toList(),
        'createdAt': DateTime.now().toIso8601String(),
      };
      // if a table is selected, include its info in the held ticket
      final table = ref.read(tableSelectionProvider);
      if (table != null) {
        data['tableName'] = table.tableNumber;
      }
      final created = await service.holdTicket(ticketData: data);
      await loadHeldTickets();
      // the sale is now held, not active — clear the working cart
      await ref.read(cartProvider.notifier).clear();
      // once a ticket is held, clear the current table selection so the table
      // appears free for new orders
      ref.read(tableSelectionProvider.notifier).select(null);
      final rawId = created?['id'];
      return rawId == null ? null : int.tryParse(rawId.toString());
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Restore selected ticket into the active cart. The ticket is kept (not
  /// voided) — it's marked [_inProgressStatus] so it drops out of the held
  /// list everywhere until the cashier either re-holds it (updates it in
  /// place, see [holdCurrentCart]), pays it (see cleanup in
  /// `payment_screen.dart`), or abandons the resume ([cancelResume]).
  Future<void> restoreTicket(HeldOrder ticket) async {
    try {
      if (ticket.cartItems == null) {
        // Nothing to load into the cart — leave the ticket as-is rather
        // than hiding it as in-progress with no way back to it.
        state = state.copyWith(selected: ticket);
        return;
      }

      // Reuse the waiting number originally bound to this ticket (set
      // when it was first held via holdCurrentCart) instead of letting
      // the cart issue a new one — otherwise resuming an old ticket
      // always shows a higher number than it was held with.
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

      // Mirror the ticket's table (or lack of one) into the current
      // selection too — restoreItems() above only updates cart.tableId
      // (used at checkout), this keeps the cart panel's table chip in sync
      // instead of showing a stale table left over from a previous ticket.
      ref.read(tableSelectionProvider.notifier).select(ticket.table);
      state = state.copyWith(selected: ticket);
      try {
        await service.holdTicket(ticketData: {
          'id': ticket.id.toString(),
          'status': _inProgressStatus,
          'cart': ticket.cartItems!.map((e) => e.toJson()).toList(),
          if (ticket.table != null) 'tableName': ticket.table!.tableNumber,
        });
      } catch (e) {
        // Non-fatal: the ticket loaded into the cart regardless. Worst case
        // it's still visible (and editable) in the held list until the
        // cashier re-holds or pays it.
      }
      await loadHeldTickets();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Abandons an in-progress resume (e.g. the cashier hit "Clear" instead
  /// of re-holding or charging): puts the ticket back on hold — unchanged —
  /// so it reappears in the held list, then clears the working cart. Safe
  /// to call even when the cart wasn't resumed from a ticket.
  Future<void> cancelResume() async {
    final cartState = ref.read(cartProvider);
    final ticketId = cartState.heldTicketId;
    if (ticketId != null) {
      try {
        await service.holdTicket(ticketData: {
          'id': ticketId.toString(),
          'status': 'open',
          'cart': cartState.items.map((e) => e.toJson()).toList(),
        });
        await loadHeldTickets();
      } catch (e) {
        state = state.copyWith(error: e.toString());
      }
    }
    await ref.read(cartProvider.notifier).clear();
  }

  /// Cancels the ticket the active cart was resumed from (if any) — voids
  /// it on the backend (see HeldTicketService.softDelete, which frees its
  /// table if no other open ticket still holds it) and clears the working
  /// cart. Unlike [cancelResume], this permanently cancels the order rather
  /// than putting it back on hold. Safe to call even when the cart wasn't
  /// resumed from a ticket (just clears).
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

  /// Releases a held ticket by id once it's been converted into a paid
  /// sale (see `payment_screen.dart`), so it doesn't linger as a phantom
  /// in-progress entry that can never be resumed again.
  ///
  /// Returns `true` on success, `false` (after logging) if the backend
  /// call failed. The sale itself already succeeded either way — a failure
  /// here is non-fatal to payment — but it used to be swallowed completely
  /// silently (no log, no return value, fire-and-forget from the caller),
  /// which meant a paid ticket could linger forever in the held list with
  /// zero indication to staff or in logs of why. Callers should await this
  /// and warn on `false` instead of treating it as fire-and-forget.
  Future<bool> releaseTicketById(int ticketId) async {
    try {
      await service.releaseTicket(ticketId: ticketId.toString());
      await ref.read(billPrintStatusProvider.notifier).clear(ticketId);
      return true;
    } catch (e) {
      debugPrint('Failed to release held ticket #$ticketId after payment: $e');
      return false;
    }
  }

  /// Change the table associated with [ticket].  This will send an update
  /// to the service and refresh the list.
  Future<void> assignTable(HeldOrder ticket, RestaurantTable? table) async {
    try {
      final data = {
        'id': ticket.id.toString(),
        'status': ticket.status,
        'cart': ticket.cartItems?.map((e) => e.toJson()).toList() ?? [],
      };
      if (table != null) {
        data['tableName'] = table.tableNumber;
      }
      await service.holdTicket(ticketData: data);
      await loadHeldTickets();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider for the held ticket state notifier.
final heldTicketProvider =
    StateNotifierProvider<HeldTicketNotifier, HeldTicketState>((ref) {
  final service = ref.read(heldTicketServiceProvider);
  return HeldTicketNotifier(service, ref);
});
