import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/receipts_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/services/sale_service.dart';

import 'test_l10n_helper.dart';

class _FakeSaleService extends SaleService {
  _FakeSaleService() : super(ApiService());

  List<SaleResponse> sales = [];

  @override
  Future<List<SaleResponse>> getActiveShiftSales({
    String status = 'PAID',
  }) async => sales;

  @override
  Future<Map<String, dynamic>> getReceipt(int saleId) async {
    final sale = sales.firstWhere((s) => s.id == saleId);
    return {
      'saleId': sale.id,
      'saleNumber': sale.invoiceNumber,
      'status': sale.status,
      'total': sale.grandTotal,
      'paidAmount': sale.paidAmount,
    };
  }
}

SaleResponse _sale(int id, {required String status}) => SaleResponse(
  id: id,
  status: status,
  grandTotal: 10,
  paidAmount: 10,
  invoiceNumber: 'INV-$id',
);

Widget _wrap(SaleService service) => ProviderScope(
  overrides: [saleServiceProvider.overrideWithValue(service)],
  child: MaterialApp(
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    home: const ReceiptsScreen(),
  ),
);

void main() {
  testWidgets('lists sales with their status badges', (tester) async {
    final service = _FakeSaleService()
      ..sales = [_sale(1, status: 'PAID'), _sale(2, status: 'VOID')];
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('INV-1'), findsOneWidget);
    expect(find.text('INV-2'), findsOneWidget);
  });

  testWidgets('tapping a PAID sale opens its detail with a Refund button', (
    tester,
  ) async {
    final service = _FakeSaleService()..sales = [_sale(1, status: 'PAID')];
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('INV-1'));
    await tester.pumpAndSettle();

    expect(find.text('Refund'), findsOneWidget);
  });

  testWidgets(
    'tapping a VOID sale opens its detail WITHOUT a Refund button — VOID '
    'is terminal, no VOID -> PAID transition exists',
    (tester) async {
      final service = _FakeSaleService()..sales = [_sale(1, status: 'VOID')];
      await tester.pumpWidget(_wrap(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('INV-1'));
      await tester.pumpAndSettle();

      expect(find.text('Refund'), findsNothing);
    },
  );

  testWidgets('tapping a PARTIALLY_REFUNDED sale still shows Refund — further '
      'refund is explicitly permitted from this status too', (tester) async {
    final service = _FakeSaleService()
      ..sales = [_sale(1, status: 'PARTIALLY_REFUNDED')];
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('INV-1'));
    await tester.pumpAndSettle();

    expect(find.text('Refund'), findsOneWidget);
  });

  testWidgets('status filter chips narrow the visible list', (tester) async {
    final service = _FakeSaleService()
      ..sales = [_sale(1, status: 'PAID'), _sale(2, status: 'VOID')];
    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('INV-1'), findsOneWidget);
    expect(find.text('INV-2'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Void'));
    await tester.pumpAndSettle();

    expect(find.text('INV-1'), findsNothing);
    expect(find.text('INV-2'), findsOneWidget);
  });
}
