import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend_flutter_pos/features/pos/screens/pos_screen.dart';
import 'package:frontend_flutter_pos/features/pos/services/cart_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/product_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/product_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/product_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/demo_product_service.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_selection_provider.dart';
import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/core/config/app_config.dart';

import 'test_l10n_helper.dart';

/// Minimal fake that records POST/GET calls used by ApiCartService.
class FakeApiService extends ApiService {
  final List<String> calls = [];
  final Map<String, dynamic> _get = {};
  final Map<String, dynamic> _post = {};
  final Map<String, dynamic> _delete = {};

  void whenGet(String path, dynamic resp) => _get[path] = resp;
  void whenPost(String path, dynamic resp) => _post[path] = resp;
  void whenDelete(String path, dynamic resp) => _delete[path] = resp;

  @override
  Future<T> get<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('GET $path');
    if (_get.containsKey(path)) return _get[path] as T;
    return Future.value({} as T);
  }

  @override
  Future<T> post<T>(String path,
      {Object? data,
      Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    // include payload string for easier inspection
    calls.add('POST $path ${data ?? ''}');
    if (_post.containsKey(path)) return _post[path] as T;
    return Future.value({} as T);
  }

  @override
  Future<T> delete<T>(String path,
      {Map<String, dynamic>? queryParameters,
      T Function(Object? data)? fromJson}) async {
    calls.add('DELETE $path');
    if (_delete.containsKey(path)) return _delete[path] as T;
    return Future.value({} as T);
  }
}

// simple fake product service reused from other tests (now supports categories)
class FakeProductService extends ProductService {
  final List<Product> _list;
  final List<Category> _categories;
  FakeProductService(this._list, {List<Category>? categories})
      : _categories = categories ?? [];

  @override
  Future<List<Product>> getProducts(
      {String? query, int? categoryId, int page = 0, int size = 100}) async {
    return _list;
  }

  @override
  Future<List<Category>> getCategories() async => _categories;

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async =>
      _list.take(limit).toList();

  @override
  Future<List<Product>> getLowStockProducts() async => _list;

  @override
  Future<Product> createProduct(Product product) async => product;

  @override
  Future<Product> updateProduct(Product product) async => product;

  @override
  Future<void> deleteProduct(int id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    // ensure SharedPreferences doesn't interfere
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tapping product triggers API calls when using ApiCartService',
      (tester) async {
    AppConfig.useApiCartService = true;

    final fakeApi = FakeApiService();
    // stub cart endpoints to avoid default empty map issue
    fakeApi.whenPost('/api/carts', {'id': 1});
    fakeApi.whenGet('/api/carts/1', {'items': []});
    final product = Product.sample();
    final container = ProviderContainer(overrides: [
      apiServiceProvider.overrideWithValue(fakeApi),
      productServiceProvider.overrideWithValue(FakeProductService([product])),
    ]);

    await tester.pumpWidget(ProviderScope(
      parent: container,
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: SizedBox(width: 800, child: PosScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // initial cart creation occurs on startup (POST then GET)
    expect(fakeApi.calls.length, greaterThanOrEqualTo(2));

    // tap on product tile to add item to cart
    await tester.tap(find.text(product.nameEn));
    await tester.pumpAndSettle();

    // the service should post the item to the cart path
    expect(fakeApi.calls.any((c) => c.contains('/api/carts/1/items')), isTrue);
  });

  testWidgets('holding order sends request to held-ticket endpoint',
      (tester) async {
    AppConfig.enableHeldTicketSync = true;
    AppConfig.useApiCartService = true;

    final fakeApi = FakeApiService();
    // stub cart endpoints as above
    fakeApi.whenPost('/api/carts', {'id': 1});
    fakeApi.whenGet('/api/carts/1', {'items': []});
    final product = Product.sample();
    final container = ProviderContainer(overrides: [
      apiServiceProvider.overrideWithValue(fakeApi),
      productServiceProvider.overrideWithValue(FakeProductService([product])),
    ]);

    await tester.pumpWidget(ProviderScope(
      parent: container,
      child: MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: SizedBox(width: 800, child: PosScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    // add item to cart
    await tester.tap(find.text(product.nameEn));
    await tester.pumpAndSettle();

    // pre-select a table to ensure tableName flows through
    container.read(tableSelectionProvider.notifier).state =
        RestaurantTable.sample();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Hold Order').first);
    await tester.pumpAndSettle();

    // verify held ticket POST request happened and included tableName
    expect(
        fakeApi.calls.any((c) => c.contains('/api/pos/held-tickets')), isTrue);
    expect(fakeApi.calls.any((c) => c.contains('tableName')), isTrue);
  });
}
