import 'dart:convert';

import 'product_models.dart';
import 'table_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// cart_models.dart` — `SelectedModifier`, `DiscountType`, `OrderMode`
/// (+label), `CartItem`, `HeldOrder` are COPY/ADAPT NEARLY EXACTLY
/// (`HeldOrder` added Day 9). `WaitingTicketStatus`/`WaitingTicket` (the
/// queue-board feature) are COPY/ADAPT NEARLY EXACTLY too — see
/// waiting_number_service.dart's file header for the queue-board method
/// boundary.
///
/// A single modifier option selected for a [CartItem] at checkout.
/// The `toJson`/`fromJson` field names (`groupId,groupName,optionId,
/// optionName,priceDelta`) are the exact contract the backend parses
/// `SaleLine.modifierData` against — do not rename them.
class SelectedModifier {
  const SelectedModifier({
    required this.groupId,
    required this.groupName,
    required this.optionId,
    required this.optionName,
    required this.priceDelta,
  });

  final int groupId;
  final String groupName;
  final int optionId;
  final String optionName;
  final double priceDelta;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'groupId': groupId,
        'groupName': groupName,
        'optionId': optionId,
        'optionName': optionName,
        'priceDelta': priceDelta,
      };

  factory SelectedModifier.fromJson(Map<String, dynamic> json) =>
      SelectedModifier(
        groupId: (json['groupId'] as num?)?.toInt() ?? 0,
        groupName: json['groupName'] as String? ?? '',
        optionId: (json['optionId'] as num?)?.toInt() ?? 0,
        optionName: json['optionName'] as String? ?? '',
        priceDelta: (json['priceDelta'] as num?)?.toDouble() ?? 0,
      );
}

enum DiscountType { fixed, percent }

enum OrderMode { dineIn, takeaway, delivery }

extension OrderModeExtension on OrderMode {
  String get label {
    switch (this) {
      case OrderMode.dineIn:
        return 'Dine In';
      case OrderMode.takeaway:
        return 'Takeaway';
      case OrderMode.delivery:
        return 'Delivery';
    }
  }
}

class CartItem {
  CartItem({
    required this.id,
    required this.product,
    required this.qty,
    required this.addedAt,
    this.note,
    this.discountAmount,
    this.selectedModifiers = const [],
  });

  final String id;
  final Product product;
  final int qty;
  final int addedAt;
  final String? note;
  final double? discountAmount;
  final List<SelectedModifier> selectedModifiers;

  double get modifierPriceDelta =>
      selectedModifiers.fold(0.0, (sum, m) => sum + m.priceDelta);

  /// Per-unit price including modifier surcharges — must stay in sync with
  /// the backend's own `SaleService.modifierPriceDelta` calculation.
  double get unitPrice => product.price + modifierPriceDelta;

  double get lineTotal => unitPrice * qty;

  String get modifierSummaryText {
    if (selectedModifiers.isEmpty) return '';
    final Map<String, List<String>> byGroup = <String, List<String>>{};
    final List<String> order = [];
    for (final m in selectedModifiers) {
      if (!byGroup.containsKey(m.groupName)) {
        byGroup[m.groupName] = [];
        order.add(m.groupName);
      }
      byGroup[m.groupName]!.add(m.optionName);
    }
    return order
        .map((groupName) => '$groupName: ${byGroup[groupName]!.join(', ')}')
        .join(', ');
  }

  /// JSON-encoded modifier data matching the backend contract
  /// (`SaleLineRequest.modifierData`).
  String get modifierDataJson =>
      jsonEncode(selectedModifiers.map((m) => m.toJson()).toList());

  CartItem copyWith({
    String? id,
    Product? product,
    int? qty,
    int? addedAt,
    String? note,
    double? discountAmount,
    List<SelectedModifier>? selectedModifiers,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      qty: qty ?? this.qty,
      addedAt: addedAt ?? this.addedAt,
      note: note ?? this.note,
      discountAmount: discountAmount ?? this.discountAmount,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    );
  }

  /// The API returns a flattened structure (`productId`, `unitPrice`, etc.)
  /// while the local in-memory cart stores a nested `product` object. This
  /// factory handles both shapes.
  factory CartItem.fromJson(final Map<String, dynamic> json) {
    if (json.containsKey('product')) {
      return CartItem(
        id: json['id'] as String,
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        qty: json['qty'] as int,
        addedAt: json['addedAt'] as int,
        note: json['note'] as String?,
        discountAmount: (json['discountAmount'] as num?)?.toDouble(),
        selectedModifiers: json['selectedModifiers'] is List
            ? (json['selectedModifiers'] as List<dynamic>)
                .whereType<Map>()
                .map((e) =>
                    SelectedModifier.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
      );
    }

    final double price = (json['unitPrice'] as num?)?.toDouble() ?? 0;
    final Product product = Product(
      id: (json['productId'] as num?)?.toInt() ?? 0,
      sku: json['productSku'] as String? ?? '',
      barcode: '',
      nameEn: json['productNameEn'] as String? ?? '',
      nameKm: json['productNameKm'] as String? ?? '',
      price: price,
      cost: 0,
      stock: 0,
      active: true,
      trackInventory: false,
      imageUrl: null,
      categoryId: 0,
    );
    return CartItem(
      id: json['id'].toString(),
      product: product,
      qty: json['quantity'] as int,
      addedAt: DateTime.now().millisecondsSinceEpoch,
      note: json['note'] as String?,
      discountAmount: (json['discountAmount'] as num?)?.toDouble(),
    );
  }

  /// Local shape — used by the OFFLINE cart snapshot and by
  /// `LocalCartService`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'product': product.toJson(),
        'qty': qty,
        'addedAt': addedAt,
        if (note != null) 'note': note,
        if (discountAmount != null) 'discountAmount': discountAmount,
        if (selectedModifiers.isNotEmpty)
          'selectedModifiers':
              selectedModifiers.map((m) => m.toJson()).toList(),
      };

  /// Minimal representation suitable for API requests (`ApiCartService`).
  Map<String, dynamic> toApiJson() => <String, dynamic>{
        'productId': product.id,
        'quantity': qty,
        if (note != null) 'note': note,
        if (discountAmount != null && discountAmount! > 0)
          'lineDiscount': discountAmount,
      };
}

/// Status of a [WaitingTicket] on the queue board.
enum WaitingTicketStatus {
  held,
  paid,
  ready,
}

extension WaitingTicketStatusExtension on WaitingTicketStatus {
  String get label {
    switch (this) {
      case WaitingTicketStatus.held:
        return 'Pay Later';
      case WaitingTicketStatus.paid:
        return 'Paid';
      case WaitingTicketStatus.ready:
        return 'Ready';
    }
  }

  static WaitingTicketStatus fromString(String? value) {
    switch (value) {
      case 'paid':
        return WaitingTicketStatus.paid;
      case 'ready':
        return WaitingTicketStatus.ready;
      case 'held':
      default:
        return WaitingTicketStatus.held;
    }
  }
}

/// A local queue ticket because the backend currently has no waiting
/// numbers. Backs the "queue board" feature (see
/// `mobile_waiting_tickets_screen.dart`) — distinct from [HeldOrder], which
/// backs the hold/resume-a-cart flow.
class WaitingTicket {
  const WaitingTicket({
    required this.id,
    required this.waitingNumber,
    required this.items,
    required this.orderMode,
    required this.status,
    required this.total,
    required this.createdAt,
    this.orderId,
  });

  /// Local unique ticket ID.
  final String id;

  /// Backend held/sale order ID when available.
  final int? orderId;

  /// Queue number from 1 to 100.
  final int waitingNumber;

  final List<CartItem> items;
  final OrderMode orderMode;
  final WaitingTicketStatus status;
  final double total;
  final String createdAt;

  WaitingTicket copyWith({
    String? id,
    int? orderId,
    int? waitingNumber,
    List<CartItem>? items,
    OrderMode? orderMode,
    WaitingTicketStatus? status,
    double? total,
    String? createdAt,
  }) {
    return WaitingTicket(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      waitingNumber: waitingNumber ?? this.waitingNumber,
      items: items ?? this.items,
      orderMode: orderMode ?? this.orderMode,
      status: status ?? this.status,
      total: total ?? this.total,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory WaitingTicket.fromJson(Map<String, dynamic> json) {
    final dynamic rawOrderId = json['orderId'];

    return WaitingTicket(
      id: json['id']?.toString() ?? '',
      orderId: rawOrderId == null
          ? null
          : rawOrderId is int
              ? rawOrderId
              : int.tryParse(rawOrderId.toString()),
      waitingNumber: (json['waitingNumber'] as num?)?.toInt() ??
          int.tryParse(json['waitingNumber']?.toString() ?? '') ??
          0,
      items: (json['items'] as List<dynamic>? ?? <dynamic>[])
          .map(
            (dynamic item) => CartItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      orderMode: OrderMode.values[
          (json['orderMode'] as num?)?.toInt() ?? OrderMode.dineIn.index],
      status: WaitingTicketStatusExtension.fromString(
        json['status']?.toString(),
      ),
      total: (json['total'] as num?)?.toDouble() ?? 0,
      createdAt:
          json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      if (orderId != null) 'orderId': orderId,
      'waitingNumber': waitingNumber,
      'items': items.map((CartItem item) => item.toJson()).toList(),
      'orderMode': orderMode.index,
      'status': status.name,
      'total': total,
      'createdAt': createdAt,
    };
  }
}

/// Model for a held order in the cart. Added Day 9.
class HeldOrder {
  HeldOrder({
    required this.id,
    required this.status,
    this.cartItems,
    this.table,
    this.createdAt,
    this.waitingNumber,
  });

  final int id;
  final String status;
  final List<CartItem>? cartItems;
  final RestaurantTable? table;
  final int? waitingNumber;
  final String? createdAt;

  factory HeldOrder.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final int id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    return HeldOrder(
      id: id,
      status: json['status'] as String? ?? 'open',
      cartItems: json['cart'] != null
          ? (json['cart'] as List<dynamic>)
              .map((dynamic e) => CartItem.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      table: json['table'] != null
          ? RestaurantTable.fromJson(json['table'] as Map<String, dynamic>)
          : (json['tableName'] != null
              ? RestaurantTable.sample().copyWith(
                  tableNumber: json['tableName'] as String,
                  displayName: 'Table ${json['tableName'] as String}',
                )
              : null),
      createdAt: json['createdAt'] as String?,
      waitingNumber: json['waitingNumber'] as int?,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'status': status,
        if (cartItems != null)
          'cart': cartItems!.map((CartItem e) => e.toJson()).toList(),
        if (table != null) 'table': table!.toJson(),
        if (createdAt != null) 'createdAt': createdAt,
        if (waitingNumber != null) 'waitingNumber': waitingNumber,
      };
}
