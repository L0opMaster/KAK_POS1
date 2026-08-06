import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/employee_model.dart';

abstract class EmployeeService {
  Future<List<EmployeeResponse>> listEmployees({
    String query = '',
    String? status,
    String? department,
  });
  Future<EmployeeResponse> createEmployee(EmployeeRequest request);
  Future<EmployeeResponse> updateEmployee(int id, EmployeeRequest request);
  Future<void> deleteEmployee(int id);
}

class ApiEmployeeService extends EmployeeService {
  ApiEmployeeService(this._api);

  final ApiService _api;

  @override
  Future<List<EmployeeResponse>> listEmployees({
    String query = '',
    String? status,
    String? department,
  }) async {
    final response = await _api.get<List<dynamic>>(
      '/api/employees',
      queryParameters: {'q': query, 'status': status, 'department': department},
    );
    return response
        .cast<Map<String, dynamic>>()
        .map(EmployeeResponse.fromJson)
        .toList();
  }

  @override
  Future<EmployeeResponse> createEmployee(EmployeeRequest request) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/api/employees',
      data: request.toJson(),
    );
    return EmployeeResponse.fromJson(response);
  }

  @override
  Future<EmployeeResponse> updateEmployee(int id, EmployeeRequest request) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/employees/$id',
      data: request.toJson(),
    );
    return EmployeeResponse.fromJson(response);
  }

  @override
  Future<void> deleteEmployee(int id) async {
    await _api.delete<void>('/api/employees/$id');
  }
}

final Provider<EmployeeService> employeeServiceProvider =
    Provider<EmployeeService>((final ref) {
  return ApiEmployeeService(ref.read(apiServiceProvider));
});
