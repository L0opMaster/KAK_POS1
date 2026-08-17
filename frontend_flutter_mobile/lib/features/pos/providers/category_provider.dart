import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_models.dart';
import '../services/product_service.dart';
import '../services/category_service.dart';
import '../../../core/services/api_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// category_provider.dart` — COPY/ADAPT NEARLY EXACTLY.
final categoriesProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<List<Category>>>((ref) {
  final service = ref.watch(productServiceProvider);
  final categoryService = ref.watch(categoryServiceProvider);
  return CategoryNotifier(service, categoryService);
});

class CategoryNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final ProductService _service;

  /// Used only by `createCategory`/`updateCategory` — `loadCategories()`
  /// deliberately keeps reading through [ProductService] (unchanged from
  /// before this class had write support) since other screens already
  /// depend on that read path. Optional/defaulted so existing single-arg
  /// call sites (e.g. `CategoryNotifier(service)` in product_provider_test)
  /// keep compiling unchanged.
  final CategoryService _categoryService;

  CategoryNotifier(this._service, [CategoryService? categoryService])
      : _categoryService = categoryService ?? CategoryService(apiService),
        super(const AsyncValue.loading()) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.getCategories();
      state = AsyncValue.data(List.of(list));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createCategory(Map<String, dynamic> data) async {
    await _categoryService.create(data);
    await loadCategories();
  }

  Future<void> updateCategory(int id, Map<String, dynamic> data) async {
    await _categoryService.update(id, data);
    await loadCategories();
  }
}
