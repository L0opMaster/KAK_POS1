import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// waiting_number_service.dart` — PARTIAL PORT. Source's 529-line file is
/// really two features sharing one class: (1) a local 1-100 waiting-number
/// pool (`issueNumber`/`releaseNumber`) plus an order-id<->number binding
/// (`bindToOrder`/`getNumberForOrder`/`completeOrder`) that the core cart
/// hold/resume flow genuinely depends on — ALL of that is ported,
/// byte-identical. (2) A separate "waiting tickets queue board" feature
/// (`getWaitingTickets`/`saveWaitingTicket`/`upsertWaitingTicket`/
/// `updateWaitingTicketStatus`/`markTicketReady`/`completeWaitingTicket`/
/// `resetAllWaitingNumbers`, and the `WaitingTicket` model/
/// `waitingTicketsProvider` in `[OLD/SOURCE]`'s `cart_provider.dart`) is a
/// customer-facing queue-number display feature layered on top — NOT
/// needed for a cashier to hold/resume a ticket on a phone, and not
/// ported. See DAY_09.md section 12 for the full boundary.
///
/// OFFLINE — everything here is SharedPreferences-only, no network call,
/// same as source.
class WaitingNumberService {
  static const int minNumber = 1;
  static const int maxNumber = 100;

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
