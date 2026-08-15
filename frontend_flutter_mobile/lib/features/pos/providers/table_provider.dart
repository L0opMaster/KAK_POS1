import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/table_models.dart';
import '../services/table_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// table_provider.dart` — PARTIAL PORT. `search()` only —
/// `create()`/`update()`/`delete()` (admin CRUD) dropped along with the
/// service methods they call.
class TableNotifier extends StateNotifier<AsyncValue<TablePage>> {
  final TableService _service;

  TableNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> search({
    String? query,
    String? status,
    String? section,
    bool? isActive,
    int page = 0,
    int size = 20,
  }) async {
    try {
      state = const AsyncValue.loading();
      final result = await _service.searchTables(
        search: query,
        status: status,
        section: section,
        isActive: isActive,
        page: page,
        size: size,
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final tableProvider =
    StateNotifierProvider<TableNotifier, AsyncValue<TablePage>>((ref) {
  final service = ref.watch(tableServiceProvider);
  return TableNotifier(service);
});
