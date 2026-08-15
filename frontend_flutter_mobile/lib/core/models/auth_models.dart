/// Ported from `frontend-flutter-pos/lib/core/models/auth_models.dart` —
/// RECREATE USING SAME LOGIC, not a byte-for-byte copy. The source classes
/// use `@JsonSerializable()` (json_annotation) + `Equatable`, generated via
/// build_runner into `auth_models.g.dart`. This port hand-writes
/// `fromJson`/`toJson` instead of adding json_annotation/equatable/
/// build_runner as new mobile dependencies for a single small model file —
/// `cart_models.dart`-equivalent files in `[OLD/SOURCE]` already use plain
/// hand-written classes (no codegen) for exactly this reason, so this
/// follows THAT established in-repo pattern rather than the auth-specific
/// one. Field names, JSON keys, and nullability are identical to source; see
/// DAY_04.md section 7 for the full mapping. `==`/`hashCode` (Equatable in
/// source) were intentionally NOT reproduced — nothing in the auth flow
/// compares `User`/`AuthResponse` instances for equality.
class User {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    this.permissions,
  });

  factory User.fromJson(final Map<String, dynamic> json) => User(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        fullName: json['fullName'] as String,
        roles: (json['roles'] as List<dynamic>).map((e) => e as String).toList(),
        permissions: (json['permissions'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
      );

  final int id;
  final String email;
  final String fullName;
  final List<String> roles;
  final List<String>? permissions;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'email': email,
        'fullName': fullName,
        'roles': roles,
        'permissions': permissions,
      };
}

class AuthResponse {
  const AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(final Map<String, dynamic> json) =>
      AuthResponse(
        token: json['token'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String token;
  final User user;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'token': token,
        'user': user.toJson(),
      };
}

class LoginRequest {
  const LoginRequest({
    required this.email,
    required this.password,
    this.terminalId,
  });

  final String email;
  final String password;
  final String? terminalId;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'password': password,
        'terminalId': terminalId,
      };
}
