import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/unit_models.dart';
import '../services/unit_service.dart';

/// NEW provider — no desktop equivalent exists (the desktop
/// `UnitManagementScreen` talks to `UnitService` directly). Shape/error
/// handling mirrors `frontend_flutter_mobile/lib/features/pos/providers/
/// category_provider.dart`'s `CategoryNotifier` and `frontend_flutter_mobile/
/// lib/features/inventory/providers/inventory_provider.dart`'s
/// `SuppliersNotifier`: `AsyncValue<List<Unit>>` state, `AsyncValue.loading()`
/// before the fetch, `AsyncValue.error(e, st)` on failure, and mutating
/// methods that call the service then reload the list so the UI always
/// reflects the server's latest state.
final unitProvider =
    StateNotifierProvider<UnitNotifier, AsyncValue<List<Unit>>>((ref) {
  final service = ref.watch(unitServiceProvider);
  return UnitNotifier(service);
});

class UnitNotifier extends StateNotifier<AsyncValue<List<Unit>>> {
  final UnitService _service;

  UnitNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> loadUnits({String? query}) async {
    try {
      state = const AsyncValue.loading();
      final list = await _service.list(query: query ?? '');
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createUnit(Map<String, dynamic> data) async {
    await _service.create(data);
    await loadUnits();
  }

  Future<void> updateUnit(int id, Map<String, dynamic> data) async {
    await _service.update(id, data);
    await loadUnits();
  }

  Future<void> toggleActive(int id, bool active) async {
    await _service.updateStatus(id, active);
    await loadUnits();
  }
}
