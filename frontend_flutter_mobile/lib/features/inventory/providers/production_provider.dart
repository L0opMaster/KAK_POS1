import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/production_models.dart';
import '../services/production_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/providers/
/// production_provider.dart` — COPY/ADAPT NEARLY EXACTLY, full file.

// ─────────────────────────────────────────────────────────────
// Recipes Provider
// ─────────────────────────────────────────────────────────────
final recipesProvider =
    StateNotifierProvider<RecipesNotifier, AsyncValue<List<Recipe>>>(
  (ref) {
    final service = ref.watch(productionServiceProvider);
    return RecipesNotifier(service);
  },
);

class RecipesNotifier extends StateNotifier<AsyncValue<List<Recipe>>> {
  final ProductionService _service;

  RecipesNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.getRecipes();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> create(Recipe recipe) async {
    await _service.createRecipe(recipe);
    await load();
  }

  Future<void> update(Recipe recipe) async {
    await _service.updateRecipe(recipe);
    await load();
  }

  Future<void> deactivate(int id) async {
    await _service.deactivateRecipe(id);
    await load();
  }
}

// ─────────────────────────────────────────────────────────────
// Production Orders Provider
// ─────────────────────────────────────────────────────────────
final productionOrdersProvider = StateNotifierProvider<
    ProductionOrdersNotifier, AsyncValue<List<ProductionOrder>>>(
  (ref) {
    final service = ref.watch(productionServiceProvider);
    return ProductionOrdersNotifier(service);
  },
);

class ProductionOrdersNotifier
    extends StateNotifier<AsyncValue<List<ProductionOrder>>> {
  final ProductionService _service;

  ProductionOrdersNotifier(this._service)
      : super(const AsyncValue.loading());

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.getOrders();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<AvailabilityCheckResult> checkAvailability({
    required int recipeId,
    required int storeId,
    required double producedQuantity,
  }) {
    return _service.checkAvailability(
      recipeId: recipeId,
      storeId: storeId,
      producedQuantity: producedQuantity,
    );
  }

  Future<void> create(ProductionOrder order) async {
    await _service.createOrder(order);
    await load();
  }

  Future<void> start(int id) async {
    await _service.startOrder(id);
    await load();
  }

  Future<void> complete(
    int id, {
    required double producedQuantity,
    double wasteQuantity = 0,
    String? notes,
  }) async {
    await _service.completeOrder(
      id,
      producedQuantity: producedQuantity,
      wasteQuantity: wasteQuantity,
      notes: notes,
    );
    await load();
  }

  Future<void> cancel(int id, {String? reason}) async {
    await _service.cancelOrder(id, reason: reason);
    await load();
  }
}
