import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/product_models.dart';
import '../services/product_service.dart';
import '../services/demo_product_service.dart';

/// Paginated product state with loading flags.
class ProductState {
  final List<Product> products;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final int totalCount;
  final String? error;

  const ProductState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.totalCount = 0,
    this.error,
  });

  ProductState copyWith({
    List<Product>? products,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    int? totalCount,
    String? error,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      totalCount: totalCount ?? this.totalCount,
      error: error ?? this.error,
    );
  }
}

/// Provider exposing the product notifier.
final productsProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final service = ref.watch(productServiceProvider);
  return ProductNotifier(service);
});

/// Typed alias for the provider (sugar).
class ProductNotifier extends StateNotifier<ProductState> {
  final ProductService _service;
  static const int _pageSize = 48; // 4 cols × 12 rows per load

  String? _currentQuery;
  int? _currentCategoryId;

  ProductNotifier(this._service) : super(const ProductState(isLoading: true));

  List<Product> get currentProducts => state.products;

  /// Initial full load (page 0). Resets pagination.
  Future<void> loadProducts({String? query, int? categoryId}) async {
    _currentQuery = query;
    _currentCategoryId = categoryId;

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentPage: 0,
      hasMore: true,
    );

    try {
      final list = await _service.getProducts(
        query: query,
        categoryId: categoryId,
        page: 0,
        size: _pageSize,
      );
      state = state.copyWith(
        products: List.of(list),
        isLoading: false,
        hasMore: list.length >= _pageSize,
        currentPage: 0,
        totalCount: list.length,
      );
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Loads the next page and appends products. Called on scroll-to-bottom.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.currentPage + 1;

    try {
      final list = await _service.getProducts(
        query: _currentQuery,
        categoryId: _currentCategoryId,
        page: nextPage,
        size: _pageSize,
      );
      final updatedProducts = [...state.products, ...list];
      state = state.copyWith(
        products: updatedProducts,
        isLoadingMore: false,
        hasMore: list.length >= _pageSize,
        currentPage: nextPage,
        totalCount: updatedProducts.length,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Search helper.
  Future<void> searchProducts(String query) async {
    await loadProducts(query: query.isEmpty ? null : query);
  }

  /// Finds one exact barcode match without replacing the product grid state.
  ///
  /// This reuses the backend's existing GET /api/products?q=... search endpoint.
  Future<Product?> findByBarcode(String barcode) {
    return _service.findByBarcode(barcode);
  }

  /// Category filter helper.
  Future<void> filterByCategory(int? categoryId) async {
    await loadProducts(categoryId: categoryId);
  }

  /// Re-fetches the current page with the active search/filter, so cached
  /// products (e.g. their `modifierGroups`) pick up changes made elsewhere,
  /// such as assigning products to a modifier group.
  Future<void> refresh() async {
    await loadProducts(query: _currentQuery, categoryId: _currentCategoryId);
  }

  /// Creates product and refreshes.
  Future<void> addProduct(Product product) async {
    try {
      await _service.createProduct(product);
      await loadProducts(query: _currentQuery, categoryId: _currentCategoryId);
    } catch (e, st) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Updates product and refreshes.
  Future<void> updateProduct(Product product) async {
    try {
      await _service.updateProduct(product);
      await loadProducts(query: _currentQuery, categoryId: _currentCategoryId);
    } catch (e, st) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Deletes product and refreshes.
  Future<void> deleteProduct(int id) async {
    try {
      await _service.deleteProduct(id);
      await loadProducts(query: _currentQuery, categoryId: _currentCategoryId);
    } catch (e, st) {
      state = state.copyWith(error: e.toString());
    }
  }
}
