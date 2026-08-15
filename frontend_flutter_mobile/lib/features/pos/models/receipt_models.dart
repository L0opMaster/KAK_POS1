/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// receipt_models.dart` — COPY/ADAPT NEARLY EXACTLY, full file.
class ReceiptResponse {
  final String? businessName;
  final String? address;
  final String? phone;
  final String? website;
  final String? currency;
  final String? footer;
  final int saleId;
  final String? saleNumber;
  final int? shiftId;
  final int? storeId;
  final String? createdAt;
  final String? cashierName;
  final String? storeName;
  final String? customerName;
  final String? customerPhone;
  final int? tableId;
  final String? tableNumber;
  final String? orderMode;
  final String? status;
  final List<ReceiptLine> lines;
  final List<ReceiptPayment> payments;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double deliveryCharge;
  final double otherCharge;
  final double total;
  final double paidAmount;
  final double changeAmount;
  final double refundedAmount;
  final String? qrImageData;
  final String? logoUrl;

  /// Exchange rate frozen at time of sale — null for sales that predate
  /// this field.
  final double? exchangeRateKhr;

  ReceiptResponse({
    this.businessName,
    this.address,
    this.phone,
    this.website,
    this.currency,
    this.footer,
    required this.saleId,
    this.saleNumber,
    this.shiftId,
    this.storeId,
    this.createdAt,
    this.cashierName,
    this.storeName,
    this.customerName,
    this.customerPhone,
    this.tableId,
    this.tableNumber,
    this.orderMode,
    this.status,
    this.lines = const [],
    this.payments = const [],
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.deliveryCharge = 0,
    this.otherCharge = 0,
    this.total = 0,
    this.paidAmount = 0,
    this.changeAmount = 0,
    this.refundedAmount = 0,
    this.qrImageData,
    this.logoUrl,
    this.exchangeRateKhr,
  });

  factory ReceiptResponse.fromJson(Map<String, dynamic> json) {
    return ReceiptResponse(
      businessName: json['businessName'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      currency: json['currency'] as String?,
      footer: json['footer'] as String?,
      saleId: (json['saleId'] as num?)?.toInt() ?? 0,
      saleNumber: json['saleNumber'] as String?,
      shiftId: (json['shiftId'] as num?)?.toInt(),
      storeId: (json['storeId'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String?,
      cashierName: json['cashierName'] as String?,
      storeName: json['storeName'] as String?,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      tableId: (json['tableId'] as num?)?.toInt(),
      tableNumber: json['tableNumber'] as String?,
      orderMode: json['orderMode'] as String?,
      status: json['status'] as String?,
      lines:
          (json['lines'] as List<dynamic>?)
              ?.map((e) => ReceiptLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      payments:
          (json['payments'] as List<dynamic>?)
              ?.map((e) => ReceiptPayment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      deliveryCharge: (json['deliveryCharge'] as num?)?.toDouble() ?? 0,
      otherCharge: (json['otherCharge'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      changeAmount: (json['changeAmount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0,
      qrImageData: json['qrImageData'] as String?,
      logoUrl: json['logoUrl'] as String?,
      exchangeRateKhr: (json['exchangeRateKhr'] as num?)?.toDouble(),
    );
  }
}

class ReceiptLine {
  final int? saleLineId;
  final String? nameEn;
  final String? nameKm;
  final double qty;
  final String? unitSymbol;
  final double unitPrice;
  final double lineTotal;
  final double refundedQty;

  /// Sum of modifier price deltas already baked into [unitPrice].
  final double modifierAmount;
  final String? modifierSummary;

  double get basePrice => unitPrice - modifierAmount;

  ReceiptLine({
    this.saleLineId,
    this.nameEn,
    this.nameKm,
    this.qty = 0,
    this.unitSymbol,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.refundedQty = 0,
    this.modifierAmount = 0,
    this.modifierSummary,
  });

  factory ReceiptLine.fromJson(Map<String, dynamic> json) {
    return ReceiptLine(
      saleLineId: (json['saleLineId'] as num?)?.toInt(),
      nameEn: json['nameEn'] as String?,
      nameKm: json['nameKm'] as String?,
      qty: (json['qty'] as num?)?.toDouble() ?? 0,
      unitSymbol: json['unitSymbol'] as String?,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      refundedQty: (json['refundedQty'] as num?)?.toDouble() ?? 0,
      modifierAmount: (json['modifierAmount'] as num?)?.toDouble() ?? 0,
      modifierSummary: json['modifierSummary'] as String?,
    );
  }
}

class ReceiptPayment {
  final String? method;
  final double amount;

  ReceiptPayment({this.method, this.amount = 0});

  factory ReceiptPayment.fromJson(Map<String, dynamic> json) {
    return ReceiptPayment(
      method: json['method'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
