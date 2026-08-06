
import '../models/cart_model.dart';

class CartService {
  // Simulate a network delay
  Future<void> _simulateNetworkDelay() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<Cart> getCart(String cartId) async {
    await _simulateNetworkDelay();
    // In a real app, this would make an API call
    // For now, return a mock cart
    return Cart(
      id: cartId,
      items: [
        CartItem(id: 1, name: 'Product 1', quantity: 2, price: 10.0, totalPrice: 20.0),
        CartItem(id: 2, name: 'Product 2', quantity: 1, price: 15.0, totalPrice: 15.0),
      ],
      totalAmount: 35.0,
      customerNameEn: 'Sotheakh',
      storeName: 'KAKNNEA POS',
      status: 'PENDING',
    );
  }

  Future<Cart> addItemToCart(String cartId, CartItem item) async {
    await _simulateNetworkDelay();
    // In a real app, this would make an API call
    return Cart(
      id: cartId,
      items: [
        CartItem(id: 1, name: 'Product 1', quantity: 2, price: 10.0, totalPrice: 20.0),
        CartItem(id: 2, name: 'Product 2', quantity: 1, price: 15.0, totalPrice: 15.0),
        item,
      ],
      totalAmount: 35.0 + item.totalPrice,
      customerNameEn: 'Sotheakh',
      storeName: 'KAKNNEA POS',
      status: 'PENDING',
    );
  }

  Future<Cart> removeItemFromCart(String cartId, int itemId) async {
    await _simulateNetworkDelay();
    // In a real app, this would make an API call
    return Cart(
      id: cartId,
      items: [
        CartItem(id: 2, name: 'Product 2', quantity: 1, price: 15.0, totalPrice: 15.0),
      ],
      totalAmount: 15.0,
      customerNameEn: 'Sotheakh',
      storeName: 'KAKNNEA POS',
      status: 'PENDING',
    );
  }

  Future<CartItem> updateCartItem(String cartId, int itemId, int quantity) async {
    await _simulateNetworkDelay();
    // In a real app, this would make an API call
    return CartItem(id: itemId, name: 'Product 1', quantity: quantity, price: 10.0, totalPrice: 10.0 * quantity);
  }

  Future<void> clearCart(String cartId) async {
    await _simulateNetworkDelay();
    // In a real app, this would make an API call
  }

  Future<void> checkoutCart(String cartId) async {
    await _simulateNetworkDelay();
    // In a real app, this would make an API call
  }
}
