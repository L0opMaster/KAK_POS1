import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

@JsonSerializable()
class User extends Equatable {
  const User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.roles,
    this.permissions,
  });

  factory User.fromJson(final Map<String, dynamic> json) =>
      _$UserFromJson(json);
  final int id;
  final String email;
  final String fullName;
  final List<String> roles;
  final List<String>? permissions;
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  List<Object?> get props => <Object?>[id, email, fullName, roles, permissions];
}

@JsonSerializable()
class AuthResponse extends Equatable {
  const AuthResponse({
    required this.token,
    required this.user,
  });

  factory AuthResponse.fromJson(final Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  final String token;
  final User user;
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);

  @override
  List<Object> get props => <Object>[token, user];
}

@JsonSerializable()
class LoginRequest extends Equatable {
  const LoginRequest({
    required this.email,
    required this.password,
    this.terminalId,
  });

  factory LoginRequest.fromJson(final Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  final String email;
  final String password;
  final String? terminalId;
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);

  @override
  List<Object?> get props => <Object?>[email, password, terminalId];
}
