// Short-term: silence some non-critical analyzer rules in this core service
// to keep onboarding focused. Remove or tighten these ignores later.
// ignore_for_file: public_member_api_docs, unnecessary_final, always_specify_types,
//   directives_ordering, type_annotate_public_apis, omit_local_variable_types

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/app_config.dart';
import '../../core/services/api_service.dart';
import '../models/auth_models.dart';

class AuthService {
  AuthService(this._apiService);
  final ApiService _apiService;

  // ── ONLINE ────────────────────────────────────────────────────────────
  // Calls the backend to verify credentials. Used by:
  // core/providers/auth_provider.dart (login flow triggered from
  // features/auth/screens/login_screen.dart). On success it hands off to the
  // OFFLINE `_saveAuthData` below so the session survives app restarts.
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

  // ── OFFLINE ───────────────────────────────────────────────────────────
  // Everything below reads/writes the locally cached session
  // (SharedPreferences keys AppConfig.authTokenKey / AppConfig.userKey) and
  // makes no network call. This is what lets the app know "am I logged in"
  // without hitting the backend, e.g. on cold start or when offline.

  /// Clears the cached token/user. Used by auth_provider.dart's logout, and
  /// by ApiService's 401 interceptor (see api_service.dart onUnauthorized)
  /// to force a re-login when the backend rejects the session.
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

  /// True when both a token and a user are cached locally. Purely an
  /// OFFLINE/local check — it does not verify the token is still valid on
  /// the backend (that only surfaces later, via a 401 on the next ONLINE
  /// call).
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    final user = await getCurrentUser();
    return token != null && user != null;
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

// Provider
final Provider<AuthService> authServiceProvider = Provider<AuthService>(
  (final Ref<AuthService> ref) => AuthService(apiService),
);
