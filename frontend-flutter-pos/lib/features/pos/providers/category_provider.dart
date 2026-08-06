import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_models.dart';
import '../services/product_service.dart';
import '../services/demo_product_service.dart';

/// A notifier that holds an asynchronous list of available product
/// categories.  Separating this from [productsProvider] keeps the code
/// easier to test and also makes it simple to refresh or cache categories
/// independently if the UX grows more sophisticated.
final categoriesProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<List<Category>>>((ref) {
  final service = ref.watch(productServiceProvider);
  return CategoryNotifier(service);
});

class CategoryNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  final ProductService _service;

  CategoryNotifier(this._service) : super(const AsyncValue.loading()) {
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
}
