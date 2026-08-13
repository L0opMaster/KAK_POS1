// End-to-end coverage (through the real screen) for the Receipts
// status/filter fix: no PENDING chip, a VOID chip that actually filters,
// and REFUNDED covering both REFUNDED and PARTIALLY_REFUNDED.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/screens/receipts_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/sale_service.dart';

import 'test_l10n_helper.dart';

class _FakeSaleService extends SaleService {
  _FakeSaleService() : super(ApiService());

  final List<SaleResponse> allSales = [
    SaleResponse(
        id: 1, invoiceNumber: 'SR-1', status: 'PAID', grandTotal: 10, paidAmount: 10),
    SaleResponse(
        id: 2, invoiceNumber: 'SR-2', status: 'VOID', grandTotal: 20, paidAmount: 0),
    SaleResponse(
        id: 3,
        invoiceNumber: 'SR-3',
        status: 'REFUNDED',
        grandTotal: 30,
        paidAmount: 30),
    SaleResponse(
        id: 4,
        invoiceNumber: 'SR-4',
        status: 'PARTIALLY_REFUNDED',
        grandTotal: 40,
        paidAmount: 40),
  ];

  @override
  Future<List<SaleResponse>> getActiveShiftSales({String status = 'PAID'}) async =>
      allSales.where((s) => s.status == status).toList();

  @override
  Future<List<SaleResponse>> listSales({String? query, String? status}) async =>
      status == null
          ? allSales
          : allSales.where((s) => s.status == status).toList();

  @override
  Future<Map<String, dynamic>> getReceipt(int saleId) async => {
        'saleId': saleId,
        'status': allSales.firstWhere((s) => s.id == saleId).status,
      };
}

Future<void> _switchToAllSales(WidgetTester tester) async {
  await tester.tap(find.descendant(
    of: find.byType(SegmentedButton<bool>),
    matching: find.text('All'),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilterChip, label));
  await tester.pumpAndSettle();
}

void main() {
  Widget buildScreen(_FakeSaleService service) => ProviderScope(
        overrides: [saleServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: const ReceiptsScreen(),
        ),
      );

  testWidgets('no PENDING chip; a Void chip exists instead', (tester) async {
    final service = _FakeSaleService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();

    expect(find.text('PENDING'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Void'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Paid'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Refunded'), findsOneWidget);
  });

  testWidgets('Void filter shows only the VOID sale', (tester) async {
    final service = _FakeSaleService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();
    await _switchToAllSales(tester);

    await _tapChip(tester, 'Void');

    expect(find.text('SR-2'), findsOneWidget);
    expect(find.text('SR-1'), findsNothing);
    expect(find.text('SR-3'), findsNothing);
    expect(find.text('SR-4'), findsNothing);
  });

  testWidgets('Paid filter shows only the PAID sale', (tester) async {
    final service = _FakeSaleService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();
    await _switchToAllSales(tester);

    await _tapChip(tester, 'Paid');

    expect(find.text('SR-1'), findsOneWidget);
    expect(find.text('SR-2'), findsNothing);
    expect(find.text('SR-3'), findsNothing);
    expect(find.text('SR-4'), findsNothing);
  });

  testWidgets(
      'Refunded filter shows both the REFUNDED and PARTIALLY_REFUNDED sales',
      (tester) async {
    final service = _FakeSaleService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();
    await _switchToAllSales(tester);

    await _tapChip(tester, 'Refunded');

    expect(find.text('SR-3'), findsOneWidget);
    expect(find.text('SR-4'), findsOneWidget);
    expect(find.text('SR-1'), findsNothing);
    expect(find.text('SR-2'), findsNothing);
  });

  testWidgets('All filter (no chip selected) shows every sale', (tester) async {
    // The default test surface is too short for the split-pane layout to
    // fit all 4 rows in the list pane at once — grow it so the 4th row's
    // absence would be a real bug, not just an off-screen lazy-list item.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeSaleService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();
    await _switchToAllSales(tester);

    expect(find.text('SR-1'), findsOneWidget);
    expect(find.text('SR-2'), findsOneWidget);
    expect(find.text('SR-3'), findsOneWidget);
    expect(find.text('SR-4'), findsOneWidget);
  });

  testWidgets(
      'switching to All sales does not silently clear an active status '
      'filter selection (the loadAllSales/statusFilter coupling bug)',
      (tester) async {
    final service = _FakeSaleService();
    await tester.pumpWidget(buildScreen(service));
    await tester.pumpAndSettle();
    await _switchToAllSales(tester);

    await _tapChip(tester, 'Refunded');
    expect(find.text('SR-3'), findsOneWidget);
    expect(find.text('SR-4'), findsOneWidget);

    // Flip Shift/All off and back on — this used to re-fetch with
    // status:null and, because loadAllSales set statusFilter as a side
    // effect, silently deselect "Refunded".
    await tester.tap(find.descendant(
      of: find.byType(SegmentedButton<bool>),
      matching: find.text('Shift'),
    ));
    await tester.pumpAndSettle();
    await _switchToAllSales(tester);

    expect(find.text('SR-3'), findsOneWidget);
    expect(find.text('SR-4'), findsOneWidget);
    expect(find.text('SR-1'), findsNothing);
    expect(find.text('SR-2'), findsNothing);
  });
}
