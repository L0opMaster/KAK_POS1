import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/features/pos/models/role_model.dart';
import 'package:frontend_flutter_pos/features/pos/services/role_service.dart';

class RoleState {
  final bool loading;
  final List<RoleModel> roles;
  final List<PermissionModel> permissions;
  final String? error;

  const RoleState({
    required this.loading,
    required this.roles,
    required this.permissions,
    this.error,
  });

  factory RoleState.initial() =>
      const RoleState(loading: false, roles: [], permissions: []);

  RoleState copyWith({
    bool? loading,
    List<RoleModel>? roles,
    List<PermissionModel>? permissions,
    String? error,
    bool clearError = false,
  }) {
    return RoleState(
      loading: loading ?? this.loading,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class RoleNotifier extends StateNotifier<RoleState> {
  final RoleService _service;

  RoleNotifier(this._service) : super(RoleState.initial());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final roles = await _service.listRoles();
      final permissions = await _service.listPermissions();
      state = state.copyWith(
        loading: false,
        clearError: true,
        roles: roles,
        permissions: permissions,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> updateRolePermissions(
      int roleId, List<String> permissionNames) async {
    await _service.updateRolePermissions(roleId, permissionNames);
    await load();
  }
}

final roleProvider = StateNotifierProvider<RoleNotifier, RoleState>((ref) {
  return RoleNotifier(ref.watch(roleServiceProvider));
});
