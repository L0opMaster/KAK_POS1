import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';
import '../services/scanner_relay_role.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// phone_scanner_receiver_button.dart` — COPY/ADAPT to Riverpod
/// `ConsumerStatefulWidget` (source already used Riverpod, so this is
/// otherwise near byte-identical). This is the RECEIVING side of the
/// "phone as remote barcode scanner" relay feature: this device generates
/// a session code, a SEPARATE phone (running `MobilePhoneScannerScreen`)
/// connects to it and relays scanned barcodes here, which are fed into
/// the exact same `cartProvider.notifier.addProductByBarcode()` call used
/// by this app's own camera-scanner screen — no duplicate barcode-lookup
/// logic.
///
/// Fully self-contained: owns its own `ScannerRelayClient` and local
/// state. Intended to be dropped into an AppBar's `actions` elsewhere.
class PhoneScannerReceiverButton extends ConsumerStatefulWidget {
  const PhoneScannerReceiverButton({super.key});

  @override
  ConsumerState<PhoneScannerReceiverButton> createState() =>
      _PhoneScannerReceiverButtonState();
}

class _PhoneScannerReceiverButtonState
    extends ConsumerState<PhoneScannerReceiverButton> {
  final ScannerRelayClient _relay = ScannerRelayClient();
  final ValueNotifier<_PhoneScannerStatus> _status =
      ValueNotifier(const _PhoneScannerStatus());

  StreamSubscription<ScannerRelayMessage>? _messageSubscription;
  StreamSubscription<ScannerRelayConnectionState>? _stateSubscription;
  String? _sessionCode;

  @override
  void initState() {
    super.initState();
    _messageSubscription = _relay.messages.listen(_handleRelayMessage);
    _stateSubscription = _relay.connectionStates.listen((state) {
      final _PhoneScannerStatus current = _status.value;
      _status.value = current.copyWith(
        relayConnected: state == ScannerRelayConnectionState.connected,
        error: state == ScannerRelayConnectionState.disconnected &&
                _sessionCode != null
            ? current.error
            : null,
      );
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    unawaited(_stateSubscription?.cancel());
    unawaited(_relay.dispose());
    _status.dispose();
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_sessionCode != null &&
        _relay.state == ScannerRelayConnectionState.connected) {
      return;
    }

    final String sessionCode = _generateSessionCode();
    _sessionCode = sessionCode;
    final l10n = context.l10n;
    _status.value = _PhoneScannerStatus(
      message: l10n.phoneScannerConnecting,
    );

    try {
      await _relay.connect(
        serverBaseUrl: AppConfig.apiBaseUrl,
        sessionCode: sessionCode,
        role: ScannerRelayRole.pos,
      );
      _status.value = _PhoneScannerStatus(
        relayConnected: true,
        message: l10n.phoneScannerWaiting,
      );
    } catch (_) {
      _status.value = _PhoneScannerStatus(
        error: l10n.phoneScannerStartFailed,
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _stopSession({String? message}) async {
    _sessionCode = null;

    _status.value = _PhoneScannerStatus(
      message: message ?? context.l10n.phoneScannerStopped,
    );

    if (mounted) {
      setState(() {});
    }

    await _relay.disconnect();
  }

  Future<void> _openSessionDialog() async {
    await _startSession();
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.phone_android,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              Text(dialogContext.l10n.phoneScannerDialogTitle),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: ValueListenableBuilder<_PhoneScannerStatus>(
              valueListenable: _status,
              builder: (context, status, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(context.l10n.phoneScannerInstructions),
                    const SizedBox(height: 16),
                    SelectableText(
                      _sessionCode ?? context.l10n.phoneScannerUnavailable,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _sessionCode == null
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: _sessionCode!),
                              );
                            },
                      icon: const Icon(Icons.copy),
                      label: Text(context.l10n.phoneScannerCopyCode),
                    ),
                    const SizedBox(height: 12),
                    _StatusLine(status: status),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.phoneScannerExampleUrl,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();

                unawaited(
                  _stopSession(
                    message: dialogContext.l10n.phoneScannerStopped,
                  ),
                );
              },
              child: Text(dialogContext.l10n.phoneScannerStopSession),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.phoneScannerKeepRunning),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleRelayMessage(
    ScannerRelayMessage message,
  ) async {
    if (!mounted) {
      return;
    }

    switch (message.type) {
      case 'ready':
        _status.value = _PhoneScannerStatus(
          relayConnected: true,
          message: context.l10n.phoneScannerWaiting,
        );
        break;
      case 'scanner_connected':
        _status.value = _PhoneScannerStatus(
          relayConnected: true,
          phoneConnected: true,
          message: context.l10n.phoneScannerPhoneReady,
        );
        break;
      case 'scanner_disconnected':
        unawaited(
          _stopSession(
            message: context.l10n.phoneScannerPhoneDisconnected,
          ),
        );
        return;
      case 'barcode':
        final String barcode = message.value?.trim() ?? '';
        if (barcode.isEmpty) {
          return;
        }

        final BarcodeAddResult result =
            await ref.read(cartProvider.notifier).addProductByBarcode(barcode);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(result.message),
            backgroundColor: result.added ? Colors.green : Colors.red,
            duration: const Duration(milliseconds: 1200),
          ));

        _status.value = _status.value.copyWith(
          phoneConnected: true,
          message: result.message,
        );
        break;
      case 'error':
        _status.value = _status.value.copyWith(
          error: message.message ?? context.l10n.phoneScannerRelayError,
        );
        break;
    }

    if (mounted) {
      setState(() {});
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
  Widget build(BuildContext context) {
    final bool phoneConnected = _status.value.phoneConnected;

    return IconButton(
      key: const Key('phone_scanner_button'),
      tooltip: phoneConnected
          ? context.l10n.phoneScannerConnectedTooltip
          : context.l10n.phoneScannerConnectTooltip,
      icon: Icon(
        phoneConnected ? Icons.phonelink_ring : Icons.phonelink_setup,
        color: phoneConnected ? Colors.green : null,
      ),
      onPressed: _openSessionDialog,
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final _PhoneScannerStatus status;

  @override
  Widget build(BuildContext context) {
    final bool ready = status.relayConnected && status.phoneConnected;
    final Color color = status.error != null
        ? Colors.red
        : ready
            ? Colors.green
            : Colors.orange;

    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle : Icons.info_outline,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            status.error ??
                status.message ??
                context.l10n.phoneScannerSessionStoppedStatus,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhoneScannerStatus {
  const _PhoneScannerStatus({
    this.relayConnected = false,
    this.phoneConnected = false,
    this.message,
    this.error,
  });

  final bool relayConnected;
  final bool phoneConnected;
  final String? message;
  final String? error;

  _PhoneScannerStatus copyWith({
    bool? relayConnected,
    bool? phoneConnected,
    String? message,
    String? error,
  }) {
    return _PhoneScannerStatus(
      relayConnected: relayConnected ?? this.relayConnected,
      phoneConnected: phoneConnected ?? this.phoneConnected,
      message: message ?? this.message,
      error: error,
    );
  }
}
