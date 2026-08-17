import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/services/scanner_relay_role.dart';

void main() {
  group('buildScannerWebSocketUri', () {
    test('maps http scheme to ws and builds the expected shape', () {
      final Uri uri = buildScannerWebSocketUri(
        serverBaseUrl: 'http://192.168.1.101:8081',
        sessionCode: 'abcd2345',
        role: ScannerRelayRole.scanner,
      );

      expect(uri.scheme, 'ws');
      expect(uri.host, '192.168.1.101');
      expect(uri.port, 8081);
      expect(uri.path, '/ws/scanner');
      expect(uri.queryParameters['session'], 'ABCD2345');
      expect(uri.queryParameters['role'], 'scanner');
    });

    test('maps https scheme to wss', () {
      final Uri uri = buildScannerWebSocketUri(
        serverBaseUrl: 'https://pos.example.com',
        sessionCode: 'zzzz9999',
        role: ScannerRelayRole.pos,
      );

      expect(uri.scheme, 'wss');
      expect(uri.host, 'pos.example.com');
      expect(uri.path, '/ws/scanner');
      expect(uri.queryParameters['session'], 'ZZZZ9999');
      expect(uri.queryParameters['role'], 'pos');
    });

    test('uppercases and trims the session code', () {
      final Uri uri = buildScannerWebSocketUri(
        serverBaseUrl: 'http://localhost:8081',
        sessionCode: '  a1b2c3d4  ',
        role: ScannerRelayRole.scanner,
      );

      expect(uri.queryParameters['session'], 'A1B2C3D4');
    });

    test('throws a FormatException when the base URL has no host', () {
      expect(
        () => buildScannerWebSocketUri(
          serverBaseUrl: 'not a url',
          sessionCode: 'ABCD2345',
          role: ScannerRelayRole.scanner,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ScannerRelayMessage.fromJson', () {
    test('parses a barcode message with type and value', () {
      final message = ScannerRelayMessage.fromJson(<String, dynamic>{
        'type': 'barcode',
        'value': '012345678905',
      });

      expect(message.type, 'barcode');
      expect(message.value, '012345678905');
      expect(message.message, isNull);
    });

    test('parses a barcode_ack message', () {
      final message = ScannerRelayMessage.fromJson(<String, dynamic>{
        'type': 'barcode_ack',
        'value': '012345678905',
      });

      expect(message.type, 'barcode_ack');
      expect(message.value, '012345678905');
    });

    test('parses an error message with a message field and no value', () {
      final message = ScannerRelayMessage.fromJson(<String, dynamic>{
        'type': 'error',
        'message': 'Invalid response from scanner relay',
      });

      expect(message.type, 'error');
      expect(message.value, isNull);
      expect(message.message, 'Invalid response from scanner relay');
    });

    test('parses bare status messages (ready, scanner_connected, etc.)', () {
      for (final String type in <String>[
        'ready',
        'scanner_connected',
        'scanner_disconnected',
        'pos_disconnected',
      ]) {
        final message = ScannerRelayMessage.fromJson(<String, dynamic>{
          'type': type,
        });
        expect(message.type, type);
        expect(message.value, isNull);
        expect(message.message, isNull);
      }
    });

    test('defaults type to "unknown" when the type field is missing', () {
      final message = ScannerRelayMessage.fromJson(<String, dynamic>{});

      expect(message.type, 'unknown');
      expect(message.value, isNull);
      expect(message.message, isNull);
    });

    test('defaults type to "unknown" when the type field is null', () {
      final message = ScannerRelayMessage.fromJson(<String, dynamic>{
        'type': null,
        'value': 'ignored',
      });

      expect(message.type, 'unknown');
      expect(message.value, 'ignored');
    });
  });

  group('ScannerRelayClient.sendBarcode', () {
    test('is a safe no-op when never connected', () {
      final client = ScannerRelayClient();

      expect(client.state, ScannerRelayConnectionState.disconnected);
      expect(() => client.sendBarcode('012345678905'), returnsNormally);
      expect(client.state, ScannerRelayConnectionState.disconnected);
    });

    test('is a safe no-op for an empty/whitespace-only value', () {
      final client = ScannerRelayClient();

      expect(() => client.sendBarcode(''), returnsNormally);
      expect(() => client.sendBarcode('   '), returnsNormally);
    });

    test('dispose after never connecting is also a safe no-op', () async {
      final client = ScannerRelayClient();

      await expectLater(client.dispose(), completes);
    });
  });
}
