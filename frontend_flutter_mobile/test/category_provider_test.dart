import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/models/product_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/category_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/category_service.dart';
import 'package:frontend_flutter_mobile/features/pos/services/product_service.dart';

/// Fake ProductService — used only to drive `CategoryNotifier.loadCategories`
/// (which deliberately still reads through `ProductService.getCategories`,
/// unchanged from before this notifier gained write support), mirroring
/// `product_provider_test.dart`'s `_FakeProductService` approach: no
/// network, no dependency on ApiService/Dio.
class _FakeProductService extends ProductService {
  List<Category> categories;
  bool throwOnGetCategories = false;

  _FakeProductService({required this.categories});

  @override
  Future<List<Product>> getProducts(
      {String? query, int? categoryId, int page = 0, int size = 100}) async {
    return [];
  }

  @override
  Future<List<Category>> getCategories() async {
    if (throwOnGetCategories) throw Exception('boom');
    return List.of(categories);
  }
}

/// Fake CategoryService — in-memory create/update, no real HTTP. Subclasses
/// the concrete `CategoryService` (its methods aren't `final`, so this is
/// possible even though, unlike `ProductService`, it isn't abstract) and
/// never touches the `ApiService` it's constructed with.
class _FakeCategoryService extends CategoryService {
  final List<Category> store;
  int _nextId;
  bool throwOnCreate = false;
  bool throwOnUpdate = false;

  _FakeCategoryService({List<Category>? initial})
      : store = initial ?? [],
        _nextId = ((initial ?? []).map((c) => c.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1,
        super(apiService);

  @override
  Future<List<Category>> list() async => List.of(store);

  @override
  Future<Category> create(Map<String, dynamic> data) async {
    if (throwOnCreate) throw Exception('create failed');
    final cat = Category(
      id: _nextId++,
      nameEn: data['nameEn'] as String,
      nameKm: data['nameKm'] as String,
      active: data['active'] as bool,
    );
    store.add(cat);
    return cat;
  }

  @override
  Future<Category> update(int id, Map<String, dynamic> data) async {
    if (throwOnUpdate) throw Exception('update failed');
    final index = store.indexWhere((c) => c.id == id);
    final updated = Category(
      id: id,
      nameEn: data['nameEn'] as String,
      nameKm: data['nameKm'] as String,
      active: data['active'] as bool,
    );
    if (index >= 0) {
      store[index] = updated;
    } else {
      store.add(updated);
    }
    return updated;
  }
}

void main() {
  group('CategoryNotifier', () {
    test('initial load populates state.data from ProductService', () async {
      final productService = _FakeProductService(categories: [
        Category(id: 1, nameEn: 'Beverages', nameKm: 'ភេសជ្ជៈ', active: true),
        Category(id: 2, nameEn: 'Food', nameKm: 'អាហារ', active: true),
      ]);
      final categoryService = _FakeCategoryService();
      final notifier = CategoryNotifier(productService, categoryService);

      // Constructor kicks off loadCategories(); wait for it to settle.
      for (var i = 0; i < 20; i++) {
        if (!notifier.state.isLoading) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      expect(notifier.state.value?.length, 2);
      expect(notifier.state.value?.map((c) => c.nameEn), containsAll(
        ['Beverages', 'Food'],
      ));
    });

    test('loadCategories sets AsyncValue.error on failure', () async {
      final productService = _FakeProductService(categories: [])
        ..throwOnGetCategories = true;
      final notifier =
          CategoryNotifier(productService, _FakeCategoryService());

      await notifier.loadCategories();

      expect(notifier.state.hasError, isTrue);
    });

    test('createCategory adds an item and refreshes state', () async {
      final categories = [
        Category(id: 1, nameEn: 'Beverages', nameKm: 'ភេសជ្ជៈ', active: true),
      ];
      final productService = _FakeProductService(categories: categories);
      final categoryService = _FakeCategoryService(initial: categories);
      final notifier = CategoryNotifier(productService, categoryService);
      await notifier.loadCategories();

      await notifier.createCategory({
        'nameEn': 'Snacks',
        'nameKm': 'អាហារសម្រន់',
        'active': true,
      });

      expect(notifier.state.value?.length, 2);
      expect(
        notifier.state.value?.any((c) => c.nameEn == 'Snacks'),
        isTrue,
      );
    });

    test('updateCategory modifies an existing item and refreshes state',
        () async {
      final categories = [
        Category(id: 1, nameEn: 'Beverages', nameKm: 'ភេសជ្ជៈ', active: true),
      ];
      final productService = _FakeProductService(categories: categories);
      final categoryService = _FakeCategoryService(initial: categories);
      final notifier = CategoryNotifier(productService, categoryService);
      await notifier.loadCategories();

      await notifier.updateCategory(1, {
        'nameEn': 'Beverages',
        'nameKm': 'ភេសជ្ជៈ',
        'active': false,
      });

      final updated = notifier.state.value!.firstWhere((c) => c.id == 1);
      expect(updated.active, isFalse);
    });
  });
}
