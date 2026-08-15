import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_models.dart';
import '../services/auth_service.dart';
import '../utils/jwt_utils.dart';

/// Ported from `frontend-flutter-pos/lib/core/providers/auth_provider.dart`
/// — COPY/ADAPT NEARLY EXACTLY. Same `StateNotifier<AsyncValue<User?>>`
/// shape, same startup JWT-expiry guard, same login/logout/refreshUser
/// bodies. See DAY_04.md section 7 for the full function-by-function
/// mapping and section 8 for the login click flow.
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }
  final AuthService _authService;

  /// Runs once, at provider creation (app startup). Only restores a session
  /// if BOTH a cached token and user exist AND the token's `exp` claim
  /// hasn't passed — a cached-but-expired token would otherwise let the app
  /// boot straight past LoginScreen and only fail on the first API call.
  Future<void> _initializeAuth() async {
    try {
      final token = await _authService.getToken();
      if (token == null || isJwtExpired(token)) {
        if (token != null) {
          await _authService.logout();
        }
        state = const AsyncValue.data(null);
        return;
      }
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> login(
    final String email,
    final String password, {
    final String? terminalId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final authResponse =
          await _authService.login(email, password, terminalId: terminalId);
      state = AsyncValue.data(authResponse.user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final StateNotifierProvider<AuthNotifier, AsyncValue<User?>> authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
        (final Ref<AsyncValue<User?>> ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

final Provider<User?> currentUserProvider = Provider<User?>(
  (final Ref<User?> ref) => ref.watch(authProvider).maybeWhen(
        data: (final User? user) => user,
        orElse: () => null,
      ),
);

final Provider<bool> isAuthenticatedProvider = Provider<bool>(
  (final Ref<bool> ref) => ref.watch(currentUserProvider) != null,
);
