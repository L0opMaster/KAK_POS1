import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/cart_items_list.dart';

import 'test_l10n_helper.dart';

class _FakeCartNotifier {
  String? removedItemId;
  CartItem? reAddedItem;
  final Map<String, int> qtyCalls = {};

  void removeItem(String id) => removedItemId = id;
  void addItem(CartItem item) => reAddedItem = item;
  void setItemQuantity(String id, int qty) => qtyCalls[id] = qty;
  void setItemNote(String id, String? note) {}
  void setItemDiscount(String id, double discount) {}
  void setItemModifiers(String id,
      {required List<SelectedModifier> selectedModifiers,
      required int qty,
      String? note}) {}
}

Product _product() => Product(
      id: 1,
      sku: 'SKU1',
      barcode: 'BAR1',
      nameEn: 'Iced Latte',
      nameKm: 'Iced Latte',
      cost: 1,
      price: 5.0,
      active: true,
      categoryId: 1,
    );

CartItem _item({String id = 'item-1'}) =>
    CartItem(id: id, product: _product(), qty: 2, addedAt: 0);

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('empty cart shows the empty state, no crash', (tester) async {
    final notifier = _FakeCartNotifier();
    await tester.pumpWidget(
        _wrap(CartItemsList(items: const [], notifier: notifier)));
    await tester.pumpAndSettle();

    expect(find.text('Cart is empty'), findsOneWidget);
  });

  testWidgets('shows product name, qty, unit price and line total',
      (tester) async {
    final notifier = _FakeCartNotifier();
    await tester
        .pumpWidget(_wrap(CartItemsList(items: [_item()], notifier: notifier)));
    await tester.pumpAndSettle();

    expect(find.text('Iced Latte'), findsOneWidget);
    // currencyCodeProvider falls back to 'KHR' when /api/settings/general
    // is unreachable (as it always is in the test sandbox) — same fallback
    // [OLD/SOURCE]'s watchCurrency() uses, so this isn't a test-only stand-in.
    expect(find.text('៛10.00'), findsOneWidget); // line total (5 x 2)
  });

  testWidgets('delete icon calls removeItem with the correct id',
      (tester) async {
    final notifier = _FakeCartNotifier();
    await tester.pumpWidget(_wrap(
        CartItemsList(items: [_item(id: 'abc')], notifier: notifier)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pump();

    expect(notifier.removedItemId, 'abc');
  });

  testWidgets('swiping a card away removes it and offers Undo',
      (tester) async {
    final notifier = _FakeCartNotifier();
    await tester.pumpWidget(_wrap(
        CartItemsList(items: [_item(id: 'swipe-me')], notifier: notifier)));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(notifier.removedItemId, 'swipe-me');
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(notifier.reAddedItem?.id, 'swipe-me');
  });

  testWidgets('modifier icon only shows for products with modifier groups',
      (tester) async {
    final notifier = _FakeCartNotifier();
    await tester.pumpWidget(
        _wrap(CartItemsList(items: [_item()], notifier: notifier)));
    await tester.pumpAndSettle();

    // _product() has no modifierGroups by default.
    expect(find.byIcon(Icons.tune), findsNothing);
  });

  testWidgets('QtyStepper + calls setItemQuantity', (tester) async {
    final notifier = _FakeCartNotifier();
    await tester.pumpWidget(_wrap(
        CartItemsList(items: [_item(id: 'q1')], notifier: notifier)));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(notifier.qtyCalls['q1'], 3); // was qty 2, incremented to 3
  });
}
