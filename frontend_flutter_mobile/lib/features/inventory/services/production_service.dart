import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/production_models.dart';
import '../../../core/services/api_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/services/
/// production_service.dart` — COPY/ADAPT NEARLY EXACTLY, full file.
///
/// Service for the Production module (recipes + production orders).
/// Matches backend ProductionController / ProductionDtos exactly.
abstract class ProductionService {
  Future<List<Recipe>> getRecipes();
  Future<Recipe> createRecipe(Recipe recipe);
  Future<Recipe> updateRecipe(Recipe recipe);
  Future<void> deactivateRecipe(int id);

  Future<List<ProductionOrder>> getOrders();
  Future<ProductionOrder> createOrder(ProductionOrder order);
  Future<AvailabilityCheckResult> checkAvailability({
    required int recipeId,
    required int storeId,
    required double producedQuantity,
  });
  Future<ProductionOrder> startOrder(int id);
  Future<ProductionOrder> completeOrder(
    int id, {
    required double producedQuantity,
    double wasteQuantity = 0,
    String? notes,
  });
  Future<ProductionOrder> cancelOrder(int id, {String? reason});
}

class ApiProductionService extends ProductionService {
  final ApiService _api;

  ApiProductionService(this._api);

  @override
  Future<List<Recipe>> getRecipes() async {
    final resp = await _api.get<List<dynamic>>('/api/production/recipes');
    return resp.cast<Map<String, dynamic>>().map(Recipe.fromJson).toList();
  }

  @override
  Future<Recipe> createRecipe(Recipe recipe) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/production/recipes',
      data: recipe.toCreateJson(),
    );
    return Recipe.fromJson(resp);
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    final resp = await _api.put<Map<String, dynamic>>(
      '/api/production/recipes/${recipe.id}',
      data: recipe.toUpdateJson(),
    );
    return Recipe.fromJson(resp);
  }

  @override
  Future<void> deactivateRecipe(int id) async {
    await _api.delete('/api/production/recipes/$id');
  }

  @override
  Future<List<ProductionOrder>> getOrders() async {
    final resp = await _api.get<List<dynamic>>('/api/production/orders');
    return resp
        .cast<Map<String, dynamic>>()
        .map(ProductionOrder.fromJson)
        .toList();
  }

  @override
  Future<ProductionOrder> createOrder(ProductionOrder order) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/production/orders',
      data: order.toJson(),
    );
    return ProductionOrder.fromJson(resp);
  }

  @override
  Future<AvailabilityCheckResult> checkAvailability({
    required int recipeId,
    required int storeId,
    required double producedQuantity,
  }) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/production/orders/check-availability',
      data: {
        'recipeId': recipeId,
        'storeId': storeId,
        'producedQuantity': producedQuantity,
      },
    );
    return AvailabilityCheckResult.fromJson(resp);
  }

  @override
  Future<ProductionOrder> startOrder(int id) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/production/orders/$id/start',
    );
    return ProductionOrder.fromJson(resp);
  }

  @override
  Future<ProductionOrder> completeOrder(
    int id, {
    required double producedQuantity,
    double wasteQuantity = 0,
    String? notes,
  }) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/production/orders/$id/complete',
      data: {
        'producedQuantity': producedQuantity,
        'wasteQuantity': wasteQuantity,
        if (notes != null) 'notes': notes,
      },
    );
    return ProductionOrder.fromJson(resp);
  }

  @override
  Future<ProductionOrder> cancelOrder(int id, {String? reason}) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/production/orders/$id/cancel',
      data: {if (reason != null) 'reason': reason},
    );
    return ProductionOrder.fromJson(resp);
  }
}

final Provider<ProductionService> productionServiceProvider =
    Provider<ProductionService>((ref) {
      final api = ref.watch(apiServiceProvider);
      return ApiProductionService(api);
    });
