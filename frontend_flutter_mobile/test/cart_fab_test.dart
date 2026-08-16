import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/screens/cart_screen.dart';
import 'package:frontend_flutter_mobile/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/waiting_number_service.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/cart_fab.dart';

import 'test_l10n_helper.dart';

/// Covers what `pos_register_screen_test.dart` used to assert about
/// `CartSummaryBar` before it was replaced by this FAB (see
/// `CartFab`'s own doc comment) — icon-only (no badge/total) when empty so
/// `CartScreen`'s empty-cart "Open Held Tickets" button stays reachable,
/// shows the live count/total when the cart has items, tap navigates to
/// `CartScreen` either way.
///
/// Pins the notifier's state directly rather than letting the real
/// constructor's fire-and-forget `restoreCart()` (async SharedPreferences
/// read) win the race and stomp it back to `CartState.initial()` — the
/// `restoreCart` override below makes that call a no-op instead.
class _FixedCartNotifier extends CartNotifier {
  _FixedCartNotifier(this._fixedState, super.service, super.waitingNumberService, super.ref) {
    state = _fixedState;
  }

  final CartState _fixedState;

  @override
  Future<void> restoreCart() async {}
}

Product _product(int id) => Product(
      id: id,
      sku: 'SKU$id',
      barcode: 'BAR$id',
      nameEn: 'Product $id',
      nameKm: 'Product $id',
      cost: 1,
      price: 5.0,
      active: true,
      categoryId: 1,
    );

CartItem _item(int id, {int qty = 1}) =>
    CartItem(id: 'item-$id', product: _product(id), qty: qty, addedAt: 0);

Widget _wrap(CartState cartState) => ProviderScope(
      overrides: [
        cartProvider.overrideWith((ref) => _FixedCartNotifier(
              cartState,
              LocalCartService(),
              WaitingNumberService(),
              ref,
            )),
      ],
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: const Scaffold(
          body: SizedBox.shrink(),
          floatingActionButton: CartFab(),
        ),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'shows an icon-only FAB (no badge/total) when the cart is empty',
      (tester) async {
    await tester.pumpWidget(_wrap(CartState.initial()));
    await tester.pumpAndSettle();

    expect(find.byType(CartFab), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byType(Badge), findsNothing);
  });

  testWidgets('shows item count and total when the cart has items',
      (tester) async {
    // taxRate: 0 keeps finalTotal == subtotal, so the assertion below
    // isolates the FAB's own formatting from CartState's tax calculation.
    final state = CartState.initial().copyWith(
        items: [_item(1, qty: 2), _item(2)], taxRate: 0);
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('3'), findsOneWidget); // 2 + 1 items
    // KHR formats with zero decimals + thousands grouping.
    expect(find.text('៛15'), findsOneWidget); // (5 x 2) + (5 x 1)
  });

  testWidgets('tapping the FAB navigates to CartScreen', (tester) async {
    final state = CartState.initial().copyWith(items: [_item(1)]);
    await tester.pumpWidget(_wrap(state));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(CartScreen), findsOneWidget);
  });

  testWidgets('tapping the empty-cart FAB still navigates to CartScreen',
      (tester) async {
    await tester.pumpWidget(_wrap(CartState.initial()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(CartScreen), findsOneWidget);
  });
}
