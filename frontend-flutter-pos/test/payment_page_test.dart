import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/screens/payment_page.dart';

void main() {
  // helper to build the cart override, capturing the created notifier so
  // tests can drive it directly (applyDiscount/applyLoyalty/state).
  Override makeCartOverride(void Function(CartNotifier) capture) {
    final initialItems = [
      CartItem.sample(),
      CartItem(
        id: 'item2',
        product: Product.sample().copyWith(price: 5.0),
        qty: 1,
        addedAt: 0,
      ),
    ];
    return cartProvider.overrideWith((ref) {
      final notifier = CartNotifier(FakeCartService(initialItems), ref);
      capture(notifier);
      return notifier;
    });
  }

  testWidgets('PaymentPage split bill clears cart when used', (tester) async {
    late CartNotifier notifier;

    await tester.pumpWidget(ProviderScope(
      overrides: [makeCartOverride((n) => notifier = n)],
      child: const MaterialApp(home: PaymentPage()),
    ));
    await notifier.loadCart();
    await tester.pumpAndSettle();

    // apply a couple of discounts to exercise final total logic
    notifier.applyDiscount(5.0);
    await tester.pumpAndSettle();
    notifier.applyLoyalty(2.0);
    await tester.pumpAndSettle();

    // capture the final total now that all discounts are applied
    final finalTotalValue = notifier.state.finalTotal;

    // split bill flow
    final splitButton = find.text('Split Bill');
    expect(splitButton, findsOneWidget);
    await tester.tap(splitButton);
    await tester.pumpAndSettle();
    expect(find.text('Number of ways'), findsOneWidget);

    // increase splits twice (2 -> 4)
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final amount = (finalTotalValue / 4).toStringAsFixed(2);
    expect(find.text('Split into 4 x \$${amount}'), findsOneWidget);
    expect(notifier.state.items, isEmpty);
  });

  testWidgets('PaymentPage Pay Full clears cart and shows snackbar',
      (tester) async {
    late CartNotifier notifier;

    await tester.pumpWidget(ProviderScope(
      overrides: [makeCartOverride((n) => notifier = n)],
      child: const MaterialApp(home: PaymentPage()),
    ));
    await notifier.loadCart();
    await tester.pumpAndSettle();

    // apply discounts for completeness
    notifier.applyDiscount(5.0);
    await tester.pumpAndSettle();
    notifier.applyLoyalty(2.0);
    await tester.pumpAndSettle();

    final fullButton = find.text('Pay Full');
    expect(fullButton, findsOneWidget);
    await tester.tap(fullButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('Pay full amount:'), findsOneWidget);
    expect(notifier.state.items, isEmpty);
  });
}

// A trivial fake cart service that can return a preset list of items.
class FakeCartService extends CartService {
  final List<CartItem> _initial;
  FakeCartService([this._initial = const []]);

  @override
  Future<void> clearCart() async {}

  @override
  Future<List<CartItem>> getCartItems() async => _initial;

  @override
  Future<void> removeCartItem(String id) async {}

  @override
  Future<void> saveCartItems(List<CartItem> items) async {}
}
