// ignore_for_file: public_member_api_docs, sort_constructors_first
/// Ported from `frontend-flutter-pos/lib/features/pos/models/role_model.dart`
/// — COPY/ADAPT NEARLY EXACTLY. Same flat shape: a permission is just
/// `id`/`name`/`description`, and a role embeds its full list of granted
/// permission objects (not just names/ids). No `toJson` existed in the
/// source models; both are added here since the mobile `RoleService`
/// convention keeps model classes self-serializing where practical, but
/// note the actual PUT payload for permission updates is a bare
/// `{'permissions': List<String>}` — these `toJson`s aren't used for that
/// call, only for potential local caching/debugging.
class PermissionModel {
  final int id;
  final String name;
  final String? description;

  PermissionModel({required this.id, required this.name, this.description});

  factory PermissionModel.fromJson(Map<String, dynamic> json) {
    return PermissionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (description != null) 'description': description,
      };
}

class RoleModel {
  final int id;
  final String name;
  final List<PermissionModel> permissions;

  RoleModel({required this.id, required this.name, required this.permissions});

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => PermissionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'permissions': permissions.map((p) => p.toJson()).toList(),
      };
}
