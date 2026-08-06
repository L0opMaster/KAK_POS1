import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import 'cart_service.dart';

/// Abstract service for held ticket operations in POS.
/// Extend this class to provide concrete implementations.
///
/// Consider returning a Result/Either type for error handling.
abstract class HeldTicketService {
  static const String endpoint = '/api/pos/open-tickets';

  /// API service dependency (may be unused by local impls)
  final ApiService api;

  /// Cart service dependency (unused by default but kept for symmetry)
  final CartService cartService;

  HeldTicketService(final ApiService api, final CartService cartService)
      : api = api,
        cartService = cartService;

  /// Fetch held tickets (raw JSON maps)
  Future<List<Map<String, dynamic>>> fetchHeldTickets();

  /// Hold a ticket. Returns the created/updated ticket (including its
  /// backend `id`) on success, or null on failure.
  Future<Map<String, dynamic>?> holdTicket(
      {required final Map<String, dynamic> ticketData});

  /// Release a held ticket
  Future<bool> releaseTicket({required final String ticketId});
}

// ══ OFFLINE ════════════════════════════════════════════════════════════
/// In-memory implementation with SharedPreferences persistence.
/// Used when sync is disabled or in tests. Held tickets are kept in the
/// in-memory `_store` map and mirrored to SharedPreferences under key
/// `_prefsKey` ('held_tickets_local') on every write, and reloaded from
/// there on construction (`_loadFromPrefs`) — no network calls at all.
/// Selected when `AppConfig.enableHeldTicketSync == false`.
class LocalHeldTicketService extends HeldTicketService {
  static const String _prefsKey = 'held_tickets_local';

  final Map<String, Map<String, dynamic>> _store = {};
  int _nextId = 1;

  LocalHeldTicketService(super.api, super.cartService) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefsKey);
      if (jsonStr != null) {
        final List<dynamic> list = json.decode(jsonStr) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final id = map['id']?.toString() ?? '${_nextId++}';
          _store[id] = map;
        }
        // update _nextId to be higher than any stored id
        for (final key in _store.keys) {
          final parsed = int.tryParse(key);
          if (parsed != null && parsed >= _nextId) {
            _nextId = parsed + 1;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _store.values.toList();
      await prefs.setString(_prefsKey, json.encode(list));
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> fetchHeldTickets() async {
    return _store.values.toList();
  }

  @override
  Future<Map<String, dynamic>?> holdTicket(
      {required Map<String, dynamic> ticketData}) async {
    final providedId = ticketData['id']?.toString();
    if (providedId != null && _store.containsKey(providedId)) {
      final copy = Map<String, dynamic>.from(ticketData);
      copy['id'] = providedId;
      _store[providedId] = copy;
      await _saveToPrefs();
      return copy;
    }

    final id = (_nextId++).toString();
    final copy = Map<String, dynamic>.from(ticketData);
    copy['id'] = id;
    _store[id] = copy;
    await _saveToPrefs();
    return copy;
  }

  @override
  Future<bool> releaseTicket({required String ticketId}) async {
    _store.remove(ticketId);
    await _saveToPrefs();
    return true;
  }
}

// ══ ONLINE ═════════════════════════════════════════════════════════════
/// Network-backed implementation that calls the backend REST API
/// (`HeldTicketService.endpoint` = '/api/pos/open-tickets') via
/// [ApiService]. No local persistence — every read/write round-trips to
/// the server. Selected when `AppConfig.enableHeldTicketSync == true`.
class ApiHeldTicketService extends HeldTicketService {
  ApiHeldTicketService(super.api, super.cartService);

  @override
  Future<List<Map<String, dynamic>>> fetchHeldTickets() async {
    final resp = await api.get<List<dynamic>>(HeldTicketService.endpoint);
    return resp.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> holdTicket(
      {required Map<String, dynamic> ticketData}) async {
    return api.post<Map<String, dynamic>>(
      HeldTicketService.endpoint,
      data: ticketData,
    );
  }

  @override
  Future<bool> releaseTicket({required String ticketId}) async {
    await api.delete<void>('${HeldTicketService.endpoint}/$ticketId');
    return true;
  }
}

// ══ SWITCH POINT ═══════════════════════════════════════════════════════
/// Provider for HeldTicketService.
/// Selects the network (ONLINE) or local (OFFLINE) implementation via the
/// `AppConfig.enableHeldTicketSync` config flag. Consumers (e.g. the held
/// tickets / open tickets screens) just `ref.read(heldTicketServiceProvider)`
/// and call the abstract HeldTicketService API.
final Provider<HeldTicketService> heldTicketServiceProvider =
    Provider<HeldTicketService>((final ref) {
  final ApiService api = ref.read(apiServiceProvider);
  final CartService cartService = ref.read(cartServiceProvider);
  if (AppConfig.enableHeldTicketSync) {
    // -> ONLINE
    return ApiHeldTicketService(api, cartService);
  }
  // -> OFFLINE
  return LocalHeldTicketService(api, cartService);
});
