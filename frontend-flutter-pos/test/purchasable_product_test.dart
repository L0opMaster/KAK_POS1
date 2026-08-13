// Regression coverage for "<product> is not allowed for purchasing":
// PurchasingWorkflowService rejects a PO line unless the product is BOTH
// purchasable AND trackInventory, but (1) the product form had no UI
// control for `purchasable` at all — the state field existed and was
// wired into the save payload, but no widget ever let a user set it — and
// (2) the Purchase Order product dropdown offered every product
// regardless, so a doomed selection only failed on Save. Covers both.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/inventory/screens/create_purchase_order.dart';
import 'package:frontend_flutter_pos/features/pos/models/modifier_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/product_provider.dart';
import 'package:frontend_flutter_pos/features/pos/screens/item_management_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/category_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/modifier_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';

import 'test_l10n_helper.dart';

class _FakeCategoryService extends CategoryService {
  _FakeCategoryService() : super(ApiService());
  @override
  Future<List<Category>> list() async => [];
}

class _FakeModifierService implements ModifierService {
  @override
  Future<List<ModifierGroupResponse>> getGroups() async => [];
  @override
  Future<ModifierGroupResponse> createGroup(ModifierGroupRequest request) =>
      throw UnimplementedError();
  @override
  Future<ModifierGroupResponse> updateGroup(
          {required int groupId, required ModifierGroupRequest request}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteGroup(int groupId) => throw UnimplementedError();
  @override
  Future<ModifierOptionResponse> addOption(
          {required int groupId, required ModifierOptionRequest request}) =>
      throw UnimplementedError();
  @override
  Future<ModifierOptionResponse> updateOption(
          {required int optionId, required ModifierOptionRequest request}) =>
      throw UnimplementedError();
  @override
  Future<void> deleteOption(int optionId) => throw UnimplementedError();
  @override
  Future<List<int>> getGroupProducts(int groupId) async => [];
  @override
  Future<void> updateGroupProducts(
          {required int groupId, required List<int> productIds}) =>
      throw UnimplementedError();
  @override
  Future<List<ProductModifiersResponse>> getProductModifiers(
          int productId) async =>
      [];
}

class _FakeProductService extends ProductService {
  Product? created;
  Product? updated;

  @override
  Future<List<Product>> getProducts(
          {String? query, int? categoryId, int page = 0, int size = 20}) async =>
      [];
  @override
  Future<List<Category>> getCategories() async => [];
  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async => [];
  @override
  Future<List<Product>> getLowStockProducts() async => [];
  @override
  Future<Product> createProduct(Product product) async {
    created = product;
    return product.copyWith(id: 99);
  }

  @override
  Future<Product> updateProduct(Product product) async {
    updated = product;
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {}
}

void main() {
  group('ProductFormScreen — Purchasable toggle', () {
    Widget buildForm({Product? product}) => ProviderScope(
          overrides: [
            categoryServiceProvider.overrideWithValue(_FakeCategoryService()),
            modifierServiceProvider.overrideWithValue(_FakeModifierService()),
            productServiceProvider.overrideWithValue(_FakeProductService()),
          ],
          child: MaterialApp(
            localizationsDelegates: testLocalizationsDelegates,
            supportedLocales: testSupportedLocales,
            home: ProductFormScreen(
              isEdit: product != null,
              product: product,
            ),
          ),
        );

    testWidgets(
        'is hidden for a new product until Track inventory is turned on',
        (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      // The form is longer than the default test viewport, so sections
      // below the fold aren't mounted until the ListView is scrolled to
      // them.
      await tester.scrollUntilVisible(find.text('Track inventory'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Allow purchasing from supplier'), findsNothing);

      await tester.tap(find.text('Track inventory'));
      await tester.pumpAndSettle();

      expect(find.text('Allow purchasing from supplier'), findsOneWidget);
    });

    testWidgets(
        'turning Track inventory back off clears a previously-enabled '
        'Purchasable value, not just hides it', (tester) async {
      await tester.pumpWidget(buildForm());
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Track inventory'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Track inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Allow purchasing from supplier'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(
                SwitchListTile, 'Allow purchasing from supplier'))
            .value,
        isTrue,
      );

      // Off then back on: if the underlying flag weren't actually reset,
      // it would still show enabled here.
      await tester.tap(find.text('Track inventory'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track inventory'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(
                SwitchListTile, 'Allow purchasing from supplier'))
            .value,
        isFalse,
      );
    });

    testWidgets('an existing purchasable product loads with the toggle on',
        (tester) async {
      final product = Product.sample().copyWith(
        id: 5,
        nameEn: 'Donuts',
        trackInventory: true,
        purchasable: true,
      );
      await tester.pumpWidget(buildForm(product: product));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
          find.text('Allow purchasing from supplier'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(
        tester
            .widget<SwitchListTile>(find.widgetWithText(
                SwitchListTile, 'Allow purchasing from supplier'))
            .value,
        isTrue,
      );
    });
  });

  group('CreatePurchaseOrder — product dropdown', () {
    testWidgets(
        'only offers products that are both purchasable and trackInventory',
        (tester) async {
      final purchasableProduct = Product.sample().copyWith(
        id: 1,
        nameEn: 'Coca-Cola (Can)',
        purchasable: true,
        trackInventory: true,
      );
      final madeToOrderProduct = Product.sample().copyWith(
        id: 2,
        nameEn: 'Iced Coffee',
        purchasable: false,
        trackInventory: false,
      );
      final inconsistentProduct = Product.sample().copyWith(
        id: 3,
        nameEn: 'Half-Configured Item',
        purchasable: true,
        trackInventory: false,
      );

      final fakeProductService = _FakeProductService();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          productServiceProvider.overrideWithValue(fakeProductService),
        ],
        child: const MaterialApp(
          localizationsDelegates: testLocalizationsDelegates,
          supportedLocales: testSupportedLocales,
          home: CreatePurchaseOrder(),
        ),
      ));
      await tester.pumpAndSettle();

      // Seed the shared products provider directly (loadProducts() already
      // ran against the fake service and returned []) so the dropdown has
      // a mix of purchasable/non-purchasable/inconsistent products to
      // filter, without needing a real backend.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CreatePurchaseOrder)),
      );
      container.read(productsProvider.notifier).state = ProductState(
        products: [purchasableProduct, madeToOrderProduct, inconsistentProduct],
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<Product>,
          'Product').first);
      await tester.pumpAndSettle();

      expect(find.text('Coca-Cola (Can)'), findsOneWidget);
      expect(find.text('Iced Coffee'), findsNothing);
      expect(find.text('Half-Configured Item'), findsNothing);
    });
  });
}
