import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/unit_models.dart';

/// Service for unit-of-measure CRUD operations.
/// Matches the backend UnitController REST API (`/api/units`).
///
/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// unit_service.dart` — COPY/ADAPT NEARLY EXACTLY.
class UnitService {
  final ApiService _api;

  UnitService(this._api);

  /// Lists units matching [query]/[active], newest-first page of [size]
  /// starting at [page] — the backend returns a Spring `Page`, so the rows
  /// live under the response's `content` key.
  Future<List<Unit>> list({
    String query = '',
    bool? active,
    int page = 0,
    int size = 200,
  }) async {
    final resp = await _api.get<Map<String, dynamic>>(
      '/api/units',
      queryParameters: {
        'q': query,
        if (active != null) 'active': active,
        'page': page,
        'size': size,
      },
    );
    final content = (resp['content'] as List<dynamic>? ?? const []);
    return content
        .cast<Map<String, dynamic>>()
        .map((e) => Unit.fromJson(e))
        .toList();
  }

  Future<Unit> create(Map<String, dynamic> data) async {
    final resp = await _api.post<Map<String, dynamic>>('/api/units', data: data);
    return Unit.fromJson(resp);
  }

  Future<Unit> update(int id, Map<String, dynamic> data) async {
    final resp =
        await _api.put<Map<String, dynamic>>('/api/units/$id', data: data);
    return Unit.fromJson(resp);
  }

  Future<Unit> updateStatus(int id, bool active) async {
    final resp = await _api.patch<Map<String, dynamic>>(
      '/api/units/$id/status',
      data: {'active': active},
    );
    return Unit.fromJson(resp);
  }
}

final unitServiceProvider = Provider<UnitService>((ref) {
  return UnitService(ref.read(apiServiceProvider));
});
