import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/print_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/sale_service.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/credit_repayment_dialog.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations.dart';

/// Records the last `repayCreditSale` call and returns a canned "fully
/// repaid" response, so tests can assert on both the request the dialog
/// sent and how it reacts to the response.
class _FakeSaleService extends SaleService {
  _FakeSaleService() : super(ApiService());

  int? lastSaleId;
  double? lastAmount;
  String? lastMethod;
  String? lastNotes;
  Object? throwOnRepay;

  @override
  Future<SaleResponse> repayCreditSale(
    int saleId, {
    required double amount,
    required String method,
    String? notes,
  }) async {
    lastSaleId = saleId;
    lastAmount = amount;
    lastMethod = method;
    lastNotes = notes;
    if (throwOnRepay != null) throw throwOnRepay!;
    return SaleResponse(
      id: saleId,
      status: 'PAID',
      grandTotal: 100,
      paidAmount: 100,
    );
  }
}

/// Avoids exercising the real printer/SharedPreferences plumbing in a
/// widget test — the dialog treats printing as best-effort regardless.
class _FakePrintService extends PrintService {
  _FakePrintService() : super(ApiService(), _NoopRef());

  @override
  Future<bool> printCreditPaymentReceipt(
    BuildContext context, {
    required String creditSaleNumber,
    required String customerName,
    required double amount,
    required double previousBalance,
    required double remainingBalance,
    DateTime? dueDate,
    required String method,
    String? cashierName,
    String currency = 'KHR',
  }) async =>
      true;
}

class _NoopRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required SaleResponse sale,
  required _FakeSaleService fakeSaleService,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        saleServiceProvider.overrideWithValue(fakeSaleService),
        printServiceProvider.overrideWithValue(_FakePrintService()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () =>
                  showCreditRepaymentDialog(context, ref, sale: sale),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  final creditSale = SaleResponse(
    id: 42,
    invoiceNumber: 'INV-2026-00042',
    status: 'CREDIT',
    grandTotal: 100,
    paidAmount: 30, // remaining = 70
    customerName: 'Sok Dara',
  );

  testWidgets('rejects a zero/empty amount', (tester) async {
    final fake = _FakeSaleService();
    await _pumpDialog(tester, sale: creditSale, fakeSaleService: fake);

    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid amount'), findsOneWidget);
    expect(fake.lastAmount, isNull, reason: 'must not call the backend');
  });

  testWidgets('rejects an amount greater than the remaining balance',
      (tester) async {
    final fake = _FakeSaleService();
    await _pumpDialog(tester, sale: creditSale, fakeSaleService: fake);

    await tester.enterText(find.byType(TextField).first, '999');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(find.text('Amount exceeds remaining balance'), findsOneWidget);
    expect(fake.lastAmount, isNull);
  });

  testWidgets('"Pay Full Balance" prefills the exact remaining amount',
      (tester) async {
    final fake = _FakeSaleService();
    await _pumpDialog(tester, sale: creditSale, fakeSaleService: fake);

    await tester.tap(find.text('Pay Full Balance'));
    await tester.pumpAndSettle();

    expect(find.text('70.00'), findsOneWidget);
  });

  testWidgets(
      "uses the sale's own currency, not the app-wide default (regression)",
      (tester) async {
    // The live app-wide currency provider is unconfigured in this test
    // harness and falls back to zero-decimal KHR — if the dialog used that
    // instead of `sale.currency`, a USD amount like 2.70 would render
    // rounded as "3" (see credit_repayment_dialog.dart's `_confirm`/`build`
    // doc comments for the bug this guards against).
    final usdSale = SaleResponse(
      id: 7,
      invoiceNumber: 'INV-2026-00007',
      status: 'CREDIT',
      grandTotal: 5.70,
      paidAmount: 3.0, // remaining = 2.70
      customerName: 'Sok Dara',
      currency: 'USD',
    );
    final fake = _FakeSaleService();
    await _pumpDialog(tester, sale: usdSale, fakeSaleService: fake);

    expect(find.text(r'$2.70'), findsOneWidget,
        reason: 'Remaining Balance must show the sale\'s USD cents, not '
            'KHR-rounded');

    await tester.tap(find.text('Pay Full Balance'));
    await tester.pumpAndSettle();

    expect(find.text('2.70'), findsOneWidget);
  });

  testWidgets('confirms a valid partial payment and calls the service',
      (tester) async {
    final fake = _FakeSaleService();
    await _pumpDialog(tester, sale: creditSale, fakeSaleService: fake);

    await tester.enterText(find.byType(TextField).first, '25');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(fake.lastSaleId, 42);
    expect(fake.lastAmount, 25.0);
    expect(fake.lastMethod, 'CASH');
  });

  testWidgets('shows the backend error message and keeps the dialog open on failure',
      (tester) async {
    final fake = _FakeSaleService()
      ..throwOnRepay = ApiException('Repayment exceeds remaining balance');
    await _pumpDialog(tester, sale: creditSale, fakeSaleService: fake);

    await tester.enterText(find.byType(TextField).first, '50');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Payment failed'), findsOneWidget);
    // Dialog is still open — cashier can retry, nothing was silently lost.
    expect(find.text('Record Payment'), findsOneWidget);
  });
}
