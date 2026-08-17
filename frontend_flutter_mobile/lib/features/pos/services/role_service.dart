import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/api_service.dart';
import '../models/role_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// role_service.dart` — COPY/ADAPT NEARLY EXACTLY. Role management in this
/// app is strictly "assign permissions to a fixed set of pre-existing
/// roles": there is no create/edit-name/delete-role endpoint, so this
/// service only exposes listing roles, listing the full permission
/// catalog, and replacing a role's entire permission set in one PUT.
class RoleService {
  final ApiService _api;

  RoleService(this._api);

  /// List all roles, each with its full embedded list of granted
  /// permissions.
  Future<List<RoleModel>> listRoles() async {
    final response = await _api.get<List<dynamic>>('/api/roles');
    return response
        .cast<Map<String, dynamic>>()
        .map(RoleModel.fromJson)
        .toList();
  }

  /// List the full system permission catalog (flat, no categories).
  Future<List<PermissionModel>> listPermissions() async {
    final response = await _api.get<List<dynamic>>('/api/permissions');
    return response
        .cast<Map<String, dynamic>>()
        .map(PermissionModel.fromJson)
        .toList();
  }

  /// Replace a role's entire permission set — not a per-permission diff.
  Future<RoleModel> updateRolePermissions(
      int roleId, List<String> permissionNames) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/roles/$roleId/permissions',
      data: {'permissions': permissionNames},
    );
    return RoleModel.fromJson(response);
  }
}

final roleServiceProvider = Provider<RoleService>((ref) {
  return RoleService(ref.watch(apiServiceProvider));
});
