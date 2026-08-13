import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

enum ScannerRelayRole {
  pos,
  scanner,
}

enum ScannerRelayConnectionState {
  disconnected,
  connecting,
  connected,
}

class ScannerRelayMessage {
  const ScannerRelayMessage({
    required this.type,
    this.value,
    this.message,
  });

  final String type;
  final String? value;
  final String? message;

  factory ScannerRelayMessage.fromJson(Map<String, dynamic> json) {
    return ScannerRelayMessage(
      type: json['type'] as String? ?? 'unknown',
      value: json['value'] as String?,
      message: json['message'] as String?,
    );
  }
}

class ScannerRelayClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final StreamController<ScannerRelayMessage> _messagesController =
      StreamController<ScannerRelayMessage>.broadcast();
  final StreamController<ScannerRelayConnectionState> _stateController =
      StreamController<ScannerRelayConnectionState>.broadcast();

  ScannerRelayConnectionState _state = ScannerRelayConnectionState.disconnected;

  Stream<ScannerRelayMessage> get messages => _messagesController.stream;

  Stream<ScannerRelayConnectionState> get connectionStates =>
      _stateController.stream;

  ScannerRelayConnectionState get state => _state;

  Future<void> connect({
    required String serverBaseUrl,
    required String sessionCode,
    required ScannerRelayRole role,
  }) async {
    await disconnect();
    _setState(ScannerRelayConnectionState.connecting);

    final Uri uri = buildScannerWebSocketUri(
      serverBaseUrl: serverBaseUrl,
      sessionCode: sessionCode,
      role: role,
    );

    try {
      final WebSocketChannel channel = WebSocketChannel.connect(uri);
      _channel = channel;

      _subscription = channel.stream.listen(
        _handleMessage,
        onError: (Object error, StackTrace stackTrace) {
          _messagesController.add(ScannerRelayMessage(
            type: 'error',
            message: error.toString(),
          ));
          _setState(ScannerRelayConnectionState.disconnected);
        },
        onDone: () {
          _setState(ScannerRelayConnectionState.disconnected);
        },
        cancelOnError: false,
      );

      await channel.ready.timeout(const Duration(seconds: 10));
      _setState(ScannerRelayConnectionState.connected);
    } catch (error) {
      _setState(ScannerRelayConnectionState.disconnected);
      await disconnect();
      rethrow;
    }
  }

  void sendBarcode(String value) {
    final String normalized = value.trim();
    if (_state != ScannerRelayConnectionState.connected || normalized.isEmpty) {
      return;
    }

    _channel?.sink.add(jsonEncode(<String, dynamic>{
      'type': 'barcode',
      'value': normalized,
    }));
  }

  Future<void> disconnect() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    final WebSocketChannel? channel = _channel;

    _subscription = null;
    _channel = null;

    // Update the interface immediately.
    _setState(ScannerRelayConnectionState.disconnected);

    if (channel != null) {
      try {
        await channel.sink
            .close(
              ws_status.normalClosure,
              'Scanner session closed',
            )
            .timeout(const Duration(seconds: 2));
      } catch (error) {
        debugPrint('WebSocket close warning: $error');
      }
    }

    if (subscription != null) {
      try {
        await subscription.cancel().timeout(const Duration(seconds: 2));
      } catch (error) {
        debugPrint('WebSocket subscription warning: $error');
      }
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
    await _stateController.close();
  }

  void _handleMessage(dynamic rawMessage) {
    if (rawMessage is! String) {
      return;
    }

    try {
      final Object? decoded = jsonDecode(rawMessage);
      if (decoded is Map<String, dynamic>) {
        _messagesController.add(
          ScannerRelayMessage.fromJson(decoded),
        );
      }
    } catch (_) {
      _messagesController.add(const ScannerRelayMessage(
        type: 'error',
        message: 'Invalid response from scanner relay',
      ));
    }
  }

  void _setState(ScannerRelayConnectionState nextState) {
    if (_state == nextState) {
      return;
    }
    _state = nextState;
    if (!_stateController.isClosed) {
      _stateController.add(nextState);
    }
  }
}

Uri buildScannerWebSocketUri({
  required String serverBaseUrl,
  required String sessionCode,
  required ScannerRelayRole role,
}) {
  final Uri baseUri = Uri.parse(serverBaseUrl.trim());
  if (baseUri.host.isEmpty) {
    throw const FormatException('Enter a valid POS server URL');
  }

  final String webSocketScheme =
      baseUri.scheme.toLowerCase() == 'https' ? 'wss' : 'ws';

  return baseUri.replace(
    scheme: webSocketScheme,
    path: '/ws/scanner',
    queryParameters: <String, String>{
      'session': sessionCode.trim().toUpperCase(),
      'role': role.name,
    },
  );
}
