// ignore_for_file: public_member_api_docs, sort_constructors_first
/// Ported from `frontend-flutter-pos/lib/features/pos/models/
/// user_account_model.dart` — COPY/ADAPT NEARLY EXACTLY. Same flat shape:
/// `UserAccountResponse` mirrors what `GET /api/users` returns, and
/// `UserAccountCreateRequest` is the `POST /api/users` payload (`roles` is
/// required and, per the UI, only ever populated with a single selected
/// role name).
class UserAccountResponse {
  final int id;
  final String email;
  final String fullName;
  final bool active;
  final List<String> roles;

  UserAccountResponse({
    required this.id,
    required this.email,
    required this.fullName,
    required this.active,
    required this.roles,
  });

  factory UserAccountResponse.fromJson(Map<String, dynamic> json) {
    return UserAccountResponse(
      id: (json['id'] as num?)?.toInt() ?? 0,
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      roles: (json['roles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'active': active,
      'roles': roles,
    };
  }
}

class UserAccountCreateRequest {
  final String email;
  final String fullName;
  final String password;
  final List<String> roles;

  UserAccountCreateRequest({
    required this.email,
    required this.fullName,
    required this.password,
    required this.roles,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'fullName': fullName,
      'password': password,
      'roles': roles,
    };
  }
}
