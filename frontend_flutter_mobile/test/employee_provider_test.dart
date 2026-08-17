import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/models/employee_model.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/employee_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/employee_service.dart';

/// Fake EmployeeService — in-memory employees, no real HTTP.
class _FakeEmployeeService extends EmployeeService {
  List<EmployeeResponse> employees;
  bool throwOnList = false;
  int _nextId = 1000;

  _FakeEmployeeService({required this.employees}) : super(apiService);

  @override
  Future<List<EmployeeResponse>> listEmployees({
    String? query,
    String? status,
    String? department,
  }) async {
    if (throwOnList) throw Exception('boom');
    var results = employees;
    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results.where((e) => e.fullName.toLowerCase().contains(q)).toList();
    }
    return List.of(results);
  }

  @override
  Future<EmployeeResponse> createEmployee(EmployeeRequest request) async {
    final created = EmployeeResponse(
      id: _nextId++,
      fullName: request.fullName,
      baseSalary: request.baseSalary,
      payType: request.payType,
      status: request.status,
      linkedUserId: request.linkedUserId,
    );
    employees.add(created);
    return created;
  }

  @override
  Future<EmployeeResponse> updateEmployee(int id, EmployeeRequest request) async {
    final index = employees.indexWhere((e) => e.id == id);
    if (index < 0) throw Exception('not found');
    final updated = EmployeeResponse(
      id: id,
      fullName: request.fullName,
      baseSalary: request.baseSalary,
      payType: request.payType,
      status: request.status,
      linkedUserId: request.linkedUserId,
    );
    employees[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteEmployee(int id) async {
    employees.removeWhere((e) => e.id == id);
  }
}

EmployeeResponse _employee(int id, {String name = 'Employee', String status = 'ACTIVE'}) =>
    EmployeeResponse(
      id: id,
      fullName: '$name $id',
      baseSalary: 100,
      payType: 'MONTHLY',
      status: status,
    );

void main() {
  group('EmployeeNotifier', () {
    test('load() populates state.employees', () async {
      final service = _FakeEmployeeService(employees: [_employee(1), _employee(2)]);
      final notifier = EmployeeNotifier(service);
      await notifier.load();
      expect(notifier.state.employees, hasLength(2));
      expect(notifier.state.loading, isFalse);
    });

    test('load() sets state.error on failure', () async {
      final service = _FakeEmployeeService(employees: [])..throwOnList = true;
      final notifier = EmployeeNotifier(service);
      await notifier.load();
      expect(notifier.state.error, isNotNull);
      expect(notifier.state.employees, isEmpty);
    });

    test('load(query:) filters and remembers the query for later refreshes',
        () async {
      final service = _FakeEmployeeService(
        employees: [_employee(1, name: 'Alice'), _employee(2, name: 'Bob')],
      );
      final notifier = EmployeeNotifier(service);
      await notifier.load(query: 'alice');
      expect(notifier.state.employees, hasLength(1));
      expect(notifier.state.employees.single.fullName, 'Alice 1');
      expect(notifier.state.query, 'alice');
    });

    test('create() adds an employee and refreshes state', () async {
      final service = _FakeEmployeeService(employees: []);
      final notifier = EmployeeNotifier(service);
      await notifier.load();

      final created = await notifier.create(
        const EmployeeRequest(fullName: 'New Hire', baseSalary: 500, payType: 'MONTHLY', status: 'ACTIVE'),
      );
      expect(created.fullName, 'New Hire');
      expect(notifier.state.employees, hasLength(1));
    });

    test('update() modifies an employee and refreshes state', () async {
      final service = _FakeEmployeeService(employees: [_employee(1, name: 'Old')]);
      final notifier = EmployeeNotifier(service);
      await notifier.load();

      await notifier.update(
        1,
        const EmployeeRequest(fullName: 'New Name', baseSalary: 100, payType: 'MONTHLY', status: 'ACTIVE'),
      );
      expect(notifier.state.employees.single.fullName, 'New Name');
    });

    test('delete() removes an employee and refreshes state', () async {
      final service = _FakeEmployeeService(employees: [_employee(1), _employee(2)]);
      final notifier = EmployeeNotifier(service);
      await notifier.load();
      expect(notifier.state.employees, hasLength(2));

      await notifier.delete(1);
      expect(notifier.state.employees.map((e) => e.id), [2]);
    });
  });
}
