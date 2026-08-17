import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// sale_service.dart` — COPY/ADAPT NEARLY EXACTLY, full file. Only
/// `createSale`/`paySale`/`getReceipt` have real callers through Day 11
/// (`payment_screen.dart`'s checkout chain); the rest
/// (`getPaymentMethods`/`getSale`/`getActiveShiftSales`/`refundSale`/
/// `listSales`) are here because this is a single, small, cohesive service
/// class describing the shared backend's whole `/api/pos/sales` contract —
/// splitting it into a partial port (as `customer_service.dart`'s permanent
/// admin-CRUD boundary does) would be a false economy for methods later
/// days (12/18/refunds) genuinely need, not a permanent scope line like
/// customer CRUD is.
class PaymentMethodDto {
  final int id;
  final String code;
  final String name;
  final bool isCash;
  final bool active;

  PaymentMethodDto({
    required this.id,
    required this.code,
    required this.name,
    required this.isCash,
    required this.active,
  });

  factory PaymentMethodDto.fromJson(Map<String, dynamic> json) {
    return PaymentMethodDto(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      isCash: json['cash'] as bool? ?? json['isCash'] as bool? ?? false,
      active: json['active'] as bool? ?? true,
    );
  }
}

class SaleResponse {
  final int id;
  final String? invoiceNumber;
  final String status;
  final double grandTotal;
  final double paidAmount;
  final int? customerId;
  final String? customerName;
  final String? cashierName;
  final String? createdAt;
  final String? currency;
  final List<PaymentSummary> payments;

  /// Credit/pay-later fields — null when this sale was never a credit sale.
  /// `creditStatus` (OPEN/PARTIALLY_PAID/PAID/OVERDUE/EXPIRED/CANCELLED) is
  /// computed server-side; see the backend's `SaleService.computeCreditStatus`
  /// — the client never derives this itself for an authoritative view.
  final String? creditDueAt;
  final String? creditExpiresAt;
  final String? creditStatus;

  SaleResponse({
    required this.id,
    this.invoiceNumber,
    required this.status,
    required this.grandTotal,
    required this.paidAmount,
    this.customerId,
    this.customerName,
    this.cashierName,
    this.createdAt,
    this.currency,
    this.payments = const [],
    this.creditDueAt,
    this.creditExpiresAt,
    this.creditStatus,
  });

  /// What's still owed on this sale. Rounded to cents to avoid floating-point
  /// residue (e.g. 2.9999999999999996) causing a full-balance repayment to
  /// be rejected as "exceeds balance" — matches source's defensive rounding.
  double get remainingBalance {
    final raw = grandTotal - paidAmount;
    final rounded = (raw * 100).round() / 100;
    return rounded < 0 ? 0 : rounded;
  }

  factory SaleResponse.fromJson(Map<String, dynamic> json) {
    return SaleResponse(
      id: json['id'] as int,
      invoiceNumber: json['invoiceNumber'] as String?,
      status: json['status'] as String? ?? '',
      grandTotal: (json['grandTotal'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      customerId: (json['customerId'] as num?)?.toInt(),
      customerName: json['customerName'] as String?,
      cashierName: json['cashierName'] as String?,
      createdAt: json['createdAt'] as String?,
      currency: json['currency'] as String?,
      payments:
          (json['payments'] as List<dynamic>?)
              ?.map((e) => PaymentSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      creditDueAt: json['creditDueAt'] as String?,
      creditExpiresAt: json['creditExpiresAt'] as String?,
      creditStatus: json['creditStatus'] as String?,
    );
  }
}

class PaymentSummary {
  final int? id;
  final String method;
  final double amount;
  final String status;

  PaymentSummary({
    this.id,
    required this.method,
    required this.amount,
    required this.status,
  });

  factory PaymentSummary.fromJson(Map<String, dynamic> json) {
    return PaymentSummary(
      id: json['id'] as int?,
      method: json['method'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] as String? ?? '',
    );
  }
}

class SaleService {
  final ApiService _api;

  SaleService(this._api);

  Future<List<PaymentMethodDto>> getPaymentMethods() async {
    try {
      final data = await _api.get<List<dynamic>>(
        '/api/settings/payment-methods',
      );
      return data
          .map((e) => PaymentMethodDto.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Failed to fetch payment methods: $e');
      return _fallbackMethods();
    }
  }

  Future<SaleResponse> createSale(Map<String, dynamic> request) async {
    final data =
        await _api.post('/api/pos/sales', data: request)
            as Map<String, dynamic>;
    return SaleResponse.fromJson(data);
  }

  Future<SaleResponse> paySale(
    int saleId,
    List<Map<String, dynamic>> payments,
  ) async {
    final data =
        await _api.post(
              '/api/pos/sales/$saleId/pay',
              data: {'payments': payments},
            )
            as Map<String, dynamic>;
    return SaleResponse.fromJson(data);
  }

  Future<SaleResponse> getSale(int saleId) async {
    final data =
        await _api.get('/api/pos/sales/$saleId') as Map<String, dynamic>;
    return SaleResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> getReceipt(int saleId) async {
    return await _api.get('/api/pos/sales/$saleId/receipt')
        as Map<String, dynamic>;
  }

  Future<List<SaleResponse>> getActiveShiftSales({
    String status = 'PAID',
  }) async {
    final data = await _api.get<List<dynamic>>(
      '/api/pos/sales/active-shift',
      queryParameters: {'status': status},
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(SaleResponse.fromJson)
        .toList();
  }

  Future<SaleResponse> refundSale(
    int saleId, {
    required double amount,
    required String method,
    String? reason,
    String? managerEmail,
    String? managerPassword,
  }) async {
    final data =
        await _api.post(
              '/api/pos/sales/$saleId/refund',
              data: {
                'amount': amount,
                'method': method,
                if (reason != null && reason.isNotEmpty) 'reason': reason,
                if (managerEmail != null && managerEmail.isNotEmpty)
                  'managerEmail': managerEmail,
                if (managerPassword != null && managerPassword.isNotEmpty)
                  'managerPassword': managerPassword,
              },
            )
            as Map<String, dynamic>;
    return SaleResponse.fromJson(data);
  }

  /// Converts an existing (unpaid/partially-paid) sale into a credit/
  /// "pay later" sale — the checkout-time counterpart to
  /// [repayCreditSale] below (which pays one down later). `dueDate`/
  /// `expiresAt` are sent as plain `YYYY-MM-DD` local calendar dates (not
  /// UTC instants) via [_isoDate] — if omitted, the backend falls back to
  /// its own term-days-from-payment-terms default.
  Future<SaleResponse> creditSale(
    int saleId, {
    DateTime? dueDate,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final data =
        await _api.post(
              '/api/pos/sales/$saleId/credit',
              data: {
                if (dueDate != null) 'dueDate': _isoDate(dueDate),
                if (expiresAt != null) 'expiresAt': _isoDate(expiresAt),
                if (notes != null && notes.isNotEmpty) 'notes': notes,
              },
            )
            as Map<String, dynamic>;
    return SaleResponse.fromJson(data);
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Records a payment against an existing credit/pay-later sale. The
  /// backend rejects `amount` greater than the remaining balance and locks
  /// the row for the request's duration, so concurrent repayments can never
  /// together overpay — the client does not re-derive or double-check that
  /// invariant itself, matching source's "don't duplicate payment
  /// calculations" intent.
  Future<SaleResponse> repayCreditSale(
    int saleId, {
    required double amount,
    required String method,
    String? notes,
  }) async {
    final data =
        await _api.post(
              '/api/pos/sales/$saleId/repayments',
              data: {
                'amount': amount,
                'method': method,
                if (notes != null && notes.isNotEmpty) 'notes': notes,
              },
            )
            as Map<String, dynamic>;
    return SaleResponse.fromJson(data);
  }

  Future<List<SaleResponse>> listSales({String? query, String? status}) async {
    final data = await _api.get<List<dynamic>>(
      '/api/pos/sales',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'query': query,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return data
        .cast<Map<String, dynamic>>()
        .map(SaleResponse.fromJson)
        .toList();
  }

  List<PaymentMethodDto> _fallbackMethods() {
    return [
      PaymentMethodDto(
        id: 1,
        code: 'CASH',
        name: 'Cash',
        isCash: true,
        active: true,
      ),
      PaymentMethodDto(
        id: 2,
        code: 'CARD',
        name: 'Card',
        isCash: false,
        active: true,
      ),
      PaymentMethodDto(
        id: 3,
        code: 'ABA',
        name: 'ABA Pay',
        isCash: false,
        active: true,
      ),
      PaymentMethodDto(
        id: 4,
        code: 'KHQR',
        name: 'KHQR',
        isCash: false,
        active: true,
      ),
      PaymentMethodDto(
        id: 5,
        code: 'BANK_TRANSFER',
        name: 'Bank Transfer',
        isCash: false,
        active: true,
      ),
      PaymentMethodDto(
        id: 6,
        code: 'WING',
        name: 'Wing',
        isCash: false,
        active: true,
      ),
      PaymentMethodDto(
        id: 7,
        code: 'ACLEDA',
        name: 'ACLEDA Bank',
        isCash: false,
        active: true,
      ),
      PaymentMethodDto(
        id: 8,
        code: 'CHECK',
        name: 'Check',
        isCash: false,
        active: true,
      ),
    ];
  }
}

final saleServiceProvider = Provider<SaleService>((ref) {
  return SaleService(ref.watch(apiServiceProvider));
});

final paymentMethodsProvider = FutureProvider<List<PaymentMethodDto>>((ref) {
  return ref.watch(saleServiceProvider).getPaymentMethods();
});
