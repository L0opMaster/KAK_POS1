import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../models/cart_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// cart_service.dart` — COPY/ADAPT NEARLY EXACTLY.
abstract class CartService {
  Future<List<CartItem>> getCartItems();
  Future<void> saveCartItems(List<CartItem> items);
  Future<void> clearCart();
  Future<void> removeCartItem(String id);
}

/// Concrete implementation of CartService using API calls. Talks to the
/// backend `/api/carts` endpoints via [ApiService]. Selected when
/// `AppConfig.useApiCartService == true`.
class ApiCartService extends CartService {
  static const _prefsCartIdKey = 'api_cart_id';

  ApiCartService(this._api, [SharedPreferences? prefs]) : _prefs = prefs;

  final ApiService _api;
  SharedPreferences? _prefs;
  int? _cartId;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<int> _getOrCreateCart() async {
    if (_cartId != null) return _cartId!;
    final prefs = await _getPrefs();
    _cartId = prefs.getInt(_prefsCartIdKey);
    if (_cartId != null) return _cartId!;

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
    final existingId = await _getOrCreateCart();
    await _api.delete<void>('/api/carts/$existingId');
    final prefs = await _getPrefs();
    await prefs.remove(_prefsCartIdKey);
    _cartId = null;
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

/// Local implementation using SharedPreferences for persistence. No network
/// calls at all. Selected when `AppConfig.useApiCartService == false`.
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

/// Provider for CartService — the actual ONLINE/OFFLINE switch, based on
/// `AppConfig.useApiCartService`.
final Provider<CartService> cartServiceProvider =
    Provider<CartService>((final ref) {
  if (AppConfig.useApiCartService) {
    final api = ref.watch(apiServiceProvider);
    return ApiCartService(api);
  }
  return LocalCartService();
});
