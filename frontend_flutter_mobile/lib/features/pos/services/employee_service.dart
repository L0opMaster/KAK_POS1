import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/employee_model.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// employee_service.dart` — COPY/ADAPT NEARLY EXACTLY. Same endpoints, same
/// query params.
class EmployeeService {
  final ApiService _api;

  EmployeeService(this._api);

  Future<List<EmployeeResponse>> listEmployees({
    String? query,
    String? status,
    String? department,
  }) async {
    final resp = await _api.get<List<dynamic>>(
      '/api/employees',
      queryParameters: {
        if (query != null && query.isNotEmpty) 'q': query,
        if (status != null) 'status': status,
        if (department != null) 'department': department,
      },
    );
    return resp
        .cast<Map<String, dynamic>>()
        .map((e) => EmployeeResponse.fromJson(e))
        .toList();
  }

  Future<EmployeeResponse> createEmployee(EmployeeRequest request) async {
    final resp = await _api.post<Map<String, dynamic>>(
      '/api/employees',
      data: request.toJson(),
    );
    return EmployeeResponse.fromJson(resp);
  }

  Future<EmployeeResponse> updateEmployee(int id, EmployeeRequest request) async {
    final resp = await _api.put<Map<String, dynamic>>(
      '/api/employees/$id',
      data: request.toJson(),
    );
    return EmployeeResponse.fromJson(resp);
  }

  Future<void> deleteEmployee(int id) async {
    await _api.delete<dynamic>('/api/employees/$id');
  }
}

final employeeServiceProvider = Provider<EmployeeService>((ref) {
  return EmployeeService(ref.read(apiServiceProvider));
});
