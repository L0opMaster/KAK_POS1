// Regression coverage for what data "Print All" and "Print One" actually
// operate on, on ReceiptsScreen:
//  - Print All prints `ReceiptState.filteredSales` — the SAME list already
//    driving the on-screen count ("Receipts: N") — so there's no separate
//    query to drift out of sync with what the user is looking at. Unlike
//    the earlier A4-report bug, this screen's list endpoints are entirely
//    unbounded (no pagination), so "every sale matching the current
//    filters" and "everything already loaded in state" are the same set
//    by construction; these tests pin that down for 0/1/5/64 sales, with
//    and without the status/search filters active.
//  - Print One (SaleService.getReceipt) must request exactly the id it
//    was given, not, say, the currently-selected receipt or a stale one.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/providers/receipt_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/sale_service.dart';

SaleResponse _sale(int id, {String status = 'PAID', String? customerName}) =>
    SaleResponse(
      id: id,
      invoiceNumber: 'INV-${id.toString().padLeft(3, '0')}',
      status: status,
      grandTotal: id.toDouble(),
      paidAmount: id.toDouble(),
      customerName: customerName,
    );

void main() {
  group('ReceiptState.filteredSales — Print All\'s exact input, no filters',
      () {
    for (final count in [0, 1, 5, 64]) {
      test('$count sales loaded -> filteredSales has all $count, in order', () {
        final sales = List.generate(count, (i) => _sale(i + 1));
        final state = ReceiptState.initial().copyWith(sales: sales);

        expect(state.filteredSales.length, count);
        expect(state.filteredSales.map((s) => s.id).toList(),
            List.generate(count, (i) => i + 1));
      });
    }

    test(
        '64 sales -> every invoice number INV-001..INV-064 present exactly '
        'once — the exact reported "Transactions: 64" scenario', () {
      final sales = List.generate(64, (i) => _sale(i + 1));
      final state = ReceiptState.initial().copyWith(sales: sales);

      final numbers = state.filteredSales.map((s) => s.invoiceNumber).toSet();
      expect(numbers.length, 64);
      expect(numbers.contains('INV-001'), isTrue);
      expect(numbers.contains('INV-064'), isTrue);
    });
  });

  group(
      'ReceiptState.filteredSales — respects the active status filter '
      '(Print All must only get what the screen currently shows)', () {
    test('statusFilter=PAID excludes PENDING/REFUNDED sales from the batch',
        () {
      final sales = [
        _sale(1, status: 'PAID'),
        _sale(2, status: 'PENDING'),
        _sale(3, status: 'PAID'),
        _sale(4, status: 'REFUNDED'),
      ];
      final state =
          ReceiptState.initial().copyWith(sales: sales, statusFilter: 'PAID');

      expect(state.filteredSales.map((s) => s.id).toList(), [1, 3]);
    });

    test('no status filter -> all statuses included', () {
      final sales = [
        _sale(1, status: 'PAID'),
        _sale(2, status: 'PENDING'),
      ];
      final state = ReceiptState.initial().copyWith(sales: sales);

      expect(state.filteredSales.length, 2);
    });
  });

  group('ReceiptState.filteredSales — respects the active search query', () {
    test('search query narrows the batch to matching invoice/customer/id', () {
      final sales = [
        _sale(1, customerName: 'Alice'),
        _sale(2, customerName: 'Bob'),
        _sale(64, customerName: 'Alice'),
      ];
      final state =
          ReceiptState.initial().copyWith(sales: sales, searchQuery: 'alice');

      expect(state.filteredSales.map((s) => s.id).toList(), [1, 64]);
    });
  });

  group('SaleService.getReceipt — Print One loads exactly the requested id',
      () {
    test('requests /api/pos/sales/{id}/receipt for the given id only',
        () async {
      final api = _CapturingApiService();
      final service = SaleService(api);

      await service.getReceipt(64);

      expect(api.lastGetPath, '/api/pos/sales/64/receipt');
    });

    test('a different id produces a different, correctly-scoped path',
        () async {
      final api = _CapturingApiService();
      final service = SaleService(api);

      await service.getReceipt(1);
      expect(api.lastGetPath, '/api/pos/sales/1/receipt');

      await service.getReceipt(64);
      expect(api.lastGetPath, '/api/pos/sales/64/receipt',
          reason: 'must not still be pointed at the previous id');
    });
  });
}

class _CapturingApiService extends ApiService {
  String? lastGetPath;

  @override
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(Object? data)? fromJson,
  }) async {
    lastGetPath = path;
    return <String, dynamic>{'saleId': 1} as T;
  }
}
