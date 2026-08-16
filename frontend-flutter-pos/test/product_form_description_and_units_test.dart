// Regression coverage for two product-form bugs:
// 1. The description field was initialized from the product's Khmer name
//    (`p.nameKm`) instead of an actual description, and whatever the user
//    typed was never included in the save payload at all.
// 2. The form has no UI for parent product / sale / purchase / stock
//    units, but building a *new* Product object in _save() rather than
//    carrying the existing one's values forward meant every edit silently
//    wiped them (the backend treats a missing unit id as "reset to
//    default", and a missing parentProductId as "clear the parent link").
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/modifier_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/models/unit_models.dart';
import 'package:frontend_flutter_pos/features/pos/screens/item_management_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/category_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/modifier_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/unit_service.dart';

import 'test_l10n_helper.dart';

class _FakeCategoryService extends CategoryService {
  _FakeCategoryService() : super(ApiService());
  @override
  Future<List<Category>> list() async => [];
}

Unit _unit(int id, String code) => Unit(
      id: id,
      code: code,
      name: code,
      nameEn: code,
      nameKm: code,
      symbol: code,
      baseUnitGroup: 'count',
      baseUnit: true,
      conversionFactor: 1,
      active: true,
    );

class _FakeUnitService extends UnitService {
  _FakeUnitService(this.units) : super(ApiService());
  final List<Unit> units;

  @override
  Future<List<Unit>> list({
    String query = '',
    bool? active,
    int page = 0,
    int size = 200,
  }) async =>
      units;
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
  Future<Product> createProduct(Product product) async => product.copyWith(id: 99);
  @override
  Future<Product> updateProduct(Product product) async {
    updated = product;
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {}
}

void main() {
  Widget buildForm(
    _FakeProductService service, {
    Product? product,
    List<Unit> units = const [],
  }) =>
      ProviderScope(
        overrides: [
          categoryServiceProvider.overrideWithValue(_FakeCategoryService()),
          modifierServiceProvider.overrideWithValue(_FakeModifierService()),
          productServiceProvider.overrideWithValue(service),
          unitServiceProvider.overrideWithValue(_FakeUnitService(units)),
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
      'editing a product loads the description field, not the Khmer name',
      (tester) async {
    final product = Product(
      id: 5,
      sku: 'SKU5',
      barcode: 'BC5',
      nameEn: 'Donuts',
      nameKm: 'នំដូណាត់',
      description: 'Glazed ring donuts, six pack',
      cost: 1,
      taxRate: 0,
      price: 2,
      active: true,
      categoryId: 1,
    );
    final service = _FakeProductService();
    await tester.pumpWidget(buildForm(service, product: product));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.text('Glazed ring donuts, six pack'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Glazed ring donuts, six pack'), findsOneWidget);
    // The Khmer name field legitimately shows this text too — the bug was
    // the description field ALSO showing it (a second occurrence). Exactly
    // one occurrence means only the real Khmer Name field has it.
    expect(find.text('នំដូណាត់'), findsOneWidget);
  });

  testWidgets(
      'saving an edit preserves parentProductId (no UI for it) and the '
      "product's existing units even before the unit list has loaded",
      (tester) async {
    final product = Product(
      id: 7,
      sku: 'SKU7',
      barcode: 'BC7',
      nameEn: 'Iced Coffee — Large',
      nameKm: 'កាហ្វេទឹកកក ធំ',
      cost: 1,
      taxRate: 0,
      price: 3,
      active: true,
      categoryId: 1,
      parentProductId: 3,
      saleUnitId: 11,
      purchaseUnitId: 12,
      stockUnitId: 13,
      variantLabel: 'Large',
    );
    final service = _FakeProductService();
    // No units seeded here — proves the earlier crash (DropdownButtonFormField
    // throws if initialValue doesn't match any item) is actually fixed, not
    // just untested: _safeUnitValue must fall back to null in the dropdown
    // itself while _saleUnitId/etc. still carry the real value through to save.
    await tester.pumpWidget(buildForm(service, product: product));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Save'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.updated, isNotNull);
    expect(service.updated!.parentProductId, 3);
    expect(service.updated!.saleUnitId, 11);
    expect(service.updated!.purchaseUnitId, 12);
    expect(service.updated!.stockUnitId, 13);
    expect(service.updated!.variantLabel, 'Large');
  });

  testWidgets(
      'the Sale Unit dropdown shows the current unit and can be changed, '
      'saving the new selection', (tester) async {
    final units = [_unit(1, 'EACH'), _unit(2, 'BOX')];
    final product = Product(
      id: 9,
      sku: 'SKU9',
      barcode: 'BC9',
      nameEn: 'Bottled Water',
      nameKm: 'ទឹកដប',
      cost: 1,
      taxRate: 0,
      price: 2,
      active: true,
      categoryId: 1,
      saleUnitId: 1,
    );
    final service = _FakeProductService();
    await tester.pumpWidget(buildForm(service, product: product, units: units));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('EACH (EACH)'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('EACH (EACH)'), findsOneWidget);

    await tester.tap(find.text('EACH (EACH)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BOX (BOX)').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Save'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.updated?.saleUnitId, 2);
  });

  testWidgets('the Product Type dropdown defaults to the product\'s '
      'existing type and can be changed', (tester) async {
    final product = Product(
      id: 8,
      sku: 'SKU8',
      barcode: 'BC8',
      nameEn: 'Flour',
      nameKm: 'ម្សៅ',
      cost: 1,
      taxRate: 0,
      price: 0,
      active: true,
      categoryId: 1,
      productType: 'SALE_ITEM',
    );
    final service = _FakeProductService();
    await tester.pumpWidget(buildForm(service, product: product));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Sale Item'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Sale Item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingredient').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Save'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.updated?.productType, 'INGREDIENT');
  });
}
