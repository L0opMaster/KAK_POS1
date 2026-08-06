
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_model.dart';
import '../services/cart_service.dart';

enum CartStatus { initial, loading, success, error }

class CartState {
  final Cart? cart;
  final CartStatus status;
  final String? errorMessage;

  CartState({this.cart, this.status = CartStatus.initial, this.errorMessage});

  CartState copyWith({
    Cart? cart,
    CartStatus? status,
    String? errorMessage,
  }) {
    return CartState(
      cart: cart ?? this.cart,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final cartServiceProvider = Provider((ref) => CartService());

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref.watch(cartServiceProvider));
});

class CartNotifier extends StateNotifier<CartState> {
  final CartService _cartService;

  CartNotifier(this._cartService) : super(CartState());

  Future<void> getCart(String cartId) async {
    state = state.copyWith(status: CartStatus.loading);
    try {
      final cart = await _cartService.getCart(cartId);
      state = state.copyWith(cart: cart, status: CartStatus.success);
    } catch (e) {
      state = state.copyWith(status: CartStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> addItemToCart(String cartId, CartItem item) async {
    state = state.copyWith(status: CartStatus.loading);
    try {
      final cart = await _cartService.addItemToCart(cartId, item);
      state = state.copyWith(cart: cart, status: CartStatus.success);
    } catch (e) {
      state = state.copyWith(status: CartStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> removeItemFromCart(String cartId, int itemId) async {
    final originalCart = state.cart;
    state = state.copyWith(
      cart: state.cart?.copyWith(items: state.cart!.items.where((item) => item.id != itemId).toList()),
    );
    try {
      await _cartService.removeItemFromCart(cartId, itemId);
    } catch (e) {
      state = state.copyWith(cart: originalCart, status: CartStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> updateCartItem(String cartId, int itemId, int quantity) async {
    final originalCart = state.cart;
    final itemIndex = state.cart!.items.indexWhere((item) => item.id == itemId);
    if (itemIndex != -1) {
      final item = state.cart!.items[itemIndex];
      final updatedItem = CartItem(
        id: item.id,
        name: item.name,
        quantity: quantity,
        price: item.price,
        totalPrice: item.price * quantity,
        imageUrl: item.imageUrl,
      );
      final newItems = List<CartItem>.from(state.cart!.items);
      newItems[itemIndex] = updatedItem;
      state = state.copyWith(cart: state.cart?.copyWith(items: newItems));
    }

    try {
      await _cartService.updateCartItem(cartId, itemId, quantity);
    } catch (e) {
      state = state.copyWith(cart: originalCart, status: CartStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> clearCart(String cartId) async {
    state = state.copyWith(status: CartStatus.loading);
    try {
      await _cartService.clearCart(cartId);
      state = state.copyWith(cart: state.cart?.copyWith(items: []), status: CartStatus.success);
    } catch (e) {
      state = state.copyWith(status: CartStatus.error, errorMessage: e.toString());
    }
  }

    Future<void> checkoutCart(String cartId) async {
    state = state.copyWith(status: CartStatus.loading);
    try {
      await _cartService.checkoutCart(cartId);
      state = state.copyWith(cart: null, status: CartStatus.success);
    } catch (e) {
      state = state.copyWith(status: CartStatus.error, errorMessage: e.toString());
    }
  }
}
