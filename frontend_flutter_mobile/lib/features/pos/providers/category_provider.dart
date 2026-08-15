import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_models.dart';
import '../services/product_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// category_provider.dart` — COPY/ADAPT NEARLY EXACTLY.
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
