import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/cart_footer.dart';

import 'test_l10n_helper.dart';

// minimal fake service used for provider; state is manipulated directly
class FakeCartService extends CartService {
  @override
  Future<void> clearCart() async {}

  @override
  Future<List<CartItem>> getCartItems() async => [];

  @override
  Future<void> removeCartItem(String id) async {}

  @override
  Future<void> saveCartItems(List<CartItem> items) async {}
}

void main() {
  testWidgets('CartFooter shows totals and handles adjustments',
      (tester) async {
    final container = ProviderContainer(overrides: [
      cartProvider.overrideWith((ref) => CartNotifier(FakeCartService(), ref)),
    ]);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: Scaffold(body: CartFooter()),
        ),
      ),
    );

    final CartNotifier cartNotifier = container.read(cartProvider.notifier);

    expect(find.textContaining('Total:'), findsOneWidget);
    expect(find.textContaining('Final:'), findsOneWidget);
    // no discount/loyalty texts or buttons initially
    expect(find.textContaining('Discount:'), findsNothing);
    expect(find.textContaining('Loyalty:'), findsNothing);
    expect(find.text('Clear Discount'), findsNothing);
    expect(find.text('Clear Loyalty'), findsNothing);

    // apply discount and loyalty through notifier
    cartNotifier.applyDiscount(5);
    cartNotifier.applyLoyalty(2);
    await tester.pumpAndSettle();

    expect(find.text('Discount: -\$5.00'), findsOneWidget);
    expect(find.text('Loyalty: -\$2.00'), findsOneWidget);
    expect(find.text('Clear Discount'), findsOneWidget);
    expect(find.text('Clear Loyalty'), findsOneWidget);

    // clear discount
    await tester.tap(find.text('Clear Discount'));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.discount, 0);
    expect(find.textContaining('Discount:'), findsNothing);

    // clear loyalty
    await tester.tap(find.text('Clear Loyalty'));
    await tester.pumpAndSettle();
    expect(cartNotifier.state.loyalty, 0);
    expect(find.textContaining('Loyalty:'), findsNothing);
  });
}
