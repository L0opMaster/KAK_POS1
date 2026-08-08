import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../models/display_message.dart';
import '../services/customer_display_relay.dart';

enum DisplayView { idle, cart, paymentPending, paymentCompleted }

class DisplayState {
  const DisplayState({
    this.connectionState = CustomerDisplayConnectionState.disconnected,
    this.posConnected = false,
    this.view = DisplayView.idle,
    this.cart,
    this.paymentPending,
    this.splitUpdate,
    this.paymentCompleted,
    this.error,
  });

  final CustomerDisplayConnectionState connectionState;

  /// Whether the relay confirmed a POS is present in this session (distinct
  /// from this device's own socket being open).
  final bool posConnected;

  final DisplayView view;
  final CartSnapshot? cart;
  final PaymentPendingSnapshot? paymentPending;
  final PaymentSplitUpdateSnapshot? splitUpdate;
  final PaymentCompletedSnapshot? paymentCompleted;
  final String? error;

  bool get isConnected =>
      connectionState == CustomerDisplayConnectionState.connected;

  DisplayState copyWith({
    CustomerDisplayConnectionState? connectionState,
    bool? posConnected,
    DisplayView? view,
    CartSnapshot? cart,
    PaymentPendingSnapshot? paymentPending,
    PaymentSplitUpdateSnapshot? splitUpdate,
    bool clearSplitUpdate = false,
    PaymentCompletedSnapshot? paymentCompleted,
    String? error,
    bool clearError = false,
  }) {
    return DisplayState(
      connectionState: connectionState ?? this.connectionState,
      posConnected: posConnected ?? this.posConnected,
      view: view ?? this.view,
      cart: cart ?? this.cart,
      paymentPending: paymentPending ?? this.paymentPending,
      splitUpdate: clearSplitUpdate ? null : splitUpdate ?? this.splitUpdate,
      paymentCompleted: paymentCompleted ?? this.paymentCompleted,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Drives the customer-facing view from messages relayed by the POS app.
///
/// The view always reacts to whatever the POS last broadcast; the only
/// self-timed behavior is reverting from the thank-you screen back to idle
/// a few seconds after a completed payment, so a missed/never-sent `idle`
/// message can't strand the display on the receipt screen forever.
class DisplayNotifier extends StateNotifier<DisplayState> {
  DisplayNotifier() : super(const DisplayState()) {
    _messageSubscription = _relay.messages.listen(_handleMessage);
    _stateSubscription = _relay.connectionStates.listen((connectionState) {
      state = state.copyWith(
        connectionState: connectionState,
        posConnected: connectionState == CustomerDisplayConnectionState.connected
            ? state.posConnected
            : false,
      );
    });
  }

  static const Duration _thankYouDuration = Duration(seconds: 8);

  final CustomerDisplayRelayClient _relay = CustomerDisplayRelayClient();
  StreamSubscription<CustomerDisplayMessage>? _messageSubscription;
  StreamSubscription<CustomerDisplayConnectionState>? _stateSubscription;
  Timer? _revertTimer;

  /// Returns whether the socket ended up connected. Reads the relay's own
  /// synchronous [CustomerDisplayRelayClient.state] rather than this
  /// notifier's `state` field — the latter is only updated once the
  /// `connectionStates` broadcast stream delivers its event, which is not
  /// guaranteed to have happened yet the instant this await returns.
  Future<bool> connect({
    required String serverUrl,
    required String sessionCode,
  }) async {
    state = state.copyWith(clearError: true);
    await AppConfig.saveServerUrl(serverUrl);
    await AppConfig.saveSessionCode(sessionCode);

    await _relay.connect(serverBaseUrl: serverUrl, sessionCode: sessionCode);
    return _relay.state == CustomerDisplayConnectionState.connected;
  }

  Future<void> disconnect() async {
    _revertTimer?.cancel();
    await _relay.disconnect();
    state = const DisplayState();
  }

  void _handleMessage(CustomerDisplayMessage message) {
    switch (message.type) {
      case 'ready':
        state = state.copyWith(clearError: true);
        break;
      case 'display_connected':
        // Sent to the POS, not to us — ignored here.
        break;
      case 'pos_disconnected':
        state = state.copyWith(
          posConnected: false,
          error: 'The register disconnected',
        );
        // The backend only nulls its side of the room and leaves this
        // socket open — drop it ourselves so `connectionState` flips to
        // `disconnected` and DisplayScreen's existing handler routes back
        // to ConnectScreen, instead of sitting frozen on the last view
        // waiting for a POS session that (after a POS-side reload) will
        // come back under a different pairing code.
        unawaited(_relay.disconnect());
        break;
      case 'cart_update':
        _revertTimer?.cancel();
        final CartSnapshot cart = CartSnapshot.fromJson(message.data);
        state = state.copyWith(
          posConnected: true,
          cart: cart,
          view: cart.isEmpty ? DisplayView.idle : DisplayView.cart,
          clearSplitUpdate: true,
          clearError: true,
        );
        break;
      case 'payment_pending':
        _revertTimer?.cancel();
        state = state.copyWith(
          posConnected: true,
          paymentPending: PaymentPendingSnapshot.fromJson(message.data),
          view: DisplayView.paymentPending,
          clearSplitUpdate: true,
          clearError: true,
        );
        break;
      case 'payment_split_update':
        state = state.copyWith(
          posConnected: true,
          splitUpdate: PaymentSplitUpdateSnapshot.fromJson(message.data),
          view: DisplayView.paymentPending,
        );
        break;
      case 'payment_completed':
        state = state.copyWith(
          posConnected: true,
          paymentCompleted: PaymentCompletedSnapshot.fromJson(message.data),
          view: DisplayView.paymentCompleted,
          clearError: true,
        );
        _revertTimer?.cancel();
        _revertTimer = Timer(_thankYouDuration, () {
          state = state.copyWith(view: DisplayView.idle);
        });
        break;
      case 'idle':
        _revertTimer?.cancel();
        state = state.copyWith(posConnected: true, view: DisplayView.idle);
        break;
      case 'error':
        state = state.copyWith(
          error: message.data['message'] as String? ?? 'Display relay error',
        );
        break;
    }
  }

  @override
  void dispose() {
    _revertTimer?.cancel();
    unawaited(_messageSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_relay.dispose());
    super.dispose();
  }
}

final StateNotifierProvider<DisplayNotifier, DisplayState> displayProvider =
    StateNotifierProvider<DisplayNotifier, DisplayState>(
  (ref) => DisplayNotifier(),
);
