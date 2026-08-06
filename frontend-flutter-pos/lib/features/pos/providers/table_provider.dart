import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/table_models.dart';
import '../services/table_service.dart';

/// Notifier exposing async table page results to the UI.
///
/// Mirrors the pattern used by [ProductNotifier] but returns a full
/// [TablePage] object since tables are paginated.
class TableNotifier extends StateNotifier<AsyncValue<TablePage>> {
  final TableService _service;
  String? _lastQuery;

  TableNotifier(this._service) : super(const AsyncValue.loading());

  /// Executes a search call and updates state accordingly.
  Future<void> search({
    String? query,
    String? status,
    String? section,
    bool? isActive,
    int page = 0,
    int size = 20,
  }) async {
    _lastQuery = query;
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

  Future<RestaurantTable> create(TableCreateRequest request) async {
    final created = await _service.createTable(request);
    await search(query: _lastQuery, size: 1000);
    return created;
  }

  Future<RestaurantTable> update(int id, TableUpdateRequest request) async {
    final updated = await _service.updateTable(id, request);
    await search(query: _lastQuery, size: 1000);
    return updated;
  }

  Future<void> delete(int id) async {
    await _service.deleteTable(id);
    await search(query: _lastQuery, size: 1000);
  }
}

/// Provider that automatically obtains a [TableService] from the container
/// then wraps it in a [TableNotifier]. UI widgets can watch this provider to
/// react to loading/error/data states when performing table searches.
final tableProvider =
    StateNotifierProvider<TableNotifier, AsyncValue<TablePage>>((ref) {
  final service = ref.watch(tableServiceProvider);
  return TableNotifier(service);
});
