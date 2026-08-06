
import 'package:flutter/foundation.dart';

class Cart {
  final String? id;
  final List<CartItem> items;
  final double totalAmount;
  final String customerNameEn;
  final String? storeName;
  final String status;

  Cart({
    this.id,
    required this.items,
    required this.totalAmount,
    this.customerNameEn = 'Walk-in Customer',
    this.storeName,
    this.status = 'PENDING',
  });

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'],
      items: (json['items'] as List)
          .map((item) => CartItem.fromJson(item))
          .toList(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      customerNameEn: json['customerNameEn'] ?? 'Walk-in Customer',
      storeName: json['storeName'],
      status: json['status'] ?? 'PENDING',
    );
  }

  Cart copyWith({
    String? id,
    List<CartItem>? items,
    double? totalAmount,
    String? customerNameEn,
    String? storeName,
    String? status,
  }) {
    return Cart(
      id: id ?? this.id,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      customerNameEn: customerNameEn ?? this.customerNameEn,
      storeName: storeName ?? this.storeName,
      status: status ?? this.status,
    );
  }
}

class CartItem {
  final int id;
  final String name;
  final int quantity;
  final double price;
  final double totalPrice;
  final String? imageUrl;

  CartItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.totalPrice,
    this.imageUrl,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'],
      price: (json['price'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      imageUrl: json['imageUrl'],
    );
  }
}
