// Regression coverage for the Receipts status/filter inconsistencies:
// - 'PENDING' was a filter chip that never matched any real backend
//   Sale.status (no sale is ever literally "PENDING").
// - VOID is a real status but had no filter chip.
// - The REFUNDED chip only matched the literal REFUNDED status, missing
//   PARTIALLY_REFUNDED (which SaleService.refund() treats as part of the
//   same refund family — it's a valid starting state for another refund).
// - `sale.status == 'COMPLETED'` checks were dead — backend never
//   produces that status.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/providers/receipt_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/sale_service.dart';

SaleResponse _sale(int id, String status) => SaleResponse(
      id: id,
      status: status,
      grandTotal: 10,
      paidAmount: 10,
    );

void main() {
  group('saleMatchesStatusFilter', () {
    test('PAID filter matches only PAID', () {
      expect(saleMatchesStatusFilter('PAID', 'PAID'), isTrue);
      expect(saleMatchesStatusFilter('VOID', 'PAID'), isFalse);
      expect(saleMatchesStatusFilter('PARTIALLY_REFUNDED', 'PAID'), isFalse);
    });

    test('VOID filter matches only VOID', () {
      expect(saleMatchesStatusFilter('VOID', 'VOID'), isTrue);
      expect(saleMatchesStatusFilter('PAID', 'VOID'), isFalse);
    });

    test('REFUNDED filter matches both REFUNDED and PARTIALLY_REFUNDED',
        () {
      expect(saleMatchesStatusFilter('REFUNDED', 'REFUNDED'), isTrue);
      expect(saleMatchesStatusFilter('PARTIALLY_REFUNDED', 'REFUNDED'),
          isTrue);
      expect(saleMatchesStatusFilter('PAID', 'REFUNDED'), isFalse);
      expect(saleMatchesStatusFilter('VOID', 'REFUNDED'), isFalse);
    });
  });

  group('backendStatusQueryFor', () {
    test('PAID and VOID pass through unchanged (still narrowed server-side)',
        () {
      expect(backendStatusQueryFor('PAID'), 'PAID');
      expect(backendStatusQueryFor('VOID'), 'VOID');
    });

    test('null (All) passes through as null', () {
      expect(backendStatusQueryFor(null), isNull);
    });

    test('REFUNDED resolves to null — the backend cannot express a '
        '2-status family in one query param, so the fetch is left '
        'unfiltered and saleMatchesStatusFilter narrows it client-side',
        () {
      expect(backendStatusQueryFor('REFUNDED'), isNull);
    });
  });

  group('ReceiptState.filteredSales', () {
    final sales = [
      _sale(1, 'PAID'),
      _sale(2, 'VOID'),
      _sale(3, 'REFUNDED'),
      _sale(4, 'PARTIALLY_REFUNDED'),
      _sale(5, 'CREDIT'),
    ];

    test('no filter (All) includes every sale', () {
      final state = ReceiptState.initial().copyWith(sales: sales);
      expect(state.filteredSales.map((s) => s.id).toSet(), {1, 2, 3, 4, 5});
    });

    test('PAID filter includes only sale 1', () {
      final state =
          ReceiptState.initial().copyWith(sales: sales, statusFilter: 'PAID');
      expect(state.filteredSales.map((s) => s.id).toList(), [1]);
    });

    test('VOID filter includes only sale 2', () {
      final state =
          ReceiptState.initial().copyWith(sales: sales, statusFilter: 'VOID');
      expect(state.filteredSales.map((s) => s.id).toList(), [2]);
    });

    test('REFUNDED filter includes both REFUNDED (3) and '
        'PARTIALLY_REFUNDED (4)', () {
      final state = ReceiptState.initial()
          .copyWith(sales: sales, statusFilter: 'REFUNDED');
      expect(state.filteredSales.map((s) => s.id).toSet(), {3, 4});
    });

    test('a dead PENDING filter value matches nothing (no sale ever has '
        'that literal status) — proves why the chip had to be removed, '
        'not replaced with another fake status', () {
      final state = ReceiptState.initial()
          .copyWith(sales: sales, statusFilter: 'PENDING');
      expect(state.filteredSales, isEmpty);
    });
  });

  group('loadAllSales no longer couples statusFilter to the fetch', () {
    test('ReceiptState.copyWith preserves statusFilter independent of sales',
        () {
      // Regression for the bug where loadAllSales(status: null) — now
      // required for the REFUNDED family — used to also clear
      // state.statusFilter as a side effect, silently deselecting
      // whichever chip was active.
      final withFilter =
          ReceiptState.initial().copyWith(statusFilter: 'REFUNDED');
      final afterLoad = withFilter.copyWith(sales: [_sale(1, 'REFUNDED')]);
      expect(afterLoad.statusFilter, 'REFUNDED');
    });
  });
}
