import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_models.dart';
import '../../../core/services/api_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// category_service.dart` — COPY/ADAPT NEARLY EXACTLY. Same small concrete
/// (non-abstract) shape as source: `list()`/`create()`/`update()` against
/// `/api/categories`. Methods are left overridable (not `final`) so tests
/// can subclass this with an in-memory fake, matching this project's
/// `_FakeProductService extends ProductService` pattern even though, unlike
/// `ProductService`, this class isn't abstract.
class CategoryService {
  final ApiService _api;

  CategoryService(this._api);

  /// List all categories (active + inactive).
  Future<List<Category>> list() async {
    final resp = await _api.get<List<dynamic>>('/api/categories');
    return resp
        .cast<Map<String, dynamic>>()
        .map((e) => Category.fromJson(e))
        .toList();
  }

  /// Create a new category.
  Future<Category> create(Map<String, dynamic> data) async {
    final resp =
        await _api.post<Map<String, dynamic>>('/api/categories', data: data);
    return Category.fromJson(resp);
  }

  /// Update an existing category. Full PUT — the caller must send the
  /// complete `nameEn`/`nameKm`/`active` payload, not a partial patch.
  Future<Category> update(int id, Map<String, dynamic> data) async {
    final resp = await _api.put<Map<String, dynamic>>(
        '/api/categories/$id', data: data);
    return Category.fromJson(resp);
  }
}

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(ref.watch(apiServiceProvider));
});
