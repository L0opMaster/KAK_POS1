import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../models/table_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// table_service.dart`. Originally a PARTIAL PORT (`searchTables` only,
/// needed for the table *picker*); `getStats`/`createTable`/`updateTable`/
/// `deleteTable` were added later for the admin table-management CRUD
/// screens.
abstract class TableService {
  final ApiService api;
  TableService(this.api);

  Future<TablePage> searchTables({
    final String? search,
    final String? status,
    final String? section,
    final bool? isActive,
    final int page,
    final int size,
    final String? sortBy,
  });

  /// Gets table statistics. Returns a [TableStats] or throws on failure.
  Future<TableStats> getStats();

  /// Creates a new table. Returns the created [RestaurantTable] or throws
  /// on failure (e.g. duplicate table number).
  Future<RestaurantTable> createTable(TableCreateRequest request);

  /// Updates an existing table's editable fields.
  Future<RestaurantTable> updateTable(int id, TableUpdateRequest request);

  /// Deletes a table. Throws if the table is currently OCCUPIED.
  Future<void> deleteTable(int id);
}

/// Hits the real backend (`/api/tables`) over HTTP. Selected when
/// `AppConfig.useApiTableService == true`.
class ApiTableService extends TableService {
  ApiTableService(super.api);

  @override
  Future<TablePage> searchTables({
    final String? search,
    final String? status,
    final String? section,
    final bool? isActive,
    final int page = 0,
    final int size = 20,
    final String? sortBy,
  }) async {
    final Map<String, dynamic> queryParameters = {
      if (search != null) 'search': search,
      if (status != null) 'status': status,
      if (section != null) 'section': section,
      if (isActive != null) 'isActive': isActive,
      'page': page,
      'size': size,
      if (sortBy != null) 'sortBy': sortBy,
    };
    final dynamic response = await api.get(
      '/api/tables',
      queryParameters: queryParameters,
    );
    return TablePage.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<TableStats> getStats() async {
    final dynamic response = await api.get('/api/tables/stats');
    return TableStats.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<RestaurantTable> createTable(TableCreateRequest request) async {
    final dynamic response = await api.post(
      '/api/tables',
      data: request.toJson(),
    );
    return RestaurantTable.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<RestaurantTable> updateTable(
      int id, TableUpdateRequest request) async {
    final dynamic response = await api.put(
      '/api/tables/$id',
      data: request.toJson(),
    );
    return RestaurantTable.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<void> deleteTable(int id) async {
    await api.delete('/api/tables/$id');
  }
}

/// Simple local implementation returning sample data — no
/// SharedPreferences, nothing to persist across restarts, same as source.
/// Selected when `AppConfig.useApiTableService == false`.
class LocalTableService extends TableService {
  LocalTableService(super.api);

  /// Mutable in-memory table list so create/update/delete are visible to
  /// the admin screen while running offline, without needing persistence.
  static final List<RestaurantTable> _tables = [RestaurantTable.sample()];
  static int _nextId = 2;

  @override
  Future<TablePage> searchTables({
    final String? search,
    final String? status,
    final String? section,
    final bool? isActive,
    final int page = 0,
    final int size = 20,
    final String? sortBy,
  }) async {
    final needle = (search ?? '').trim().toLowerCase();
    final matches = _tables.where((t) {
      final matchesSearch = needle.isEmpty ||
          t.tableNumber.toLowerCase().contains(needle) ||
          t.displayName.toLowerCase().contains(needle);
      final matchesStatus = status == null || t.status == status;
      final matchesSection = section == null || t.section == section;
      final matchesActive = isActive == null || t.isActive == isActive;
      return matchesSearch && matchesStatus && matchesSection && matchesActive;
    }).toList();

    return TablePage(
      content: matches,
      number: 0,
      size: matches.length,
      totalElements: matches.length,
      totalPages: 1,
    );
  }

  @override
  Future<TableStats> getStats() async => TableStats.sample();

  @override
  Future<RestaurantTable> createTable(TableCreateRequest request) async {
    if (_tables.any((t) => t.tableNumber == request.tableNumber)) {
      throw Exception('Table number already exists: ${request.tableNumber}');
    }
    final table = RestaurantTable(
      id: _nextId++,
      tableNumber: request.tableNumber,
      displayName: request.displayName?.isNotEmpty == true
          ? request.displayName!
          : request.tableNumber,
      status: 'AVAILABLE',
      capacity: request.capacity,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      section: request.section,
      notes: request.notes,
    );
    _tables.add(table);
    return table;
  }

  @override
  Future<RestaurantTable> updateTable(
      int id, TableUpdateRequest request) async {
    final index = _tables.indexWhere((t) => t.id == id);
    if (index == -1) throw Exception('Table not found');
    final updated = _tables[index].copyWith(
      displayName: request.displayName,
      capacity: request.capacity,
      section: request.section,
      notes: request.notes,
      status: request.status,
      isActive: request.isActive,
      updatedAt: DateTime.now(),
    );
    _tables[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteTable(int id) async {
    final table = _tables.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Table not found'),
    );
    if (table.status == 'OCCUPIED') {
      throw Exception('Cannot delete table that is currently occupied');
    }
    _tables.removeWhere((t) => t.id == id);
  }
}

/// SWITCH POINT — `AppConfig.useApiTableService`.
final Provider<TableService> tableServiceProvider =
    Provider<TableService>((final ref) {
  final api = ref.read(apiServiceProvider);
  if (AppConfig.useApiTableService) {
    return ApiTableService(api);
  }
  return LocalTableService(api);
});
