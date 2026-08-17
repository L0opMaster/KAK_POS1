import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// waiting_number_service.dart`. Source's file is really two features
/// sharing one class: (1) a local 1-100 waiting-number pool
/// (`issueNumber`/`releaseNumber`) plus an order-id<->number binding
/// (`bindToOrder`/`getNumberForOrder`/`completeOrder`) that the core cart
/// hold/resume flow genuinely depends on — ALL of that is ported,
/// byte-identical, and MUST NOT be renamed/removed (see
/// `cart_provider.dart`'s `ensureWaitingNumber()`, `held_tickets_screen
/// .dart`, `cart_totals.dart`). (2) A "waiting tickets queue board" feature
/// (`getWaitingTickets`/`saveWaitingTicket`/`upsertWaitingTicket`/
/// `updateWaitingTicketStatus`/`markTicketReady`/`completeWaitingTicket`/
/// `resetAllWaitingNumbers`, backing `WaitingTicket` in cart_models.dart
/// and `waitingTicketsProvider` in waiting_ticket_provider.dart) — a
/// customer-facing queue-number display feature, COPY/ADAPT NEARLY
/// EXACTLY from source, added alongside (1) without touching it.
///
/// OFFLINE — everything here is SharedPreferences-only, no network call,
/// same as source.
class WaitingNumberService {
  static const int minNumber = 1;
  static const int maxNumber = 100;

  static const String _waitingTicketsKey = 'waiting_number_tickets';
  static const String _nextNumberKey = 'waiting_number_next';
  static const String _activeNumbersKey = 'waiting_number_active';
  static const String _orderNumberMapKey = 'waiting_number_order_map';

  /// Returns the next available waiting number between 1 and 100. After
  /// reaching 100, the sequence starts checking again from 1. A number
  /// that is still active will not be reused.
  Future<int> issueNumber() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<int> activeNumbers = _readActiveNumbers(prefs);

    if (activeNumbers.length >= maxNumber) {
      throw StateError(
        'All waiting numbers from 1 to 100 are currently being used.',
      );
    }

    final int nextNumber = prefs.getInt(_nextNumberKey) ?? minNumber;

    for (int offset = 0; offset < maxNumber; offset++) {
      final int candidate =
          ((nextNumber - minNumber + offset) % maxNumber) + minNumber;

      if (activeNumbers.contains(candidate)) {
        continue;
      }

      activeNumbers.add(candidate);
      final int followingNumber =
          candidate >= maxNumber ? minNumber : candidate + 1;

      await prefs.setInt(_nextNumberKey, followingNumber);
      await _saveActiveNumbers(prefs, activeNumbers);

      return candidate;
    }

    throw StateError('No waiting number is currently available.');
  }

  /// Releases a waiting number so another customer can use it.
  Future<void> releaseNumber(int waitingNumber) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<int> activeNumbers = _readActiveNumbers(prefs);
    activeNumbers.remove(waitingNumber);
    await _saveActiveNumbers(prefs, activeNumbers);
  }

  /// Connects a waiting number to a backend order or sale ID.
  Future<void> bindToOrder({
    required int orderId,
    required int waitingNumber,
  }) async {
    _validateWaitingNumber(waitingNumber);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> orderMap = _readOrderMap(prefs);
    orderMap[orderId.toString()] = waitingNumber;
    await prefs.setString(_orderNumberMapKey, jsonEncode(orderMap));
  }

  /// Returns the waiting number connected to an order ID.
  Future<int?> getNumberForOrder(int orderId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> orderMap = _readOrderMap(prefs);
    final dynamic rawNumber = orderMap[orderId.toString()];
    if (rawNumber == null) return null;
    if (rawNumber is int) return rawNumber;
    return int.tryParse(rawNumber.toString());
  }

  /// Completes an order using its backend order ID — removes the order
  /// mapping and releases its waiting number.
  Future<void> completeOrder(int orderId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> orderMap = _readOrderMap(prefs);
    final dynamic rawNumber = orderMap.remove(orderId.toString());
    await prefs.setString(_orderNumberMapKey, jsonEncode(orderMap));
    if (rawNumber == null) return;
    final int? waitingNumber =
        rawNumber is int ? rawNumber : int.tryParse(rawNumber.toString());
    if (waitingNumber != null) {
      await releaseNumber(waitingNumber);
    }
  }

  /// Returns every locally stored waiting ticket.
  Future<List<WaitingTicket>> getWaitingTickets() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? rawTickets = prefs.getString(_waitingTicketsKey);

    if (rawTickets == null || rawTickets.isEmpty) {
      return <WaitingTicket>[];
    }

    try {
      final dynamic decoded = jsonDecode(rawTickets);

      if (decoded is! List<dynamic>) {
        return <WaitingTicket>[];
      }

      final List<WaitingTicket> tickets = decoded
          .whereType<Map>()
          .map(
            (Map<dynamic, dynamic> item) =>
                WaitingTicket.fromJson(Map<String, dynamic>.from(item)),
          )
          .where(
            (WaitingTicket ticket) =>
                ticket.waitingNumber >= minNumber &&
                ticket.waitingNumber <= maxNumber,
          )
          .toList();

      tickets.sort((WaitingTicket first, WaitingTicket second) {
        final DateTime? firstDate = DateTime.tryParse(first.createdAt);
        final DateTime? secondDate = DateTime.tryParse(second.createdAt);

        if (firstDate != null && secondDate != null) {
          return firstDate.compareTo(secondDate);
        }

        return first.waitingNumber.compareTo(second.waitingNumber);
      });

      return tickets;
    } catch (_) {
      return <WaitingTicket>[];
    }
  }

  /// Creates a new waiting ticket or updates the ticket with the same
  /// number. This is the method used by `CartTotals` and `PaymentScreen`.
  Future<WaitingTicket> saveWaitingTicket({
    required int waitingNumber,
    required List<CartItem> items,
    required OrderMode orderMode,
    required WaitingTicketStatus status,
    required double total,
    int? orderId,
  }) async {
    _validateWaitingNumber(waitingNumber);

    final List<WaitingTicket> tickets = await getWaitingTickets();

    final int existingIndex = tickets.indexWhere(
      (WaitingTicket ticket) => ticket.waitingNumber == waitingNumber,
    );

    if (existingIndex >= 0) {
      final WaitingTicket current = tickets[existingIndex];

      final WaitingTicket updated = current.copyWith(
        orderId: orderId,
        waitingNumber: waitingNumber,
        items: List<CartItem>.from(items),
        orderMode: orderMode,
        status: status,
        total: total,
      );

      tickets[existingIndex] = updated;

      await _saveWaitingTickets(tickets);

      if (orderId != null) {
        await bindToOrder(orderId: orderId, waitingNumber: waitingNumber);
      }

      return updated;
    }

    final WaitingTicket ticket = WaitingTicket(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      orderId: orderId,
      waitingNumber: waitingNumber,
      items: List<CartItem>.from(items),
      orderMode: orderMode,
      status: status,
      total: total,
      createdAt: DateTime.now().toIso8601String(),
    );

    tickets.add(ticket);

    await _saveWaitingTickets(tickets);

    if (orderId != null) {
      await bindToOrder(orderId: orderId, waitingNumber: waitingNumber);
    }

    return ticket;
  }

  /// Compatibility method for code that uses `upsertWaitingTicket`.
  Future<WaitingTicket> upsertWaitingTicket({
    required int waitingNumber,
    required List<CartItem> items,
    required OrderMode orderMode,
    required WaitingTicketStatus status,
    required double total,
    int? orderId,
  }) {
    return saveWaitingTicket(
      waitingNumber: waitingNumber,
      items: items,
      orderMode: orderMode,
      status: status,
      total: total,
      orderId: orderId,
    );
  }

  /// Updates the status of a waiting ticket.
  Future<void> updateWaitingTicketStatus({
    required String ticketId,
    required WaitingTicketStatus status,
  }) async {
    final List<WaitingTicket> tickets = await getWaitingTickets();

    final int index = tickets.indexWhere(
      (WaitingTicket ticket) => ticket.id == ticketId,
    );

    if (index < 0) {
      return;
    }

    tickets[index] = tickets[index].copyWith(status: status);

    await _saveWaitingTickets(tickets);
  }

  /// Marks a waiting ticket as ready. Used by the waiting-tickets queue
  /// board screen.
  Future<void> markTicketReady(String ticketId) {
    return updateWaitingTicketStatus(
      ticketId: ticketId,
      status: WaitingTicketStatus.ready,
    );
  }

  /// Removes a ticket after the customer collects the order. Its waiting
  /// number is then made available for another customer.
  Future<void> completeWaitingTicket(String ticketId) async {
    final List<WaitingTicket> tickets = await getWaitingTickets();

    final int index = tickets.indexWhere(
      (WaitingTicket ticket) => ticket.id == ticketId,
    );

    if (index < 0) {
      return;
    }

    final WaitingTicket completedTicket = tickets[index];

    tickets.removeAt(index);

    await _saveWaitingTickets(tickets);

    if (completedTicket.orderId != null) {
      await _removeOrderMapping(completedTicket.orderId!);
    }

    await releaseNumber(completedTicket.waitingNumber);
  }

  /// Deletes all waiting tickets and resets waiting numbers. Use this only
  /// for testing or an administrator reset.
  Future<void> resetAllWaitingNumbers() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.remove(_waitingTicketsKey);
    await prefs.remove(_activeNumbersKey);
    await prefs.remove(_orderNumberMapKey);

    await prefs.setInt(_nextNumberKey, minNumber);
  }

  Future<void> _saveWaitingTickets(List<WaitingTicket> tickets) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> jsonTickets =
        tickets.map((WaitingTicket ticket) => ticket.toJson()).toList();

    await prefs.setString(_waitingTicketsKey, jsonEncode(jsonTickets));
  }

  Future<void> _removeOrderMapping(int orderId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> orderMap = _readOrderMap(prefs);
    orderMap.remove(orderId.toString());
    await prefs.setString(_orderNumberMapKey, jsonEncode(orderMap));
  }

  Set<int> _readActiveNumbers(SharedPreferences prefs) {
    final List<String> storedNumbers =
        prefs.getStringList(_activeNumbersKey) ?? <String>[];
    return storedNumbers
        .map(int.tryParse)
        .whereType<int>()
        .where((number) => number >= minNumber && number <= maxNumber)
        .toSet();
  }

  Future<void> _saveActiveNumbers(
      SharedPreferences prefs, Set<int> numbers) async {
    final List<int> sortedNumbers = numbers.toList()..sort();
    await prefs.setStringList(
      _activeNumbersKey,
      sortedNumbers.map((number) => number.toString()).toList(),
    );
  }

  Map<String, dynamic> _readOrderMap(SharedPreferences prefs) {
    final String? rawMap = prefs.getString(_orderNumberMapKey);
    if (rawMap == null || rawMap.isEmpty) return <String, dynamic>{};
    try {
      final dynamic decoded = jsonDecode(rawMap);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  void _validateWaitingNumber(int waitingNumber) {
    if (waitingNumber < minNumber || waitingNumber > maxNumber) {
      throw ArgumentError.value(
        waitingNumber,
        'waitingNumber',
        'Waiting number must be between $minNumber and $maxNumber.',
      );
    }
  }
}
