import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_models.dart';
import '../../../core/services/api_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// product_service.dart` — COPY/ADAPT NEARLY EXACTLY.
abstract class ProductService {
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 100,
  });

  Future<List<Category>> getCategories();

  /// Looks up a product through the existing product-search flow, then
  /// requires an exact barcode match.
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
}

/// Concrete implementation of ProductService using API calls. Matches the
/// shared Spring Boot backend exactly (same endpoints as `[OLD/SOURCE]`).
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
}

/// Demo product service returning sample data for development/testing when
/// the backend API is unavailable.
///
/// TRIMMED vs. `[OLD/SOURCE]`'s `DemoProductService`: 8 products across 3
/// categories here (vs. source's 15 across 4) — this is placeholder
/// fallback data, not a business contract, so a smaller set was judged
/// sufficient to exercise the same grid/search/filter/pagination code
/// paths without hand-copying 15 near-identical product literals. Shape
/// (fields, `Future.delayed` simulated latency, filter/pagination logic) is
/// otherwise byte-identical to source.
class DemoProductService extends ProductService {
  static final List<Category> _demoCategories = [
    Category(id: 1, nameEn: 'Beverages', nameKm: 'ភេសជ្ជៈ', parentId: null, active: true),
    Category(id: 2, nameEn: 'Food', nameKm: 'អាហារ', parentId: null, active: true),
    Category(id: 3, nameEn: 'Snacks', nameKm: 'អាហារសម្រន់', parentId: null, active: true),
  ];

  static final List<Product> _demoProducts = [
    Product(
      id: 1, sku: 'BEV001', barcode: '880123456001',
      nameEn: 'Coffee Latte', nameKm: 'កាហ្វេឡាតេ',
      price: 4.50, cost: 2.00, stock: 23,
      active: true, trackInventory: true, categoryId: 1,
      categoryNameEn: 'Beverages', categoryNameKm: 'ភេសជ្ជៈ',
      imageUrl: 'https://picsum.photos/seed/coffee-latte/400/400',
    ),
    Product(
      id: 2, sku: 'BEV002', barcode: '880123456002',
      nameEn: 'Espresso', nameKm: 'អេស្ព្រេសសូ',
      price: 3.00, cost: 1.20, stock: 45,
      active: true, trackInventory: true, categoryId: 1,
      categoryNameEn: 'Beverages', categoryNameKm: 'ភេសជ្ជៈ',
      imageUrl: 'https://picsum.photos/seed/espresso/400/400',
    ),
    Product(
      id: 3, sku: 'BEV005', barcode: '880123456005',
      nameEn: 'Water Bottle', nameKm: 'ដបទឹក',
      price: 1.00, cost: 0.40, stock: 100,
      active: true, trackInventory: true, categoryId: 1,
      categoryNameEn: 'Beverages', categoryNameKm: 'ភេសជ្ជៈ',
      imageUrl: 'https://picsum.photos/seed/water-bottle/400/400',
    ),
    Product(
      id: 4, sku: 'FOOD001', barcode: '880123456006',
      nameEn: 'Ham & Cheese Sandwich', nameKm: 'សាំងវិច',
      price: 6.50, cost: 3.00, stock: 12,
      active: true, trackInventory: true, categoryId: 2,
      categoryNameEn: 'Food', categoryNameKm: 'អាហារ',
      imageUrl: 'https://picsum.photos/seed/sandwich/400/400',
    ),
    Product(
      id: 5, sku: 'FOOD003', barcode: '880123456008',
      nameEn: 'Chicken Wrap', nameKm: 'វ្រាប់សាច់មាន់',
      price: 5.75, cost: 2.80, stock: 15,
      active: true, trackInventory: true, categoryId: 2,
      categoryNameEn: 'Food', categoryNameKm: 'អាហារ',
      imageUrl: 'https://picsum.photos/seed/chicken-wrap/400/400',
    ),
    Product(
      id: 6, sku: 'FOOD004', barcode: '880123456009',
      nameEn: 'Bagel with Cream Cheese', nameKm: 'បេហ្គែល',
      price: 2.75, cost: 1.20, stock: 5,
      active: true, trackInventory: true, categoryId: 2,
      categoryNameEn: 'Food', categoryNameKm: 'អាហារ',
      imageUrl: 'https://picsum.photos/seed/bagel/400/400',
    ),
    Product(
      id: 7, sku: 'SNK001', barcode: '880123456010',
      nameEn: 'Potato Chips', nameKm: 'បន្ទះសៀគ្វី',
      price: 1.50, cost: 0.60, stock: 35,
      active: true, trackInventory: true, categoryId: 3,
      categoryNameEn: 'Snacks', categoryNameKm: 'អាហារសម្រន់',
      imageUrl: 'https://picsum.photos/seed/potato-chips/400/400',
    ),
    Product(
      id: 8, sku: 'SNK004', barcode: '880123456013',
      nameEn: 'Muffin', nameKm: 'ម៉ាហ្វាំង',
      price: 2.50, cost: 1.00, stock: 4,
      active: true, trackInventory: true, categoryId: 3,
      categoryNameEn: 'Snacks', categoryNameKm: 'អាហារសម្រន់',
      imageUrl: 'https://picsum.photos/seed/muffin/400/400',
    ),
  ];

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 100,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    var results = _demoProducts.where((p) => p.active).toList();

    if (categoryId != null) {
      results = results.where((p) => p.categoryId == categoryId).toList();
    }

    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results
          .where((p) =>
              p.nameEn.toLowerCase().contains(q) ||
              p.nameKm.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q) ||
              p.barcode.contains(q))
          .toList();
    }

    final start = page * size;
    if (start < results.length) {
      final end = (start + size).clamp(0, results.length);
      results = results.sublist(start, end);
    } else {
      results = [];
    }

    return results;
  }

  @override
  Future<List<Category>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.of(_demoCategories);
  }
}

/// Provider that tries API first, falls back to demo data on failure.
final Provider<ProductService> productServiceProvider =
    Provider<ProductService>((ref) {
  final api = ref.watch(apiServiceProvider);
  final apiService = ApiProductService(api);
  return _FallbackProductService(apiService, DemoProductService());
});

/// Wraps API service and falls back to demo on any failure.
class _FallbackProductService extends ProductService {
  final ApiProductService _api;
  final DemoProductService _demo;

  _FallbackProductService(this._api, this._demo);

  Future<T> _tryApi<T>(
      Future<T> Function() apiCall, Future<T> Function() demoCall) async {
    try {
      return await apiCall();
    } catch (e) {
      return await demoCall();
    }
  }

  @override
  Future<List<Product>> getProducts(
      {String? query, int? categoryId, int page = 0, int size = 100}) {
    return _tryApi(
      () => _api.getProducts(
          query: query, categoryId: categoryId, page: page, size: size),
      () => _demo.getProducts(
          query: query, categoryId: categoryId, page: page, size: size),
    );
  }

  @override
  Future<List<Category>> getCategories() {
    return _tryApi(() => _api.getCategories(), () => _demo.getCategories());
  }
}
