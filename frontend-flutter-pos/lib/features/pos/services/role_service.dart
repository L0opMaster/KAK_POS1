import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/role_model.dart';

abstract class RoleService {
  Future<List<RoleModel>> listRoles();
  Future<List<PermissionModel>> listPermissions();
  Future<RoleModel> updateRolePermissions(int roleId, List<String> permissionNames);
}

class ApiRoleService extends RoleService {
  ApiRoleService(this._api);

  final ApiService _api;

  @override
  Future<List<RoleModel>> listRoles() async {
    final response = await _api.get<List<dynamic>>('/api/roles');
    return response.cast<Map<String, dynamic>>().map(RoleModel.fromJson).toList();
  }

  @override
  Future<List<PermissionModel>> listPermissions() async {
    final response = await _api.get<List<dynamic>>('/api/permissions');
    return response
        .cast<Map<String, dynamic>>()
        .map(PermissionModel.fromJson)
        .toList();
  }

  @override
  Future<RoleModel> updateRolePermissions(
      int roleId, List<String> permissionNames) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/api/roles/$roleId/permissions',
      data: {'permissions': permissionNames},
    );
    return RoleModel.fromJson(response);
  }
}

final Provider<RoleService> roleServiceProvider = Provider<RoleService>((ref) {
  return ApiRoleService(ref.read(apiServiceProvider));
});
