import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/modifier_models.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/widgets/product_modifier_sheet.dart';

import 'test_l10n_helper.dart';

Product _productWithModifiers() => Product(
      id: 1,
      sku: 'SKU1',
      barcode: 'BAR1',
      nameEn: 'Latte',
      nameKm: 'Latte',
      cost: 1,
      price: 4.0,
      active: true,
      categoryId: 1,
      modifierGroups: const [
        ModifierGroupResponse(
          id: 1,
          nameEn: 'Size',
          nameKm: 'Size',
          isRequired: true,
          multiSelect: false,
          active: true,
          displayOrder: 0,
          options: [
            ModifierOptionResponse(
                id: 10,
                nameEn: 'Small',
                nameKm: 'Small',
                priceDelta: 0,
                active: true,
                displayOrder: 0),
            ModifierOptionResponse(
                id: 11,
                nameEn: 'Large',
                nameKm: 'Large',
                priceDelta: 1.5,
                active: true,
                displayOrder: 1),
          ],
        ),
        ModifierGroupResponse(
          id: 2,
          nameEn: 'Toppings',
          nameKm: 'Toppings',
          isRequired: false,
          multiSelect: true,
          active: true,
          displayOrder: 1,
          options: [
            ModifierOptionResponse(
                id: 20,
                nameEn: 'Extra Shot',
                nameKm: 'Extra Shot',
                priceDelta: 0.75,
                active: true,
                displayOrder: 0),
          ],
        ),
      ],
    );

Future<CartItem?> _pumpAndConfirm(
    WidgetTester tester, Product product) async {
  CartItem? result;
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showModalBottomSheet<CartItem>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProductModifierSheet(product: product),
              );
            },
            child: const Text('open'),
          );
        }),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows every group and option', (tester) async {
    await _pumpAndConfirm(tester, _productWithModifiers());
    expect(find.text('Size'), findsOneWidget);
    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('Toppings'), findsOneWidget);
    expect(find.text('Extra Shot'), findsOneWidget);
  });

  testWidgets(
      'confirming without selecting a required option shows a validation '
      'error and does not close the sheet', (tester) async {
    final product = _productWithModifiers();
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showModalBottomSheet<CartItem>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProductModifierSheet(product: product),
              ),
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();

    expect(find.text('Please select an option for all required modifiers.'),
        findsOneWidget);
    expect(find.byType(ProductModifierSheet), findsOneWidget); // still open
  });

  testWidgets(
      'selecting a required option and confirming returns the right CartItem',
      (tester) async {
    final product = _productWithModifiers();
    final result = await _pumpAndConfirmWithSelection(tester, product);

    expect(result, isNotNull);
    expect(result!.product.id, 1);
    expect(result.qty, 1);
    expect(result.selectedModifiers.single.optionName, 'Large');
    expect(result.selectedModifiers.single.priceDelta, 1.5);
    expect(result.unitPrice, 4.0 + 1.5);
  });

  testWidgets('multi-select group allows more than one option at once',
      (tester) async {
    final product = _productWithModifiers();
    CartItem? result;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Scaffold(
          body: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                result = await showModalBottomSheet<CartItem>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ProductModifierSheet(product: product),
                );
              },
              child: const Text('open'),
            );
          }),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Small')); // satisfy the required group
    await tester.tap(find.text('Extra Shot')); // optional multi-select
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 1'));
    await tester.pumpAndSettle();

    expect(result!.selectedModifiers.length, 2);
    expect(result!.selectedModifiers.map((m) => m.optionName),
        containsAll(['Small', 'Extra Shot']));
  });
}

Future<CartItem?> _pumpAndConfirmWithSelection(
    WidgetTester tester, Product product) async {
  CartItem? result;
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      localizationsDelegates: testLocalizationsDelegates,
      supportedLocales: testSupportedLocales,
      home: Scaffold(
        body: Builder(builder: (context) {
          return ElevatedButton(
            onPressed: () async {
              result = await showModalBottomSheet<CartItem>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ProductModifierSheet(product: product),
              );
            },
            child: const Text('open'),
          );
        }),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Large'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add 1'));
  await tester.pumpAndSettle();
  return result;
}
