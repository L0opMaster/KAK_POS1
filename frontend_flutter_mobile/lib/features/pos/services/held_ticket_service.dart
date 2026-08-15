import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import 'cart_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// held_ticket_service.dart` — COPY/ADAPT NEARLY EXACTLY (full port —
/// small, self-contained, works in raw JSON maps rather than typed
/// models, same as source).
abstract class HeldTicketService {
  static const String endpoint = '/api/pos/open-tickets';

  final ApiService api;
  final CartService cartService;

  HeldTicketService(final ApiService api, final CartService cartService)
      : api = api,
        cartService = cartService;

  Future<List<Map<String, dynamic>>> fetchHeldTickets();

  Future<Map<String, dynamic>?> holdTicket(
      {required final Map<String, dynamic> ticketData});

  Future<bool> releaseTicket({required final String ticketId});
}

/// In-memory implementation with SharedPreferences persistence. Selected
/// when `AppConfig.enableHeldTicketSync == false`.
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

/// Network-backed implementation. Selected when
/// `AppConfig.enableHeldTicketSync == true`.
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

/// SWITCH POINT — `AppConfig.enableHeldTicketSync`.
final Provider<HeldTicketService> heldTicketServiceProvider =
    Provider<HeldTicketService>((final ref) {
  final ApiService api = ref.read(apiServiceProvider);
  final CartService cartService = ref.read(cartServiceProvider);
  if (AppConfig.enableHeldTicketSync) {
    return ApiHeldTicketService(api, cartService);
  }
  return LocalHeldTicketService(api, cartService);
});
