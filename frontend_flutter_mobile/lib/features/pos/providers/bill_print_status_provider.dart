import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// bill_print_status_provider.dart` — COPY/ADAPT NEARLY EXACTLY, full file.
///
/// Tracks which held tickets have had their pre-payment bill printed at
/// least once — purely a local UI hint (the "BILL PRINTED" badge on
/// `held_tickets_screen.dart`'s ticket cards), distinct from payment
/// status, which stays authoritative on the backend (`HeldOrder.status`).
/// A ticket marked here is still fully UNPAID — see
/// `ReceiptViewModel.isBill` for the actual UNPAID/PAID distinction on the
/// printed document itself.
///
/// Persisted to SharedPreferences rather than the backend: this is a
/// presentation-only convenience ("has staff already printed a bill for
/// this ticket"), not business data, so it doesn't warrant a backend/DB
/// field. A ticket id is cleared once its ticket is paid or cancelled so
/// entries don't linger forever — though a stale leftover id is harmless,
/// since backend ticket ids are never reused.
class BillPrintStatusNotifier extends StateNotifier<Set<int>> {
  BillPrintStatusNotifier() : super(const <int>{}) {
    _load();
  }

  static const String _key = 'held_ticket_bill_printed_ids';

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_key) ?? const <String>[];
    state = raw.map(int.parse).toSet();
  }

  Future<void> _persist() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      state.map((int id) => id.toString()).toList(),
    );
  }

  /// Marks [ticketId] as having had its bill printed.
  Future<void> markPrinted(int ticketId) async {
    if (state.contains(ticketId)) return;
    state = {...state, ticketId};
    await _persist();
  }

  /// Clears the flag for [ticketId] — called once the ticket is paid or
  /// cancelled, so it doesn't show a stale "BILL PRINTED" badge if that id
  /// were ever reused (it never is, but this keeps stored state tidy).
  Future<void> clear(int ticketId) async {
    if (!state.contains(ticketId)) return;
    state = {...state}..remove(ticketId);
    await _persist();
  }

  bool isPrinted(int ticketId) => state.contains(ticketId);
}

final billPrintStatusProvider =
    StateNotifierProvider<BillPrintStatusNotifier, Set<int>>((ref) {
  return BillPrintStatusNotifier();
});
