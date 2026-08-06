import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../models/cart_models.dart';

/// Abstract service for cart operations in POS.
/// Extend this class to provide concrete implementations.
///
/// Consider returning a Result/Either type for error handling.
abstract class CartService {
  /// Returns the list of items in the cart.
  Future<List<CartItem>> getCartItems();

  /// Saves the provided list of cart items.
  Future<void> saveCartItems(List<CartItem> items);

  /// Clears all items from the cart.
  Future<void> clearCart();

  /// Removes a single item from the cart by ID.
  Future<void> removeCartItem(String id);
}

// ══ ONLINE (with a small OFFLINE cache) ═══════════════════════════════════
/// Concrete implementation of CartService using API calls.
/// Talks to the backend `/api/carts` endpoints via [ApiService]. Selected
/// when `AppConfig.useApiCartService == true` (see the SWITCH POINT
/// provider at the bottom of this file). Used by
/// features/pos/providers/cart_provider.dart's CartNotifier.
///
/// It also keeps one small OFFLINE piece of state: the server-assigned
/// cart id is cached in SharedPreferences (key `_prefsCartIdKey`) purely so
/// the app doesn't create a brand-new backend cart on every app restart —
/// the actual cart *contents* still live on the server, not on-device.
class ApiCartService extends CartService {
  static const _prefsCartIdKey = 'api_cart_id';

  ApiCartService(this._api, [SharedPreferences? prefs]) : _prefs = prefs;

  final ApiService _api;
  SharedPreferences? _prefs;
  int? _cartId;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Ensure we have a cart on the server and return its id.
  Future<int> _getOrCreateCart() async {
    if (_cartId != null) return _cartId!;
    final prefs = await _getPrefs();
    _cartId = prefs.getInt(_prefsCartIdKey);
    if (_cartId != null) return _cartId!;

    // create a new cart with a dummy customer (0) for now
    final data = await _api.post<Map<String, dynamic>>(
      '/api/carts',
      data: {'customerId': 0},
    );
    _cartId = (data['id'] as num).toInt();
    await prefs.setInt(_prefsCartIdKey, _cartId!);
    return _cartId!;
  }

  @override
  Future<List<CartItem>> getCartItems() async {
    final id = await _getOrCreateCart();
    final response = await _api.get<Map<String, dynamic>>('/api/carts/$id');
    final items = (response['items'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return items;
  }

  @override
  Future<void> saveCartItems(List<CartItem> items) async {
    // First delete the existing cart so we start fresh
    // (capture the id before clearCart resets it)
    final existingId = await _getOrCreateCart();
    await _api.delete<void>('/api/carts/$existingId');
    // Remove cached id so _getOrCreateCart will create a new cart
    final prefs = await _getPrefs();
    await prefs.remove(_prefsCartIdKey);
    _cartId = null;
    // Create a new cart and add items
    final newId = await _getOrCreateCart();
    for (final item in items) {
      await _api.post<void>(
        '/api/carts/$newId/items',
        data: item.toApiJson(),
      );
    }
  }

  @override
  Future<void> clearCart() async {
    final id = await _getOrCreateCart();
    await _api.delete<void>('/api/carts/$id');
    // remove stored id so a new cart will be created next time
    final prefs = await _getPrefs();
    await prefs.remove(_prefsCartIdKey);
    _cartId = null;
  }

  @override
  Future<void> removeCartItem(String id) async {
    final cartId = await _getOrCreateCart();
    await _api.delete<void>('/api/carts/$cartId/items/$id');
  }
}

// ══ OFFLINE ════════════════════════════════════════════════════════════
/// Local implementation using SharedPreferences for persistence.
/// The entire cart (list of CartItem, JSON-encoded) lives on-device under
/// key `_prefsKey` ('cart_items') — no network calls at all. Selected when
/// `AppConfig.useApiCartService == false` (the default), i.e. normal
/// day-to-day POS operation before the sale is finalized.
class LocalCartService extends CartService {
  static const _prefsKey = 'cart_items';

  LocalCartService();

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<CartItem>> getCartItems() async {
    final prefs = await _getPrefs();
    final str = prefs.getString(_prefsKey);
    if (str == null) return [];
    final List data = jsonDecode(str) as List;
    return data
        .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> saveCartItems(List<CartItem> items) async {
    final prefs = await _getPrefs();
    final str = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, str);
  }

  @override
  Future<void> clearCart() async {
    final prefs = await _getPrefs();
    await prefs.remove(_prefsKey);
  }

  @override
  Future<void> removeCartItem(String id) async {
    final items = await getCartItems();
    final newItems = items.where((i) => i.id != id).toList();
    await saveCartItems(newItems);
  }
}

// ══ SWITCH POINT ═══════════════════════════════════════════════════════
/// Provider for CartService.
/// Chooses between a local (`LocalCartService`, OFFLINE) or network-backed
/// (`ApiCartService`, ONLINE) implementation based on the
/// `AppConfig.useApiCartService` configuration flag. CartNotifier (in
/// cart_provider.dart) only ever calls the abstract CartService methods, so
/// it doesn't need to know which side of the switch it's on.
final Provider<CartService> cartServiceProvider =
    Provider<CartService>((final ref) {
  if (AppConfig.useApiCartService) {
    // -> ONLINE
    final api = ref.watch(apiServiceProvider);
    return ApiCartService(api);
  }
  // -> OFFLINE
  return LocalCartService();
});

// For testing, create a FakeCartService or MockCartService.
// Example:
// class FakeCartService extends CartService {
//   @override
//   Future<List<CartItem>> getCartItems() async => [];
//   // Implement other methods for testing.
// }
