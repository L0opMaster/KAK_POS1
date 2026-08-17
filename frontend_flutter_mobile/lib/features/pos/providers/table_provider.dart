import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/table_models.dart';
import '../services/table_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// table_provider.dart`. Originally a PARTIAL PORT (`search()` only, for
/// the table *picker*); `create()`/`update()`/`delete()`/`loadStats()` were
/// added later for the admin table-management CRUD screens, mirroring
/// source's "re-run search() with a generous page size to refresh the
/// in-memory list" pattern after each mutation.
class TableNotifier extends StateNotifier<AsyncValue<TablePage>> {
  final TableService _service;
  String? _lastQuery;

  TableNotifier(this._service) : super(const AsyncValue.loading());

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

  /// Fetches table statistics. Does not touch [state] — callers (the admin
  /// list screen's optional summary row) read the returned value directly.
  Future<TableStats> loadStats() => _service.getStats();

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

final tableProvider =
    StateNotifierProvider<TableNotifier, AsyncValue<TablePage>>((ref) {
  final service = ref.watch(tableServiceProvider);
  return TableNotifier(service);
});
