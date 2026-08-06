import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/features/pos/models/employee_model.dart';
import 'package:frontend_flutter_pos/features/pos/services/employee_service.dart';

class EmployeeSate {
  final bool loading;
  final List<EmployeeResponse> employees;
  final String? error;
  final String query;
  final String? status;
  final String? department;

  const EmployeeSate({
    required this.loading,
    required this.employees,
    this.error,
    this.query = '',
    this.department,
    this.status,
  });

  factory EmployeeSate.initial() =>
      const EmployeeSate(loading: false, employees: []);

  EmployeeSate copyWith({
    bool? loading,
    List<EmployeeResponse>? employees,
    String? error,
    String? query,
    String? status,
    String? department,
    bool clearError = false,
  }) {
    return EmployeeSate(
        loading: loading ?? this.loading,
        employees: employees ?? this.employees,
        error: clearError ? null : error ?? this.error,
        query: query ?? this.query,
        status: status ?? this.status,
        department: department ?? this.department);
  }
}

class EmployeeNotifier extends StateNotifier<EmployeeSate> {
  final EmployeeService _service;

  EmployeeNotifier(this._service) : super(EmployeeSate.initial());

  Future<void> load(
      {String query = '', String? status, String? department}) async {
    state = state.copyWith(
        loading: true,
        query: query,
        clearError: true,
        status: status,
        department: department);

    try {
      final employees = await _service.listEmployees(
          query: query, status: status, department: department);

      state = state.copyWith(
          loading: false, clearError: true, employees: employees);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> create(EmployeeRequest request) async {
    await _service.createEmployee(request);
    await load(
        query: state.query, status: state.status, department: state.department);
  }

  Future<void> update(int id, EmployeeRequest request) async {
    await _service.updateEmployee(id, request);
    await load(
        query: state.query, status: state.status, department: state.department);
  }

  Future<void> delete(int id) async {
    await _service.deleteEmployee(id);
    await load(
        query: state.query, status: state.status, department: state.department);
  }
}

final employeeProvider =
    StateNotifierProvider<EmployeeNotifier, EmployeeSate>((ref) {
  return EmployeeNotifier(ref.watch(employeeServiceProvider));
});
