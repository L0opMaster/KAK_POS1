import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_models.dart';
import '../../../core/services/api_service.dart';

/// Service for category CRUD operations.
/// Matches the backend CategoryController REST API.
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

  /// Update an existing category.
  Future<Category> update(int id, Map<String, dynamic> data) async {
    final resp =
        await _api.put<Map<String, dynamic>>('/api/categories/$id', data: data);
    return Category.fromJson(resp);
  }
}

final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService(ref.read(apiServiceProvider));
});
