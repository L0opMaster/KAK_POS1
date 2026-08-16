import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/utils/khmer_text_scaler.dart';
import 'package:frontend_flutter_pos/features/pos/models/cart_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/modifier_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/cart_items_list.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/category_tabs.dart';

import 'test_l10n_helper.dart';

class _FakeCartNotifier {
  void removeItem(String id) {}
  void setItemQuantity(String id, int qty) {}
  void setItemNote(String id, String? note) {}
  void setItemDiscount(String id, double discount) {}
  void setItemModifiers(String id,
      {required List<SelectedModifier> selectedModifiers,
      required int qty,
      String? note}) {}
}

/// Mirrors main.dart's `MaterialApp.builder` wiring, at a narrow mobile
/// portrait width, so regressions from the +2/3px Khmer bump show up as
/// RenderFlex overflow exceptions here instead of only in production.
Widget _khmerApp(Widget home) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('km'),
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: khmerAwareTextScaler(
              MediaQuery.of(context).textScaler,
              isKhmer: true,
            ),
          ),
          child: child!,
        ),
        home: home,
      ),
    );

Future<void> _pumpNarrow(WidgetTester tester, Widget home,
    {double width = 360}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_khmerApp(home));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'CartItemsList (Khmer, +2/3px, 360px width) renders without overflow',
      (tester) async {
    final product = Product(
      id: 1,
      sku: 'SKU-1',
      barcode: '111',
      nameEn: 'Iced Caramel Macchiato with Extra Shot',
      nameKm: 'កាហ្វេម៉ាគាទីតទឹកកកជាមួយម្សៅបន្ថែម',
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
    final items = [
      CartItem(id: 'i1', product: product, qty: 1, addedAt: 0),
    ];

    await _pumpNarrow(
      tester,
      Scaffold(
        body: CartItemsList(items: items, notifier: _FakeCartNotifier()),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('CategoryTabs (Khmer, +2/3px, 360px width) renders without overflow',
      (tester) async {
    final categories = [
      Category(
          id: 1,
          nameEn: 'Coffee',
          nameKm: 'កាហ្វេនិងភេសជ្ជៈត្រជាក់ពិសេស',
          active: true),
      Category(id: 2, nameEn: 'Tea', nameKm: 'តែ', active: true),
      Category(id: 3, nameEn: 'Snacks', nameKm: 'អាហារសម្រន់', active: true),
    ];

    await _pumpNarrow(
      tester,
      Scaffold(
        body: CategoryTabs(
          categories: categories,
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
