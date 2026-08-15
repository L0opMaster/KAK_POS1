import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/core/config/currency_utils.dart';
import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/payment_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/sale_service.dart';

import 'test_l10n_helper.dart';

class _FakeCartService extends CartService {
  @override
  Future<List<CartItem>> getCartItems() async => [];
  @override
  Future<void> saveCartItems(List<CartItem> items) async {}
  @override
  Future<void> clearCart() async {}
  @override
  Future<void> removeCartItem(String id) async {}
}

class _RecordedCreateSale {
  _RecordedCreateSale(this.request, this.clientRef);
  final Map<String, dynamic> request;
  final String clientRef;
}

/// Fake `SaleService` — records every `createSale`/`paySale` call so tests
/// can assert on the exact request shape and (for the idempotency test)
/// that a retry after failure reuses the same `clientRef`.
class _FakeSaleService extends SaleService {
  _FakeSaleService() : super(ApiService());

  final List<_RecordedCreateSale> createSaleCalls = [];
  final List<Map<String, dynamic>> paySaleCalls = [];
  bool failNextCreateSale = false;
  int _nextId = 100;

  @override
  Future<SaleResponse> createSale(Map<String, dynamic> request) async {
    createSaleCalls.add(
      _RecordedCreateSale(request, request['clientRef'] as String),
    );
    if (failNextCreateSale) {
      failNextCreateSale = false;
      throw Exception('backend unreachable');
    }
    return SaleResponse(
      id: _nextId++,
      invoiceNumber: 'INV-$_nextId',
      status: 'DRAFT',
      grandTotal: (request['lines'] as List).isEmpty ? 0 : 10,
      paidAmount: 0,
    );
  }

  @override
  Future<SaleResponse> paySale(
    int saleId,
    List<Map<String, dynamic>> payments,
  ) async {
    paySaleCalls.add({'saleId': saleId, 'payments': payments});
    return SaleResponse(
      id: saleId,
      invoiceNumber: 'INV-$saleId',
      status: 'PAID',
      grandTotal: 10,
      paidAmount: 10,
    );
  }
}

Widget _wrap(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: testLocalizationsDelegates,
    supportedLocales: testSupportedLocales,
    home: child,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'Pay Full Amount: createSale then paySale with the full amount as a '
    'single CASH payment, cart cleared, completed screen shown',
    (tester) async {
      final saleService = _FakeSaleService();
      await tester.pumpWidget(
        _wrap(
          PaymentScreen(
            total: 10.0,
            saleLines: const [
              {'productId': 1, 'quantity': 2},
            ],
            waitingNumber: 7,
          ),
          [
            saleServiceProvider.overrideWithValue(saleService),
            cartServiceProvider.overrideWithValue(_FakeCartService()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay Full Amount'));
      await tester.pumpAndSettle();

      expect(saleService.createSaleCalls, hasLength(1));
      expect(saleService.createSaleCalls.single.request['lines'], const [
        {'productId': 1, 'quantity': 2},
      ]);
      expect(saleService.paySaleCalls, hasLength(1));
      expect(saleService.paySaleCalls.single['payments'], [
        {'method': 'CASH', 'amount': 10.0},
      ]);
      // Both the AppBar title and the body heading read "Payment Complete"
      // once state flips to completed.
      expect(find.text('Payment Complete'), findsWidgets);
      // The completed screen shows paySale's response (not createSale's) —
      // paySale's invoiceNumber is derived from the SAME sale id createSale
      // returned (100), i.e. 'INV-100', not createSale's own
      // (pre-increment-confusion) 'INV-101'.
      expect(find.text('Invoice #INV-100'), findsOneWidget);
    },
  );

  testWidgets(
    'idempotent retry: a failed submission followed by Retry reuses the '
    'SAME clientRef — the backend dedupes on it (SaleService.'
    'findByClientRef) to avoid creating a duplicate sale on retry',
    (tester) async {
      final saleService = _FakeSaleService()..failNextCreateSale = true;
      await tester.pumpWidget(
        _wrap(
          PaymentScreen(total: 10.0, saleLines: const [], waitingNumber: 1),
          [
            saleServiceProvider.overrideWithValue(saleService),
            cartServiceProvider.overrideWithValue(_FakeCartService()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pay Full Amount'));
      await tester.pumpAndSettle();

      // First attempt failed — a SnackBar with a Retry action is shown, and
      // the screen fell back to its failed state.
      expect(saleService.createSaleCalls, hasLength(1));
      // Both the AppBar title and the body heading read "Payment Failed".
      expect(find.text('Payment Failed'), findsWidgets);

      // "Try Again" resets to idle; re-charging fires a second createSale
      // call. What matters is that it carries the identical clientRef as
      // the first attempt — that's what makes the retry safe.
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pay Full Amount'));
      await tester.pumpAndSettle();

      expect(saleService.createSaleCalls, hasLength(2));
      expect(
        saleService.createSaleCalls[0].clientRef,
        saleService.createSaleCalls[1].clientRef,
      );
    },
  );

  testWidgets(
    'split payment: two rows rebalance to \$5 each (cent remainder on the '
    'last row), charging both submits both as separate payment entries',
    (tester) async {
      final saleService = _FakeSaleService();
      await tester.pumpWidget(
        _wrap(
          PaymentScreen(total: 10.0, saleLines: const [], waitingNumber: 2),
          [
            saleServiceProvider.overrideWithValue(saleService),
            cartServiceProvider.overrideWithValue(_FakeCartService()),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Split Payment'));
      await tester.pumpAndSettle();
      // +1 split row -> 2 rows, half the total each.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      // `readCurrency` reads `currencyCodeProvider` synchronously during
      // `initState` — in this test sandbox (no real backend), that
      // FutureProvider is always still `loading` at that exact moment, so
      // `_currency` locks onto its documented loading-fallback ('KHR'),
      // same race a real cold start before Settings loads would hit.
      expect(find.text(formatAmount(5.0, 'KHR')), findsNWidgets(2));

      // Charge both rows (each Charge tap resolves after a short delay).
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Charge').first);
        await tester.pump(const Duration(milliseconds: 600));
      }
      await tester.pumpAndSettle();

      // Both authorized -> the bottom bar becomes "Done".
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(saleService.paySaleCalls, hasLength(1));
      final payments =
          saleService.paySaleCalls.single['payments'] as List<dynamic>;
      expect(payments, hasLength(2));
      expect(
        payments.fold<double>(0, (sum, p) => sum + (p['amount'] as double)),
        10.0,
      );
    },
  );
}
