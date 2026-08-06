// ignore_for_file: public_member_api_docs, sort_constructors_first
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
}
