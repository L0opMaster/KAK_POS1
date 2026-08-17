import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/role_models.dart';
import '../services/role_service.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/providers/
/// role_provider.dart` — COPY/ADAPT NEARLY EXACTLY. `load()` fetches roles
/// and the full permission catalog together (two sequential service calls)
/// since desktop's permission browser and permission editor both just read
/// this same already-loaded state; there is no separate permission
/// provider/service to mirror.
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

  /// Replaces [roleId]'s entire permission set, then reloads roles +
  /// permissions from the server (matches source: no optimistic local
  /// patch, always re-fetch).
  Future<void> updateRolePermissions(
      int roleId, List<String> permissionNames) async {
    await _service.updateRolePermissions(roleId, permissionNames);
    await load();
  }
}

final roleProvider = StateNotifierProvider<RoleNotifier, RoleState>((ref) {
  return RoleNotifier(ref.watch(roleServiceProvider));
});
