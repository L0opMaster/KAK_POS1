import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/modifier_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/cart_provider.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/cart_items_list.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/product_modifier_sheet.dart';

import 'test_l10n_helper.dart';

class _FakeCartNotifier {
  String? removedItemId;

  void removeItem(String id) => removedItemId = id;

  // Unused by this test but present because CartItemsList's `notifier` is
  // `dynamic` and other rows in the same list may call these.
  Future<CartMutationResult> setItemQuantity(String id, int qty) async =>
      const CartMutationResult.ok();
  void setItemNote(String id, String? note) {}
  void setItemDiscount(String id, double discount) {}
  void setItemModifiers(String id,
      {required List<SelectedModifier> selectedModifiers,
      required int qty,
      String? note}) {}
}

Product _productWithModifiers() => Product(
      id: 1,
      sku: 'SKU-1',
      barcode: '111',
      nameEn: 'Latte',
      nameKm: 'ឡាតេ',
      cost: 1,
      taxRate: 0,
      price: 3.5,
      active: true,
      categoryId: 1,
      modifierGroups: const [
        ModifierGroupResponse(
          id: 1,
          nameEn: 'Size',
          nameKm: 'ទំហំ',
          isRequired: false,
          multiSelect: false,
          active: true,
          displayOrder: 0,
        ),
      ],
    );

Product _productWithoutModifiers() => Product(
      id: 2,
      sku: 'SKU-2',
      barcode: '222',
      nameEn: 'Water',
      nameKm: 'ទឹក',
      cost: 0.2,
      taxRate: 0,
      price: 1,
      active: true,
      categoryId: 1,
    );

CartItem _cartItem(Product product, String id) => CartItem(
      id: id,
      product: product,
      qty: 1,
      addedAt: 0,
    );

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets(
      'cart row shows delete/modifier icons, not "Remove"/"Modifier" text',
      (tester) async {
    final notifier = _FakeCartNotifier();
    final items = [
      _cartItem(_productWithModifiers(), 'item-1'),
      _cartItem(_productWithoutModifiers(), 'item-2'),
    ];

    await tester.pumpWidget(
        _wrap(CartItemsList(items: items, notifier: notifier)));
    await tester.pumpAndSettle();

    expect(find.text('Remove'), findsNothing);
    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Modifiers'), findsNothing);

    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));
    // Only the item that actually has modifier groups gets the icon.
    expect(find.byIcon(Icons.tune), findsOneWidget);
  });

  testWidgets('delete icon tooltip is localized and calls removeItem',
      (tester) async {
    final notifier = _FakeCartNotifier();
    final item = _cartItem(_productWithoutModifiers(), 'item-42');

    await tester.pumpWidget(
        _wrap(CartItemsList(items: [item], notifier: notifier)));
    await tester.pumpAndSettle();

    final tooltipFinder = find.ancestor(
      of: find.byIcon(Icons.delete_outline),
      matching: find.byType(Tooltip),
    );
    expect(tooltipFinder, findsOneWidget);
    expect(tester.widget<Tooltip>(tooltipFinder).message, 'Remove');

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(notifier.removedItemId, 'item-42');
  });

  testWidgets(
      'modifier icon tooltip is localized and opens the modifier sheet',
      (tester) async {
    final notifier = _FakeCartNotifier();
    final item = _cartItem(_productWithModifiers(), 'item-7');

    await tester.pumpWidget(
        _wrap(CartItemsList(items: [item], notifier: notifier)));
    await tester.pumpAndSettle();

    final tooltipFinder = find.ancestor(
      of: find.byIcon(Icons.tune),
      matching: find.byType(Tooltip),
    );
    expect(tooltipFinder, findsOneWidget);
    expect(tester.widget<Tooltip>(tooltipFinder).message, 'Modifier');

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    // Tapping opens the same ProductModifierSheet the old text link did —
    // proves the underlying behavior (_editModifiers) is unchanged.
    expect(find.byType(ProductModifierSheet), findsOneWidget);
  });
}
