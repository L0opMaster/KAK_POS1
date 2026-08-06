import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

enum CustomerDisplayConnectionState {
  disconnected,
  connecting,
  connected,
}

class CustomerDisplayMessage {
  const CustomerDisplayMessage({
    required this.type,
    required this.data,
  });

  final String type;

  /// The full decoded JSON payload (including `type`), so callers can pull
  /// out whatever fields a given message type carries.
  final Map<String, dynamic> data;

  factory CustomerDisplayMessage.fromJson(Map<String, dynamic> json) {
    return CustomerDisplayMessage(
      type: json['type'] as String? ?? 'unknown',
      data: json,
    );
  }
}

/// WebSocket client for the `/ws/customer-display` relay, role `display`.
///
/// This device never sends anything but a connection request — it just
/// listens for whatever JSON the POS broadcasts. Structurally mirrors the
/// POS app's `CustomerDisplayRelayClient` (frontend-flutter-pos) so both
/// ends speak the exact same relay protocol.
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
  }) async {
    await disconnect();
    _setState(CustomerDisplayConnectionState.connecting);

    final Uri uri = buildCustomerDisplayWebSocketUri(
      serverBaseUrl: serverBaseUrl,
      sessionCode: sessionCode,
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

  Future<void> disconnect() async {
    final StreamSubscription<dynamic>? subscription = _subscription;
    final WebSocketChannel? channel = _channel;

    _subscription = null;
    _channel = null;

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
          'message': 'Invalid message from customer display relay',
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
      'role': 'display',
    },
  );
}
