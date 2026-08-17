import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/features/pos/models/role_models.dart';
import 'package:frontend_flutter_mobile/features/pos/providers/role_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/role_service.dart';

/// Fake RoleService — in-memory roles/permissions, no real HTTP.
/// `RoleService`'s methods aren't `final`, so (mirroring
/// `category_provider_test.dart`'s `_FakeCategoryService` pattern) this can
/// subclass the concrete service directly and never touch the `ApiService`
/// it's constructed with.
class _FakeRoleService extends RoleService {
  List<RoleModel> roles;
  List<PermissionModel> permissions;
  bool throwOnListRoles = false;
  bool throwOnUpdate = false;

  _FakeRoleService({required this.roles, required this.permissions})
      : super(apiService);

  @override
  Future<List<RoleModel>> listRoles() async {
    if (throwOnListRoles) throw Exception('boom');
    return List.of(roles);
  }

  @override
  Future<List<PermissionModel>> listPermissions() async {
    return List.of(permissions);
  }

  @override
  Future<RoleModel> updateRolePermissions(
      int roleId, List<String> permissionNames) async {
    if (throwOnUpdate) throw Exception('update failed');
    final index = roles.indexWhere((r) => r.id == roleId);
    if (index < 0) throw Exception('role not found');
    final newPermissions = permissions
        .where((p) => permissionNames.contains(p.name))
        .toList();
    final updated = RoleModel(
      id: roleId,
      name: roles[index].name,
      permissions: newPermissions,
    );
    roles[index] = updated;
    return updated;
  }
}

void main() {
  group('RoleNotifier', () {
    late List<PermissionModel> permissions;

    setUp(() {
      permissions = [
        PermissionModel(id: 1, name: 'sales.view', description: 'View sales'),
        PermissionModel(id: 2, name: 'sales.edit', description: 'Edit sales'),
        PermissionModel(id: 3, name: 'users.manage', description: null),
      ];
    });

    test('load() populates both roles and permissions', () async {
      final roles = [
        RoleModel(id: 1, name: 'Admin', permissions: [permissions[0]]),
        RoleModel(id: 2, name: 'Cashier', permissions: []),
      ];
      final service =
          _FakeRoleService(roles: roles, permissions: permissions);
      final notifier = RoleNotifier(service);

      await notifier.load();

      expect(notifier.state.loading, isFalse);
      expect(notifier.state.error, isNull);
      expect(notifier.state.roles.length, 2);
      expect(notifier.state.roles.map((r) => r.name),
          containsAll(['Admin', 'Cashier']));
      expect(notifier.state.permissions.length, 3);
      expect(notifier.state.permissions.map((p) => p.name),
          containsAll(['sales.view', 'sales.edit', 'users.manage']));
    });

    test(
        'updateRolePermissions updates the target role and leaves others '
        'untouched', () async {
      final roles = [
        RoleModel(id: 1, name: 'Admin', permissions: [permissions[0]]),
        RoleModel(
          id: 2,
          name: 'Cashier',
          permissions: [permissions[0], permissions[1]],
        ),
      ];
      final service =
          _FakeRoleService(roles: roles, permissions: permissions);
      final notifier = RoleNotifier(service);
      await notifier.load();

      await notifier.updateRolePermissions(1, ['sales.view', 'users.manage']);

      final admin = notifier.state.roles.firstWhere((r) => r.id == 1);
      final cashier = notifier.state.roles.firstWhere((r) => r.id == 2);
      expect(
        admin.permissions.map((p) => p.name),
        containsAll(['sales.view', 'users.manage']),
      );
      expect(admin.permissions.length, 2);
      // Untouched — Cashier's permission set is unaffected by Admin's
      // update, since it's a full replace scoped to a single role.
      expect(
        cashier.permissions.map((p) => p.name),
        containsAll(['sales.view', 'sales.edit']),
      );
      expect(cashier.permissions.length, 2);
    });

    test('load() sets an error on failure', () async {
      final service = _FakeRoleService(roles: [], permissions: permissions)
        ..throwOnListRoles = true;
      final notifier = RoleNotifier(service);

      await notifier.load();

      expect(notifier.state.error, isNotNull);
      expect(notifier.state.loading, isFalse);
    });

    test('updateRolePermissions failure surfaces as a thrown exception',
        () async {
      final roles = [
        RoleModel(id: 1, name: 'Admin', permissions: []),
      ];
      final service = _FakeRoleService(roles: roles, permissions: permissions)
        ..throwOnUpdate = true;
      final notifier = RoleNotifier(service);
      await notifier.load();

      await expectLater(
        notifier.updateRolePermissions(1, ['sales.view']),
        throwsException,
      );
    });
  });
}
