import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/models/auth_models.dart';
import 'package:frontend_flutter_pos/core/providers/auth_provider.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/core/services/auth_service.dart';

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

  @override
  Future<String?> getToken() async => _token;

  @override
  Future<User?> getCurrentUser() async => _user;

  @override
  Future<void> logout() async {
    loggedOut = true;
    _token = null;
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
      expect(service.loggedOut, isFalse);
    });

    test('expired cached token -> forced back to logged out, session cleared',
        () async {
      final past = DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final service = _FakeAuthService(_makeToken({'exp': past}));
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);

      await _pumpUntilSettled(container);

      expect(container.read(authProvider).value, isNull);
      expect(service.loggedOut, isTrue);
    });

    test('valid cached token -> restores the session', () async {
      final future = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      final service = _FakeAuthService(_makeToken({'exp': future}));
      final container = ProviderContainer(overrides: [
        authServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);

      await _pumpUntilSettled(container);

      expect(container.read(authProvider).value, _user);
      expect(service.loggedOut, isFalse);
    });
  });
}
