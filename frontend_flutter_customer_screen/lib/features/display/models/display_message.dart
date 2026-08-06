// Typed views over the JSON envelopes the POS app broadcasts. Field names
// mirror `broadcastCartState`/`broadcastPaymentPending`/etc. in
// frontend-flutter-pos's `customer_display_provider.dart` exactly — this
// is the shared wire contract between the two apps (the backend relay
// never inspects it).

class CartItemSnapshot {
  const CartItemSnapshot({
    required this.nameEn,
    required this.nameKm,
    required this.qty,
    required this.unitPrice,
    required this.lineTotal,
    this.modifiers,
  });

  final String nameEn;
  final String nameKm;
  final int qty;
  final double unitPrice;
  final double lineTotal;
  final String? modifiers;

  factory CartItemSnapshot.fromJson(Map<String, dynamic> json) {
    return CartItemSnapshot(
      nameEn: json['nameEn'] as String? ?? '',
      nameKm: json['nameKm'] as String? ?? '',
      qty: (json['qty'] as num?)?.toInt() ?? 0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      modifiers: json['modifiers'] as String?,
    );
  }
}

class CartSnapshot {
  const CartSnapshot({
    required this.orderMode,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.total,
    required this.currencySymbol,
    this.tableId,
  });

  final String orderMode;
  final int? tableId;
  final List<CartItemSnapshot> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double total;
  final String currencySymbol;

  factory CartSnapshot.fromJson(Map<String, dynamic> json) {
    return CartSnapshot(
      orderMode: json['orderMode'] as String? ?? 'dineIn',
      tableId: (json['tableId'] as num?)?.toInt(),
      items: (json['items'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) =>
              CartItemSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      currencySymbol: json['currencySymbol'] as String? ?? r'$',
    );
  }

  bool get isEmpty => items.isEmpty;
}

class PaymentPendingSnapshot {
  const PaymentPendingSnapshot({
    required this.amountDue,
    required this.currencySymbol,
  });

  final double amountDue;
  final String currencySymbol;

  factory PaymentPendingSnapshot.fromJson(Map<String, dynamic> json) {
    return PaymentPendingSnapshot(
      amountDue: (json['amountDue'] as num?)?.toDouble() ?? 0,
      currencySymbol: json['currencySymbol'] as String? ?? r'$',
    );
  }
}

class PaymentSplitSnapshot {
  const PaymentSplitSnapshot({
    required this.method,
    required this.amount,
  });

  final String method;
  final double amount;

  factory PaymentSplitSnapshot.fromJson(Map<String, dynamic> json) {
    return PaymentSplitSnapshot(
      method: json['method'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class PaymentSplitUpdateSnapshot {
  const PaymentSplitUpdateSnapshot({
    required this.splits,
    required this.remaining,
    required this.currencySymbol,
  });

  final List<PaymentSplitSnapshot> splits;
  final double remaining;
  final String currencySymbol;

  factory PaymentSplitUpdateSnapshot.fromJson(Map<String, dynamic> json) {
    return PaymentSplitUpdateSnapshot(
      splits: (json['splits'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) =>
              PaymentSplitSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(),
      remaining: (json['remaining'] as num?)?.toDouble() ?? 0,
      currencySymbol: json['currencySymbol'] as String? ?? r'$',
    );
  }
}

class PaymentCompletedSnapshot {
  const PaymentCompletedSnapshot({
    required this.receiptNumber,
    required this.total,
    required this.amountPaid,
    required this.change,
    required this.currencySymbol,
  });

  final String receiptNumber;
  final double total;
  final double amountPaid;
  final double change;
  final String currencySymbol;

  factory PaymentCompletedSnapshot.fromJson(Map<String, dynamic> json) {
    return PaymentCompletedSnapshot(
      receiptNumber: json['receiptNumber'] as String? ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      currencySymbol: json['currencySymbol'] as String? ?? r'$',
    );
  }
}
