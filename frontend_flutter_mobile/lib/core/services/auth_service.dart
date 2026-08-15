import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../models/auth_models.dart';

/// Ported from `frontend-flutter-pos/lib/core/services/auth_service.dart` —
/// COPY/ADAPT NEARLY EXACTLY. Same ONLINE login call, same OFFLINE
/// SharedPreferences-cached-session pattern, same storage keys
/// (`AppConfig.authTokenKey`/`userKey`). See DAY_04.md section 7 for the
/// full function-by-function mapping.
class AuthService {
  AuthService(this._apiService);
  final ApiService _apiService;

  /// ONLINE — calls the backend to verify credentials. Used by:
  /// core/providers/auth_provider.dart (login flow, triggered from
  /// features/auth/screens/login_screen.dart). On success it hands off to
  /// the OFFLINE `_saveAuthData` below so the session survives app restarts.
  Future<AuthResponse> login(
    final String email,
    final String password, {
    final String? terminalId,
  }) async {
    final request =
        LoginRequest(email: email, password: password, terminalId: terminalId);
    final response = await _apiService.post<Map<String, dynamic>>(
      '/api/auth/login',
      data: request.toJson(),
    );

    final authResponse = AuthResponse.fromJson(response);
    await _saveAuthData(authResponse);
    return authResponse;
  }

  // ── OFFLINE — reads/writes the locally cached session, no network call.

  /// Clears the cached token/user. Used by auth_provider.dart's logout, and
  /// by ApiService's 401 interceptor to force a re-login when the backend
  /// rejects the session.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.authTokenKey);
    await prefs.remove(AppConfig.userKey);
  }

  /// Reads the cached bearer token. Used by ApiService (`_getAuthToken`) to
  /// stamp the `Authorization` header on every outgoing ONLINE request.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConfig.authTokenKey);
  }

  /// Reads the cached logged-in user. Used by auth_provider.dart to restore
  /// the session on app startup without calling the backend.
  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(AppConfig.userKey);
    if (userJson != null) {
      final userMap = json.decode(userJson) as Map<String, dynamic>;
      return User.fromJson(userMap);
    }
    return null;
  }

  /// Persists the token + user returned by the ONLINE `login()` call above
  /// into SharedPreferences.
  Future<void> _saveAuthData(final AuthResponse authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.authTokenKey, authResponse.token);
    await prefs.setString(
      AppConfig.userKey,
      json.encode(authResponse.user.toJson()),
    );
  }
}

final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (final Ref<AuthService> ref) => AuthService(apiService),
);
