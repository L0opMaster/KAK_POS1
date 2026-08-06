import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart' show CartState;
import '../services/customer_display_relay.dart';

/// Snapshot of the customer-display pairing/connection status, consumed by
/// the pairing dialog (customer_display_status_button.dart).
class CustomerDisplayStatus {
  const CustomerDisplayStatus({
    this.sessionCode,
    this.connectionState = CustomerDisplayConnectionState.disconnected,
    this.displayConnected = false,
    this.error,
  });

  final String? sessionCode;
  final CustomerDisplayConnectionState connectionState;
  final bool displayConnected;
  final String? error;

  bool get isActive =>
      connectionState == CustomerDisplayConnectionState.connected;

  CustomerDisplayStatus copyWith({
    String? sessionCode,
    bool clearSessionCode = false,
    CustomerDisplayConnectionState? connectionState,
    bool? displayConnected,
    String? error,
    bool clearError = false,
  }) {
    return CustomerDisplayStatus(
      sessionCode: clearSessionCode ? null : sessionCode ?? this.sessionCode,
      connectionState: connectionState ?? this.connectionState,
      displayConnected: displayConnected ?? this.displayConnected,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Owns the POS-side relay connection to `/ws/customer-display` and turns
/// cart/checkout events into JSON envelopes for the paired display device.
///
/// Every `broadcast*` method is best-effort: if no display is paired, the
/// message is simply dropped (same spirit as CartNotifier's `_syncService`).
class CustomerDisplayNotifier extends StateNotifier<CustomerDisplayStatus> {
  CustomerDisplayNotifier() : super(const CustomerDisplayStatus()) {
    _messageSubscription = _relay.messages.listen(_handleMessage);
    _stateSubscription = _relay.connectionStates.listen((connectionState) {
      state = state.copyWith(connectionState: connectionState);
    });
  }

  final CustomerDisplayRelayClient _relay = CustomerDisplayRelayClient();
  StreamSubscription<CustomerDisplayMessage>? _messageSubscription;
  StreamSubscription<CustomerDisplayConnectionState>? _stateSubscription;

  Future<void> startSession() async {
    final String sessionCode = _generateSessionCode();
    state = CustomerDisplayStatus(sessionCode: sessionCode);

    try {
      await _relay.connect(
        serverBaseUrl: AppConfig.apiBaseUrl,
        sessionCode: sessionCode,
        role: CustomerDisplayRole.pos,
      );
    } catch (_) {
      state = state.copyWith(error: 'Could not start the display session');
    }
  }

  Future<void> stopSession() async {
    await _relay.disconnect();
    state = const CustomerDisplayStatus();
  }

  void broadcastCartState(
    CartState cart, {
    required String currencySymbol,
  }) {
    _send(<String, dynamic>{
      'type': 'cart_update',
      'orderMode': cart.orderMode.name,
      if (cart.tableId != null) 'tableId': cart.tableId,
      'items': cart.items
          .map((CartItem item) => <String, dynamic>{
                'nameEn': item.product.nameEn,
                'nameKm': item.product.nameKm,
                'qty': item.qty,
                'unitPrice': item.unitPrice,
                'lineTotal': item.lineTotal,
                if (item.modifierSummaryText.isNotEmpty)
                  'modifiers': item.modifierSummaryText,
              })
          .toList(),
      'subtotal': cart.total,
      'taxAmount': cart.taxAmount,
      'discountAmount': cart.discountAmount,
      'total': cart.finalTotal,
      'currencySymbol': currencySymbol,
    });
  }

  void broadcastPaymentPending(
    double amountDue, {
    required String currencySymbol,
  }) {
    _send(<String, dynamic>{
      'type': 'payment_pending',
      'amountDue': amountDue,
      'currencySymbol': currencySymbol,
    });
  }

  void broadcastPaymentSplitUpdate({
    required List<Map<String, dynamic>> splits,
    required double remaining,
    required String currencySymbol,
  }) {
    _send(<String, dynamic>{
      'type': 'payment_split_update',
      'splits': splits,
      'remaining': remaining,
      'currencySymbol': currencySymbol,
    });
  }

  void broadcastPaymentCompleted({
    required String receiptNumber,
    required double total,
    required double amountPaid,
    required double change,
    required String currencySymbol,
  }) {
    _send(<String, dynamic>{
      'type': 'payment_completed',
      'receiptNumber': receiptNumber,
      'total': total,
      'amountPaid': amountPaid,
      'change': change,
      'currencySymbol': currencySymbol,
    });
  }

  void broadcastIdle() {
    _send(const <String, dynamic>{'type': 'idle'});
  }

  void _send(Map<String, dynamic> payload) {
    if (!state.isActive) {
      return;
    }
    _relay.sendJson(payload);
  }

  void _handleMessage(CustomerDisplayMessage message) {
    switch (message.type) {
      case 'ready':
        state = state.copyWith(clearError: true);
        break;
      case 'display_connected':
        state = state.copyWith(displayConnected: true, clearError: true);
        break;
      case 'display_disconnected':
        state = state.copyWith(displayConnected: false);
        break;
      case 'error':
        state = state.copyWith(
          error: message.data?['message'] as String? ?? 'Display relay error',
        );
        break;
    }
  }

  String _generateSessionCode() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random.secure();
    return List<String>.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_relay.dispose());
    super.dispose();
  }
}

final StateNotifierProvider<CustomerDisplayNotifier, CustomerDisplayStatus>
    customerDisplayProvider =
    StateNotifierProvider<CustomerDisplayNotifier, CustomerDisplayStatus>(
  (ref) => CustomerDisplayNotifier(),
);
