import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/auth_models.dart';

// Auth notifier
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _initializeAuth();
  }
  final AuthService _authService;

  Future<void> _initializeAuth() async {
    try {
      // Only navigate to POS if BOTH token and user exist
      final token = await _authService.getToken();
      final user = token != null ? await _authService.getCurrentUser() : null;
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

// Provider
final StateNotifierProvider<AuthNotifier, AsyncValue<User?>> authProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>(
        (final StateNotifierProviderRef<AuthNotifier, AsyncValue<User?>> ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience providers
final Provider<User?> currentUserProvider = Provider<User?>(
  (final Ref<User?> ref) => ref.watch(authProvider).maybeWhen(
        data: (final User? user) => user,
        orElse: () => null,
      ),
);

final Provider<bool> isAuthenticatedProvider = Provider<bool>(
  (final Ref<bool> ref) => ref.watch(currentUserProvider) != null,
);

final Provider<bool> isLoadingProvider =
    Provider<bool>((final Ref<bool> ref) => ref.watch(authProvider).isLoading);
