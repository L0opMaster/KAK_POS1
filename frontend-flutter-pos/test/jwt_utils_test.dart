import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/utils/jwt_utils.dart';

String _makeToken(Map<String, dynamic> payload) {
  String segment(Object value) =>
      base64Url.encode(utf8.encode(json.encode(value))).replaceAll('=', '');
  final header = segment(<String, String>{'alg': 'HS256', 'typ': 'JWT'});
  final body = segment(payload);
  return '$header.$body.signature';
}

void main() {
  group('isJwtExpired', () {
    test('false for a token with a future exp claim', () {
      final future = DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      expect(isJwtExpired(_makeToken({'exp': future})), isFalse);
    });

    test('true for a token with a past exp claim', () {
      final past = DateTime.now()
              .toUtc()
              .subtract(const Duration(hours: 1))
              .millisecondsSinceEpoch ~/
          1000;
      expect(isJwtExpired(_makeToken({'exp': past})), isTrue);
    });

    test('true for a token with no exp claim', () {
      expect(isJwtExpired(_makeToken({'sub': 'user@example.com'})), isTrue);
    });

    test('true for a malformed token', () {
      expect(isJwtExpired('not-a-jwt'), isTrue);
    });

    test('true for an empty string', () {
      expect(isJwtExpired(''), isTrue);
    });
  });
}
