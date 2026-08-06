import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/features/pos/screens/item_management_screen.dart';
import 'package:frontend_flutter_pos/features/pos/providers/product_provider.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/product_grid.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';

import 'test_l10n_helper.dart';

/// A fake product service that returns a fixed list of products or throws.
/// It can also supply mock categories when needed by the UI.
class FakeProductService extends ProductService {
  final List<Product> products;
  final bool shouldFail;
  final List<Category> categories;
  FakeProductService({
    this.products = const [],
    this.shouldFail = false,
    this.categories = const [],
  });

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 20,
  }) async {
    if (shouldFail) throw Exception('failure');
    return products;
  }

  @override
  Future<List<Category>> getCategories() async => categories;

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async => [];

  @override
  Future<List<Product>> getLowStockProducts() async => [];

  @override
  Future<Product> createProduct(Product product) async => product;

  @override
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<void> deleteProduct(int id) async {}
}

/// Mutable fake that stores created products and returns them on getProducts
class _MutableFakeProductService extends ProductService {
  final List<Product> _store = [];
  final List<Product> createdProducts = [];
  final List<Category> categories = [];

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 20,
  }) async {
    return _store;
  }

  @override
  Future<Product> createProduct(Product product) async {
    final created = product.copyWith(id: _store.length + 1);
    _store.add(created);
    createdProducts.add(created);
    return created;
  }

  @override
  Future<Product> updateProduct(Product product) async {
    final index = _store.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _store[index] = product;
    }
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {
    _store.removeWhere((p) => p.id == id);
  }

  @override
  Future<List<Category>> getCategories() async => categories;

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async => [];

  @override
  Future<List<Product>> getLowStockProducts() async => [];
}

void main() {
  testWidgets('ItemManagementScreen shows loading and data', (tester) async {
    final service = FakeProductService(
        products: [Product.sample(), Product.sample().copyWith(id: 2)]);
    await tester.pumpWidget(ProviderScope(
      overrides: [productServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ItemManagementScreen(),
      ),
    ));

    // initial loading state
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    // after load the grid should appear
    expect(find.byType(ProductGrid), findsOneWidget);
    expect(find.text('Sample Product'), findsNWidgets(2));
  });

  testWidgets('ItemManagementScreen displays error', (tester) async {
    final service = FakeProductService(shouldFail: true);
    await tester.pumpWidget(ProviderScope(
      overrides: [productServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ItemManagementScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Error:'), findsOneWidget);
  });

  testWidgets('Add product dialog creates and reloads list', (tester) async {
    // service maintains a list
    final service = _MutableFakeProductService();
    await tester.pumpWidget(ProviderScope(
      overrides: [productServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ItemManagementScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // initially empty
    expect(find.byType(ProductGrid), findsNothing);

    // open dialog
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // fill in values
    await tester.enterText(find.byType(TextField).first, 'NewProd');
    await tester.enterText(find.byType(TextField).last, '3.50');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // service should have received create request, and grid should show product
    expect(service.createdProducts, hasLength(1));
    expect(find.text('NewProd'), findsOneWidget);
  });

  testWidgets('Tapping product allows editing', (tester) async {
    final service = _MutableFakeProductService();
    // seed with one product
    final initial =
        Product.sample().copyWith(id: 1, nameEn: 'OldName', price: 5);
    await service.createProduct(initial);

    await tester.pumpWidget(ProviderScope(
      overrides: [productServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ItemManagementScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // grid shows initial product
    expect(find.text('OldName'), findsOneWidget);

    // tap tile to edit
    await tester.tap(find.text('OldName'));
    await tester.pumpAndSettle();

    // dialog should appear with existing name
    expect(find.text('Edit Product'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'OldName'), findsOneWidget);

    // change name and price
    await tester.enterText(find.byType(TextField).first, 'Updated');
    await tester.enterText(find.byType(TextField).last, '7.25');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // service should reflect update, and grid shows new name
    expect(service._store.first.nameEn, 'Updated');
    expect(find.text('Updated'), findsOneWidget);
  });

  testWidgets('Tapping delete icon removes product', (tester) async {
    final service = _MutableFakeProductService();
    final initial = Product.sample().copyWith(id: 1, nameEn: 'ToDelete');
    await service.createProduct(initial);

    await tester.pumpWidget(ProviderScope(
      overrides: [productServiceProvider.overrideWithValue(service)],
      child: const MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: ItemManagementScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    // icon button should be present on the tile (delete overlay)
    final deleteIcon = find.byIcon(Icons.delete);
    expect(deleteIcon, findsOneWidget);

    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    // confirm dialog appears
    expect(find.text('Delete Product'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // item removed and snackbar shown
    expect(service._store, isEmpty);
    expect(find.text('ToDelete'), findsNothing);
    expect(find.textContaining('Deleted ToDelete'), findsOneWidget);
  });
}
