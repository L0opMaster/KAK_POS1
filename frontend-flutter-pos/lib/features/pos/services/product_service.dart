import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_models.dart';
import '../../../core/services/api_service.dart';

/// Abstract service for product operations in POS.
/// Extend this class to provide concrete implementations.
///
/// Consider returning a Result/Either type for error handling.
abstract class ProductService {
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 100,
  });

  Future<List<Category>> getCategories();

  /// Looks up a product through the existing product-search flow, then requires
  /// an exact barcode match.
  ///
  /// The default implementation also lets demo/local product services support
  /// barcode scanning without adding a separate cart API.
  Future<Product?> findByBarcode(String barcode) async {
    final String normalizedBarcode = barcode.trim().toLowerCase();
    if (normalizedBarcode.isEmpty) {
      return null;
    }

    final List<Product> matches = await getProducts(
      query: normalizedBarcode,
      page: 0,
      size: 50,
    );

    for (final Product product in matches) {
      if (product.barcode.trim().toLowerCase() == normalizedBarcode) {
        return product;
      }
    }

    return null;
  }

  Future<List<Product>> getPopularProducts({int limit = 10});

  Future<List<Product>> getLowStockProducts();

  /// Creates a new product and returns the created entity (with id).
  Future<Product> createProduct(Product product);

  /// Updates an existing product; returns the updated entity.
  Future<Product> updateProduct(Product product);

  /// Deletes the product identified by [id].
  Future<void> deleteProduct(int id);
}

/// Concrete implementation of ProductService using API calls.
/// Matches backend Kaknnea REST API.
class ApiProductService extends ProductService {
  final ApiService _api;

  ApiProductService(this._api);

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 100,
  }) async {
    // For POS, use the dedicated pos-catalog endpoint (returns flat list)
    // which is optimized for the POS screen (no pagination wrapper).
    if (query == null && categoryId == null) {
      final resp = await _api.get<List<dynamic>>('/api/products/pos-catalog');
      return resp
          .cast<Map<String, dynamic>>()
          .map((e) => Product.fromJson(e))
          .toList();
    }

    // For filtered searches, use the paginated search endpoint.
    final params = <String, dynamic>{};
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (categoryId != null) params['categoryId'] = categoryId;
    params['page'] = page;
    params['size'] = size;

    final resp = await _api.get<Map<String, dynamic>>('/api/products',
        queryParameters: params);
    final items = (resp['content'] as List<dynamic>?) ?? [];
    return items
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<Category>> getCategories() async {
    final resp = await _api.get<List<dynamic>>('/api/categories');
    return resp
        .cast<Map<String, dynamic>>()
        .map((e) => Category.fromJson(e))
        .toList();
  }

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async {
    final resp = await _api.get<List<dynamic>>('/api/products/pos-catalog');
    final all = resp
        .cast<Map<String, dynamic>>()
        .map((e) => Product.fromJson(e))
        .toList();
    return all.take(limit).toList();
  }

  @override
  Future<List<Product>> getLowStockProducts() async {
    final resp = await _api.get<List<dynamic>>('/api/products/pos-catalog');
    return resp
        .cast<Map<String, dynamic>>()
        .map((e) => Product.fromJson(e))
        .where((p) =>
            p.lowStock || (p.trackInventory && p.stock <= p.lowStockThreshold))
        .toList();
  }

  @override
  Future<Product> createProduct(Product product) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/products',
      data: product.toJson(),
    );
    return Product.fromJson(resp);
  }

  @override
  Future<Product> updateProduct(Product product) async {
    final resp = await _api.put<Map<String, dynamic>>(
      '/api/products/${product.id}',
      data: product.toJson(),
    );
    return Product.fromJson(resp);
  }

  @override
  Future<void> deleteProduct(int id) async {
    await _api.delete<void>('/api/products/$id');
  }
}

// Provider moved to demo_product_service.dart
