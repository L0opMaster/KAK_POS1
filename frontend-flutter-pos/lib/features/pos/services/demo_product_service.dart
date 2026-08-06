import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_models.dart';
import 'product_service.dart';
import '../../../core/services/api_service.dart';

/// Demo product service that returns sample data for development/testing
/// when the backend API is unavailable.
class DemoProductService extends ProductService {
  // ── Sample Categories ──
  static final List<Category> _demoCategories = [
    Category(id: 1, nameEn: 'Beverages', nameKm: 'ភេសជ្ជៈ', parentId: null, active: true),
    Category(id: 2, nameEn: 'Food', nameKm: 'អាហារ', parentId: null, active: true),
    Category(id: 3, nameEn: 'Snacks', nameKm: 'អាហារសម្រន់', parentId: null, active: true),
    Category(id: 4, nameEn: 'Merchandise', nameKm: 'ទំនិញ', parentId: null, active: true),
  ];

  // ── Sample Products ──
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
      id: 3, sku: 'BEV003', barcode: '880123456003',
      nameEn: 'Iced Matcha Latte', nameKm: 'ម៉ាចាឡាតេទឹកកក',
      price: 5.50, cost: 2.50, stock: 18,
      active: true, trackInventory: true, categoryId: 1,
      categoryNameEn: 'Beverages', categoryNameKm: 'ភេសជ្ជៈ',
      imageUrl: 'https://picsum.photos/seed/matcha-latte/400/400',
    ),
    Product(
      id: 4, sku: 'BEV004', barcode: '880123456004',
      nameEn: 'Fresh Juice', nameKm: 'ទឹកផ្លែឈើស្រស់',
      price: 3.50, cost: 1.80, stock: 30,
      active: true, trackInventory: true, categoryId: 1,
      categoryNameEn: 'Beverages', categoryNameKm: 'ភេសជ្ជៈ',
      imageUrl: 'https://picsum.photos/seed/fresh-juice/400/400',
    ),
    Product(
      id: 5, sku: 'BEV005', barcode: '880123456005',
      nameEn: 'Water Bottle', nameKm: 'ដបទឹក',
      price: 1.00, cost: 0.40, stock: 100,
      active: true, trackInventory: true, categoryId: 1,
      categoryNameEn: 'Beverages', categoryNameKm: 'ភេសជ្ជៈ',
      imageUrl: 'https://picsum.photos/seed/water-bottle/400/400',
    ),
    Product(
      id: 6, sku: 'FOOD001', barcode: '880123456006',
      nameEn: 'Ham & Cheese Sandwich', nameKm: 'សាំងវិច',
      price: 6.50, cost: 3.00, stock: 12,
      active: true, trackInventory: true, categoryId: 2,
      categoryNameEn: 'Food', categoryNameKm: 'អាហារ',
      imageUrl: 'https://picsum.photos/seed/sandwich/400/400',
    ),
    Product(
      id: 7, sku: 'FOOD002', barcode: '880123456007',
      nameEn: 'Caesar Salad', nameKm: 'សាឡាត់សេសារ',
      price: 7.00, cost: 3.50, stock: 8,
      active: true, trackInventory: true, categoryId: 2,
      categoryNameEn: 'Food', categoryNameKm: 'អាហារ',
      imageUrl: 'https://picsum.photos/seed/caesar-salad/400/400',
    ),
    Product(
      id: 8, sku: 'FOOD003', barcode: '880123456008',
      nameEn: 'Chicken Wrap', nameKm: 'វ្រាប់សាច់មាន់',
      price: 5.75, cost: 2.80, stock: 15,
      active: true, trackInventory: true, categoryId: 2,
      categoryNameEn: 'Food', categoryNameKm: 'អាហារ',
      imageUrl: 'https://picsum.photos/seed/chicken-wrap/400/400',
    ),
    Product(
      id: 9, sku: 'FOOD004', barcode: '880123456009',
      nameEn: 'Bagel with Cream Cheese', nameKm: 'បេហ្គែល',
      price: 2.75, cost: 1.20, stock: 5,
      active: true, trackInventory: true, categoryId: 2,
      categoryNameEn: 'Food', categoryNameKm: 'អាហារ',
      imageUrl: 'https://picsum.photos/seed/bagel/400/400',
    ),
    Product(
      id: 10, sku: 'SNK001', barcode: '880123456010',
      nameEn: 'Potato Chips', nameKm: 'បន្ទះសៀគ្វី',
      price: 1.50, cost: 0.60, stock: 35,
      active: true, trackInventory: true, categoryId: 3,
      categoryNameEn: 'Snacks', categoryNameKm: 'អាហារសម្រន់',
      imageUrl: 'https://picsum.photos/seed/potato-chips/400/400',
    ),
    Product(
      id: 11, sku: 'SNK002', barcode: '880123456011',
      nameEn: 'Chocolate Cookie', nameKm: 'ខូឃីសូកូឡា',
      price: 2.00, cost: 0.80, stock: 20,
      active: true, trackInventory: true, categoryId: 3,
      categoryNameEn: 'Snacks', categoryNameKm: 'អាហារសម្រន់',
      imageUrl: 'https://picsum.photos/seed/cookie/400/400',
    ),
    Product(
      id: 12, sku: 'SNK003', barcode: '880123456012',
      nameEn: 'Mixed Nuts', nameKm: 'គ្រាប់ធញ្ញជាតិ',
      price: 3.25, cost: 1.50, stock: 18,
      active: true, trackInventory: true, categoryId: 3,
      categoryNameEn: 'Snacks', categoryNameKm: 'អាហារសម្រន់',
      imageUrl: 'https://picsum.photos/seed/mixed-nuts/400/400',
    ),
    Product(
      id: 13, sku: 'SNK004', barcode: '880123456013',
      nameEn: 'Muffin', nameKm: 'ម៉ាហ្វាំង',
      price: 2.50, cost: 1.00, stock: 4,
      active: true, trackInventory: true, categoryId: 3,
      categoryNameEn: 'Snacks', categoryNameKm: 'អាហារសម្រន់',
      imageUrl: 'https://picsum.photos/seed/muffin/400/400',
    ),
    Product(
      id: 14, sku: 'MER001', barcode: '880123456014',
      nameEn: 'T-Shirt', nameKm: 'អាវយឺត',
      price: 15.00, cost: 6.00, stock: 20,
      active: true, trackInventory: true, categoryId: 4,
      categoryNameEn: 'Merchandise', categoryNameKm: 'ទំនិញ',
      imageUrl: 'https://picsum.photos/seed/tshirt/400/400',
    ),
    Product(
      id: 15, sku: 'MER002', barcode: '880123456015',
      nameEn: 'Reusable Tote Bag', nameKm: 'កាបូបក្រណាត់',
      price: 8.00, cost: 3.50, stock: 25,
      active: true, trackInventory: true, categoryId: 4,
      categoryNameEn: 'Merchandise', categoryNameKm: 'ទំនិញ',
      imageUrl: 'https://picsum.photos/seed/tote-bag/400/400',
    ),
  ];

  @override
  Future<List<Product>> getProducts({
    String? query,
    int? categoryId,
    int page = 0,
    int size = 100,
  }) async {
    // Simulate network delay
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

    // Pagination
    final start = page * size;
    if (start < results.length) {
      final end = (start + size).clamp(0, results.length);
      results = results.sublist(start, end);
    }

    return results;
  }

  @override
  Future<List<Category>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return List.of(_demoCategories);
  }

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _demoProducts.take(limit).toList();
  }

  @override
  Future<List<Product>> getLowStockProducts() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _demoProducts.where((p) => p.stock > 0 && p.stock <= 5).toList();
  }

  @override
  Future<Product> createProduct(Product product) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Product(
      id: _demoProducts.length + 1,
      sku: product.sku,
      barcode: product.barcode,
      nameEn: product.nameEn,
      nameKm: product.nameKm,
      price: product.price,
      cost: product.cost,
      stock: product.stock,
      active: product.active,
      trackInventory: product.trackInventory,
      imageUrl: product.imageUrl,
      categoryId: product.categoryId,
    );
  }

  @override
  Future<Product> updateProduct(Product product) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return product;
  }

  @override
  Future<void> deleteProduct(int id) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}

/// Provider that tries API first, falls back to demo data on failure.
final Provider<ProductService> productServiceProvider =
    Provider<ProductService>((ref) {
  // Try API-based provider first
  final api = ref.watch(apiServiceProvider);
  final apiService = ApiProductService(api);

  // Return a hybrid that catches errors and falls back to demo
  return _FallbackProductService(apiService, DemoProductService());
});

/// Wraps API service and falls back to demo on any failure.
class _FallbackProductService extends ProductService {
  final ApiProductService _api;
  final DemoProductService _demo;

  _FallbackProductService(this._api, this._demo);

  Future<T> _tryApi<T>(Future<T> Function() apiCall, Future<T> Function() demoCall) async {
    try {
      return await apiCall();
    } catch (e) {
      return await demoCall();
    }
  }

  @override
  Future<List<Product>> getProducts({String? query, int? categoryId, int page = 0, int size = 100}) {
    return _tryApi(
      () => _api.getProducts(query: query, categoryId: categoryId, page: page, size: size),
      () => _demo.getProducts(query: query, categoryId: categoryId, page: page, size: size),
    );
  }

  @override
  Future<List<Category>> getCategories() {
    return _tryApi(
      () => _api.getCategories(),
      () => _demo.getCategories(),
    );
  }

  @override
  Future<List<Product>> getPopularProducts({int limit = 10}) {
    return _tryApi(
      () => _api.getPopularProducts(limit: limit),
      () => _demo.getPopularProducts(limit: limit),
    );
  }

  @override
  Future<List<Product>> getLowStockProducts() {
    return _tryApi(
      () => _api.getLowStockProducts(),
      () => _demo.getLowStockProducts(),
    );
  }

  @override
  Future<Product> createProduct(Product product) {
    return _tryApi(
      () => _api.createProduct(product),
      () => _demo.createProduct(product),
    );
  }

  @override
  Future<Product> updateProduct(Product product) {
    return _tryApi(
      () => _api.updateProduct(product),
      () => _demo.updateProduct(product),
    );
  }

  @override
  Future<void> deleteProduct(int id) {
    return _tryApi(
      () => _api.deleteProduct(id),
      () => _demo.deleteProduct(id),
    );
  }
}
