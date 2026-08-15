import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/receipt_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/sale_service.dart';

SaleResponse _sale(int id, {String status = 'PAID', String? customerName}) =>
    SaleResponse(
      id: id,
      status: status,
      grandTotal: 10,
      paidAmount: 10,
      customerName: customerName,
      invoiceNumber: 'INV-$id',
    );

class _FakeSaleService extends SaleService {
  _FakeSaleService() : super(ApiService());

  List<SaleResponse> activeShiftSales = [];
  List<SaleResponse> allSales = [];
  String? lastListSalesStatus;
  bool throwOnGetActiveShiftSales = false;
  Map<int, Map<String, dynamic>> receiptsById = {};

  @override
  Future<List<SaleResponse>> getActiveShiftSales({
    String status = 'PAID',
  }) async {
    if (throwOnGetActiveShiftSales) throw Exception('network down');
    return activeShiftSales;
  }

  @override
  Future<List<SaleResponse>> listSales({String? query, String? status}) async {
    lastListSalesStatus = status;
    return allSales;
  }

  @override
  Future<Map<String, dynamic>> getReceipt(int saleId) async {
    final receipt = receiptsById[saleId];
    if (receipt == null) throw Exception('not found');
    return receipt;
  }
}

void main() {
  group('saleMatchesStatusFilter', () {
    test('REFUNDED filter matches both REFUNDED and PARTIALLY_REFUNDED', () {
      expect(saleMatchesStatusFilter('REFUNDED', 'REFUNDED'), isTrue);
      expect(saleMatchesStatusFilter('PARTIALLY_REFUNDED', 'REFUNDED'), isTrue);
      expect(saleMatchesStatusFilter('PAID', 'REFUNDED'), isFalse);
    });

    test('every other filter matches only the literal status', () {
      expect(saleMatchesStatusFilter('PAID', 'PAID'), isTrue);
      expect(saleMatchesStatusFilter('VOID', 'PAID'), isFalse);
      expect(saleMatchesStatusFilter('VOID', 'VOID'), isTrue);
    });
  });

  group('backendStatusQueryFor', () {
    test('REFUNDED maps to null (backend cannot express the two-status '
        'family, so the fetch is unfiltered and narrowed client-side)', () {
      expect(backendStatusQueryFor('REFUNDED'), isNull);
    });

    test('every other status (including null) passes through unchanged', () {
      expect(backendStatusQueryFor('PAID'), 'PAID');
      expect(backendStatusQueryFor('VOID'), 'VOID');
      expect(backendStatusQueryFor(null), isNull);
    });
  });

  group('ReceiptState.filteredSales', () {
    test('statusFilter narrows via saleMatchesStatusFilter, not raw '
        'equality', () {
      final state = ReceiptState(
        loading: false,
        sales: [
          _sale(1, status: 'PAID'),
          _sale(2, status: 'REFUNDED'),
          _sale(3, status: 'PARTIALLY_REFUNDED'),
        ],
        statusFilter: 'REFUNDED',
      );
      expect(state.filteredSales.map((s) => s.id), [2, 3]);
    });

    test('searchQuery matches invoice number, customer name, or raw id', () {
      final sales = [
        _sale(1, customerName: 'Alice'),
        _sale(2, customerName: 'Bob'),
      ];
      expect(
        ReceiptState(
          loading: false,
          sales: sales,
          searchQuery: 'alice',
        ).filteredSales.map((s) => s.id),
        [1],
      );
      expect(
        ReceiptState(
          loading: false,
          sales: sales,
          searchQuery: 'INV-2',
        ).filteredSales.map((s) => s.id),
        [2],
      );
    });

    test('no filter/query returns everything', () {
      final sales = [_sale(1), _sale(2)];
      expect(
        ReceiptState(loading: false, sales: sales).filteredSales,
        hasLength(2),
      );
    });
  });

  group('ReceiptNotifier', () {
    test('loadActiveShiftSales populates sales and clears selection when '
        'empty', () async {
      final service = _FakeSaleService()..activeShiftSales = [_sale(1)];
      final container = ProviderContainer(
        overrides: [saleServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(receiptProvider.notifier).loadActiveShiftSales();

      expect(container.read(receiptProvider).sales, hasLength(1));
      expect(container.read(receiptProvider).error, isNull);
    });

    test('loadActiveShiftSales records an error on failure, without '
        'throwing', () async {
      final service = _FakeSaleService()..throwOnGetActiveShiftSales = true;
      final container = ProviderContainer(
        overrides: [saleServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(receiptProvider.notifier).loadActiveShiftSales();

      expect(container.read(receiptProvider).error, isNotNull);
      expect(container.read(receiptProvider).sales, isEmpty);
    });

    test('loadAllSales does NOT also set statusFilter — chip selection is '
        'owned exclusively by setStatusFilter (a prior coupling bug, must '
        'not be reintroduced)', () async {
      final service = _FakeSaleService()..allSales = [_sale(1, status: 'VOID')];
      final container = ProviderContainer(
        overrides: [saleServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container
          .read(receiptProvider.notifier)
          .loadAllSales(status: 'VOID');

      expect(service.lastListSalesStatus, 'VOID');
      expect(container.read(receiptProvider).statusFilter, isNull);
      expect(container.read(receiptProvider).sales, hasLength(1));
    });

    test('setStatusFilter sets/clears independently of any fetch', () {
      final container = ProviderContainer(
        overrides: [saleServiceProvider.overrideWithValue(_FakeSaleService())],
      );
      addTearDown(container.dispose);

      container.read(receiptProvider.notifier).setStatusFilter('PAID');
      expect(container.read(receiptProvider).statusFilter, 'PAID');

      container.read(receiptProvider.notifier).setStatusFilter(null);
      expect(container.read(receiptProvider).statusFilter, isNull);
    });

    test('loadReceipt populates selectedReceipt on success', () async {
      final service = _FakeSaleService()
        ..receiptsById = {
          7: {'saleId': 7, 'total': 12.5},
        };
      final container = ProviderContainer(
        overrides: [saleServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(receiptProvider.notifier).loadReceipt(7);

      expect(container.read(receiptProvider).selectedReceipt?.saleId, 7);
      expect(container.read(receiptProvider).selectedReceipt?.total, 12.5);
    });

    test(
      'loadReceipt clears selection and records an error on failure',
      () async {
        final container = ProviderContainer(
          overrides: [
            saleServiceProvider.overrideWithValue(_FakeSaleService()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(receiptProvider.notifier).loadReceipt(999);

        expect(container.read(receiptProvider).selectedReceipt, isNull);
        expect(container.read(receiptProvider).error, isNotNull);
      },
    );
  });
}
