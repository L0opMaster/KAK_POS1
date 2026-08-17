import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// customer_display_relay.dart` — COPY/ADAPT NEARLY EXACTLY (byte-identical
/// wire protocol/behavior; only this doc comment differs). Mobile is the
/// `pos` role side of the same `/ws/customer-display` relay the desktop app
/// already talks to, so `frontend_flutter_customer_screen` works unchanged
/// against either POS.

enum CustomerDisplayRole {
  pos,
  display,
}

enum CustomerDisplayConnectionState {
  disconnected,
  connecting,
  connected,
}

class CustomerDisplayMessage {
  const CustomerDisplayMessage({
    required this.type,
    this.data,
  });

  final String type;
  final Map<String, dynamic>? data;

  factory CustomerDisplayMessage.fromJson(Map<String, dynamic> json) {
    return CustomerDisplayMessage(
      type: json['type'] as String? ?? 'unknown',
      data: json,
    );
  }
}

/// WebSocket client for the `/ws/customer-display` relay.
///
/// The POS side pushes arbitrary typed JSON payloads (`sendJson`) describing
/// live cart/checkout state to a paired customer-facing display device.
class CustomerDisplayRelayClient {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final StreamController<CustomerDisplayMessage> _messagesController =
      StreamController<CustomerDisplayMessage>.broadcast();
  final StreamController<CustomerDisplayConnectionState> _stateController =
      StreamController<CustomerDisplayConnectionState>.broadcast();

  CustomerDisplayConnectionState _state =
      CustomerDisplayConnectionState.disconnected;

  Stream<CustomerDisplayMessage> get messages => _messagesController.stream;

  Stream<CustomerDisplayConnectionState> get connectionStates =>
      _stateController.stream;

  CustomerDisplayConnectionState get state => _state;

  Future<void> connect({
    required String serverBaseUrl,
    required String sessionCode,
    required CustomerDisplayRole role,
  }) async {
    await disconnect();
    _setState(CustomerDisplayConnectionState.connecting);

    final Uri uri = buildCustomerDisplayWebSocketUri(
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
          _messagesController.add(CustomerDisplayMessage(
            type: 'error',
            data: <String, dynamic>{'message': error.toString()},
          ));
          _setState(CustomerDisplayConnectionState.disconnected);
        },
        onDone: () {
          _setState(CustomerDisplayConnectionState.disconnected);
        },
        cancelOnError: false,
      );

      await channel.ready.timeout(const Duration(seconds: 10));
      _setState(CustomerDisplayConnectionState.connected);
    } catch (error) {
      _setState(CustomerDisplayConnectionState.disconnected);
      await disconnect();
      rethrow;
    }
  }

  void sendJson(Map<String, dynamic> payload) {
    if (_state != CustomerDisplayConnectionState.connected) {
      return;
    }

    _channel?.sink.add(jsonEncode(payload));
  }

  Future<void> disconnect() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    final WebSocketChannel? channel = _channel;

    _subscription = null;
    _channel = null;

    // Update the interface immediately.
    _setState(CustomerDisplayConnectionState.disconnected);

    if (channel != null) {
      try {
        await channel.sink
            .close(
              ws_status.normalClosure,
              'Customer display session closed',
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
          CustomerDisplayMessage.fromJson(decoded),
        );
      }
    } catch (_) {
      _messagesController.add(const CustomerDisplayMessage(
        type: 'error',
        data: <String, dynamic>{
          'message': 'Invalid response from customer display relay',
        },
      ));
    }
  }

  void _setState(CustomerDisplayConnectionState nextState) {
    if (_state == nextState) {
      return;
    }
    _state = nextState;
    if (!_stateController.isClosed) {
      _stateController.add(nextState);
    }
  }
}

Uri buildCustomerDisplayWebSocketUri({
  required String serverBaseUrl,
  required String sessionCode,
  required CustomerDisplayRole role,
}) {
  final Uri baseUri = Uri.parse(serverBaseUrl.trim());
  if (baseUri.host.isEmpty) {
    throw const FormatException('Enter a valid POS server URL');
  }

  final String webSocketScheme =
      baseUri.scheme.toLowerCase() == 'https' ? 'wss' : 'ws';

  return baseUri.replace(
    scheme: webSocketScheme,
    path: '/ws/customer-display',
    queryParameters: <String, String>{
      'session': sessionCode.trim().toUpperCase(),
      'role': role.name,
    },
  );
}
