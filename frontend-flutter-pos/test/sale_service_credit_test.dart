import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/sale_service.dart';

/// Captures whatever gets posted so tests can assert on the exact request
/// shape sent to the backend's credit-sale endpoints.
class CapturingApiService extends ApiService {
  Object? lastPostData;
  String? lastPostPath;

  @override
  Future<T> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    lastPostPath = path;
    lastPostData = data;
    return <String, dynamic>{
      'id': 1,
      'status': 'CREDIT',
      'grandTotal': 100.0,
      'paidAmount': 20.0,
      'creditDueAt': '2026-09-16T00:00:00Z',
      'creditStatus': 'PARTIALLY_PAID',
    } as T;
  }
}

void main() {
  group('SaleService.creditSale', () {
    test('posts to /{id}/credit with plain YYYY-MM-DD dates', () async {
      final api = CapturingApiService();
      final service = SaleService(api);

      await service.creditSale(
        42,
        dueDate: DateTime(2026, 9, 16),
        expiresAt: DateTime(2026, 10, 16),
        notes: 'extended term',
      );

      expect(api.lastPostPath, '/api/pos/sales/42/credit');
      final body = api.lastPostData as Map<String, dynamic>;
      expect(body['dueDate'], '2026-09-16');
      expect(body['expiresAt'], '2026-10-16');
      expect(body['notes'], 'extended term');
    });

    test('omits dueDate/expiresAt/notes entirely when not given', () async {
      final api = CapturingApiService();
      final service = SaleService(api);

      await service.creditSale(42);

      final body = api.lastPostData as Map<String, dynamic>;
      expect(body.containsKey('dueDate'), isFalse);
      expect(body.containsKey('expiresAt'), isFalse);
      expect(body.containsKey('notes'), isFalse);
    });

    test('parses the credit fields back off the response', () async {
      final api = CapturingApiService();
      final service = SaleService(api);

      final result = await service.creditSale(42, dueDate: DateTime(2026, 9, 16));

      expect(result.status, 'CREDIT');
      expect(result.creditDueAt, '2026-09-16T00:00:00Z');
      expect(result.creditStatus, 'PARTIALLY_PAID');
      expect(result.remainingBalance, 80.0);
    });
  });

  group('SaleService.repayCreditSale', () {
    test('posts amount/method/notes to /{id}/repayments', () async {
      final api = CapturingApiService();
      final service = SaleService(api);

      await service.repayCreditSale(42,
          amount: 30.0, method: 'CASH', notes: 'partial payment');

      expect(api.lastPostPath, '/api/pos/sales/42/repayments');
      final body = api.lastPostData as Map<String, dynamic>;
      expect(body['amount'], 30.0);
      expect(body['method'], 'CASH');
      expect(body['notes'], 'partial payment');
    });

    test('omits notes when not given', () async {
      final api = CapturingApiService();
      final service = SaleService(api);

      await service.repayCreditSale(42, amount: 30.0, method: 'CASH');

      final body = api.lastPostData as Map<String, dynamic>;
      expect(body.containsKey('notes'), isFalse);
    });
  });

  group('SaleResponse.remainingBalance', () {
    test('is grandTotal - paidAmount, never negative', () {
      final withBalance = SaleResponse(
          id: 1, status: 'CREDIT', grandTotal: 100, paidAmount: 30);
      expect(withBalance.remainingBalance, 70);

      final overpaid = SaleResponse(
          id: 1, status: 'PAID', grandTotal: 100, paidAmount: 120);
      expect(overpaid.remainingBalance, 0);
    });

    test(
        'is rounded to cents so a full-balance payment never fails on '
        'binary floating-point noise (regression)', () {
      // 6.003 - 3.003 lands on 2.9999999999999996 in raw IEEE 754 double
      // subtraction — unrounded, a cashier typing the displayed "3.00"
      // would then fail `amount > remainingBalance` by that sliver and see
      // "Amount exceeds remaining balance" on an exact full payment.
      final sale = SaleResponse(
          id: 1, status: 'CREDIT', grandTotal: 6.003, paidAmount: 3.003);
      expect(sale.remainingBalance, 3.0);
      expect(3.0 > sale.remainingBalance, isFalse);
    });
  });
}
