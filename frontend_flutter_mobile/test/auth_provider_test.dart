import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/models/auth_models.dart';
import 'package:frontend_flutter_mobile/core/providers/auth_provider.dart';
import 'package:frontend_flutter_mobile/core/services/api_service.dart';
import 'package:frontend_flutter_mobile/core/services/auth_service.dart';

/// Ported from `frontend-flutter-pos/test/auth_provider_test.dart` —
/// COPY/ADAPT NEARLY EXACTLY: same fake-JWT helper, same fake AuthService,
/// same startup-guard scenarios. See DAY_04.md section 14.
String _makeToken(Map<String, dynamic> payload) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  final header = segment(<String, String>{'alg': 'HS256', 'typ': 'JWT'});
  final body = segment(payload);
  return '$header.$body.signature';
}

const _user = User(
  id: 1,
  email: 'cashier@example.com',
  fullName: 'Cashier',
  roles: ['CASHIER'],
);

class _FakeAuthService extends AuthService {
  _FakeAuthService(this._token) : super(ApiService());

  String? _token;
  bool loggedOut = false;
  bool loginCalled = false;
  Object? loginError;

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<User?> getCurrentUser() async => _user;

  @override
  Future<void> logout() async {
    loggedOut = true;
    _token = null;
  }

  @override
  Future<AuthResponse> login(String email, String password,
      {String? terminalId}) async {
    loginCalled = true;
    if (loginError != null) throw loginError!;
    _token = _makeToken({
      'sub': email,
      'exp': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000,
    });
    return AuthResponse(token: _token!, user: _user);
  }
}

Future<void> _pumpUntilSettled(ProviderContainer container) async {
  for (var i = 0; i < 50; i++) {
    if (!container.read(authProvider).isLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  group('AuthNotifier startup guard', () {
    test('no cached token -> stays logged out', () async {
      final service = _FakeAuthService(null);
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);

      await _pumpUntilSettled(container);

      expect(container.read(authProvider).value, isNull);
    });

    test('expired cached token -> logs out and stays logged out', () async {
      final expired = _makeToken({
        'sub': 'cashier@example.com',
        'exp': DateTime.now()
                .toUtc()
                .subtract(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      });
      final service = _FakeAuthService(expired);
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);

      await _pumpUntilSettled(container);

      expect(container.read(authProvider).value, isNull);
      expect(service.loggedOut, isTrue);
    });

    test('valid cached token -> restores the cached user', () async {
      final valid = _makeToken({
        'sub': 'cashier@example.com',
        'exp': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      });
      final service = _FakeAuthService(valid);
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);

      await _pumpUntilSettled(container);

      expect(container.read(authProvider).value, _user);
      expect(service.loggedOut, isFalse);
    });
  });

  group('AuthNotifier.login', () {
    test('successful login sets state to the returned user', () async {
      final service = _FakeAuthService(null);
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      await _pumpUntilSettled(container);

      await container
          .read(authProvider.notifier)
          .login('cashier@example.com', 'Password123!');

      expect(service.loginCalled, isTrue);
      expect(container.read(authProvider).value, _user);
    });

    test('failed login surfaces the error via AsyncValue.error', () async {
      final service = _FakeAuthService(null)
        ..loginError = Exception('Invalid credentials');
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      await _pumpUntilSettled(container);

      await container
          .read(authProvider.notifier)
          .login('cashier@example.com', 'wrong-password');

      expect(container.read(authProvider).hasError, isTrue);
    });
  });

  group('AuthNotifier.logout', () {
    test('clears state and delegates to AuthService.logout', () async {
      final valid = _makeToken({
        'sub': 'cashier@example.com',
        'exp': DateTime.now()
                .toUtc()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
      });
      final service = _FakeAuthService(valid);
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      await _pumpUntilSettled(container);
      expect(container.read(authProvider).value, _user);

      await container.read(authProvider.notifier).logout();

      expect(service.loggedOut, isTrue);
      expect(container.read(authProvider).value, isNull);
    });
  });

  group('currentUserProvider / isAuthenticatedProvider', () {
    test('reflect the underlying authProvider state', () async {
      final service = _FakeAuthService(null);
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      await _pumpUntilSettled(container);

      expect(container.read(currentUserProvider), isNull);
      expect(container.read(isAuthenticatedProvider), isFalse);

      await container
          .read(authProvider.notifier)
          .login('cashier@example.com', 'Password123!');

      expect(container.read(currentUserProvider), _user);
      expect(container.read(isAuthenticatedProvider), isTrue);
    });
  });
}
