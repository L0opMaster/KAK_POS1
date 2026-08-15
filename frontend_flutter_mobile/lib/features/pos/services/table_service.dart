import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../models/table_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// table_service.dart` — PARTIAL PORT. `searchTables` only —
/// `getStats`/`createTable`/`updateTable`/`deleteTable` (admin
/// dashboard/CRUD, out of scope) dropped from the abstract contract
/// entirely, matching how Day 6 trimmed `ProductService`.
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
}

/// Simple local implementation returning sample data — no
/// SharedPreferences, nothing to persist across restarts, same as source.
/// Selected when `AppConfig.useApiTableService == false`.
class LocalTableService extends TableService {
  LocalTableService(super.api);

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
    return TablePage.sample();
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
