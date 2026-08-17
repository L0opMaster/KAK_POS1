import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/employee_model.dart';
import '../services/employee_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// employee_provider.dart` — COPY/ADAPT NEARLY EXACTLY (source's state
/// class is literally misspelled `EmployeeSate`; not reproduced here).
/// `create`/`update`/`delete` all re-run `load()` with the last-used
/// query/status/department afterward instead of patching state locally,
/// matching source.
class EmployeeState {
  final bool loading;
  final List<EmployeeResponse> employees;
  final String? error;
  final String query;
  final String? status;
  final String? department;

  const EmployeeState({
    required this.loading,
    required this.employees,
    this.error,
    this.query = '',
    this.status,
    this.department,
  });

  factory EmployeeState.initial() =>
      const EmployeeState(loading: false, employees: []);

  EmployeeState copyWith({
    bool? loading,
    List<EmployeeResponse>? employees,
    String? error,
    bool clearError = false,
    String? query,
    String? status,
    String? department,
  }) {
    return EmployeeState(
      loading: loading ?? this.loading,
      employees: employees ?? this.employees,
      error: clearError ? null : error ?? this.error,
      query: query ?? this.query,
      status: status ?? this.status,
      department: department ?? this.department,
    );
  }
}

class EmployeeNotifier extends StateNotifier<EmployeeState> {
  final EmployeeService _service;

  EmployeeNotifier(this._service) : super(EmployeeState.initial());

  Future<void> load({String? query, String? status, String? department}) async {
    final effectiveQuery = query ?? state.query;
    final effectiveStatus = status ?? state.status;
    final effectiveDepartment = department ?? state.department;
    state = state.copyWith(
      loading: true,
      clearError: true,
      query: effectiveQuery,
      status: effectiveStatus,
      department: effectiveDepartment,
    );
    try {
      final employees = await _service.listEmployees(
        query: effectiveQuery,
        status: effectiveStatus,
        department: effectiveDepartment,
      );
      state = state.copyWith(loading: false, clearError: true, employees: employees);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<EmployeeResponse> create(EmployeeRequest request) async {
    final created = await _service.createEmployee(request);
    await load();
    return created;
  }

  Future<EmployeeResponse> update(int id, EmployeeRequest request) async {
    final updated = await _service.updateEmployee(id, request);
    await load();
    return updated;
  }

  Future<void> delete(int id) async {
    await _service.deleteEmployee(id);
    await load();
  }
}

final employeeProvider = StateNotifierProvider<EmployeeNotifier, EmployeeState>((ref) {
  return EmployeeNotifier(ref.watch(employeeServiceProvider));
});
