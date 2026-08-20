import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/lan_address.dart';
import '../../../core/utils/pairing_qr_data.dart';
import '../providers/customer_display_provider.dart';
import '../services/customer_display_relay.dart';
import 'pairing_qr_section.dart';

/// App-bar icon that starts/stops a customer-display pairing session and
/// shows the session code the customer-screen device should be connected
/// with (`connect_screen.dart` on that app).
class CustomerDisplayStatusButton extends ConsumerWidget {
  const CustomerDisplayStatusButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CustomerDisplayStatus status = ref.watch(customerDisplayProvider);

    return IconButton(
      key: const Key('customer_display_button'),
      tooltip: status.displayConnected
          ? context.l10n.customerDisplayTooltipConnected
          : context.l10n.customerDisplayTooltipConnect,
      icon: Icon(status.displayConnected ? Icons.tv : Icons.tv_off_outlined,
          color: status.displayConnected ? Colors.white : Colors.white),
      onPressed: () => _openSessionDialog(context, ref),
    );
  }

  Future<void> _openSessionDialog(BuildContext context, WidgetRef ref) async {
    final CustomerDisplayNotifier notifier =
        ref.read(customerDisplayProvider.notifier);

    if (ref.read(customerDisplayProvider).sessionCode == null) {
      await notifier.startSession();
    }

    if (!context.mounted) {
      return;
    }

    // Scoped to this dialog's lifetime rather than a State field, since
    // this widget is a stateless ConsumerWidget — mirrors the live-update
    // pattern PhoneScannerReceiverButton uses via an instance field, just
    // local here because there's no longer-lived State to own it.
    final ValueNotifier<String?> lanServerUrl = ValueNotifier<String?>(null);
    unawaited(
      resolvePairingServerUrl(AppConfig.apiBaseUrl)
          .then((String? url) => lanServerUrl.value = url),
    );

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.tv,
                color: Colors.green,
              ),
              const SizedBox(width: 10),
              Text(context.l10n.customerDisplayDialogTitle),
            ],
          ),
          // QR section can push content past the screen height on shorter
          // Android phones. AlertDialog's own `scrollable: true` also
          // wraps content in an IntrinsicWidth alongside the actions row,
          // which crashes ("LayoutBuilder does not support returning
          // intrinsic dimensions") because QrImageView uses a LayoutBuilder
          // internally — so the content scrolls itself here instead.
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Consumer(
                builder: (context, ref, _) {
                  final CustomerDisplayStatus status =
                      ref.watch(customerDisplayProvider);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(context.l10n.customerDisplayDialogInstructions),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<String?>(
                        valueListenable: lanServerUrl,
                        builder: (context, lanUrl, _) {
                          return PairingQrSection(
                            scanLabel: context.l10n.customerDisplayScanQrLabel,
                            orManualLabel:
                                context.l10n.customerDisplayOrManualLabel,
                            serverLabel: lanUrl == null
                                ? null
                                : context.l10n
                                    .customerDisplayServerLabel(lanUrl),
                            unavailableMessage:
                                context.l10n.customerDisplayQrUnavailable,
                            qrData:
                                (lanUrl == null || status.sessionCode == null)
                                    ? null
                                    : PairingQrData(
                                        type: PairingQrType.customerDisplay,
                                        server: lanUrl,
                                        sessionCode: status.sessionCode!,
                                      ).encode(),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        status.sessionCode ?? '--------',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: status.sessionCode == null
                            ? null
                            : () {
                                Clipboard.setData(
                                  ClipboardData(text: status.sessionCode!),
                                );
                              },
                        icon: const Icon(Icons.copy),
                        label: Text(context.l10n.customerDisplayCopyCode),
                      ),
                      const SizedBox(height: 12),
                      _StatusLine(status: status),
                    ],
                  );
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                notifier.stopSession();
              },
              child: Text(context.l10n.customerDisplayStopSession),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.customerDisplayKeepRunning),
            ),
          ],
        );
      },
    );
    lanServerUrl.dispose();
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final CustomerDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final bool ready = status.isActive && status.displayConnected;
    final Color color = status.error != null
        ? Colors.red
        : ready
            ? Colors.green
            : Colors.orange;

    String message;
    if (status.error != null) {
      message = status.error!;
    } else if (status.connectionState ==
        CustomerDisplayConnectionState.connecting) {
      message = context.l10n.customerDisplayStatusStarting;
    } else if (!status.isActive) {
      message = context.l10n.customerDisplayStatusStopped;
    } else if (status.displayConnected) {
      message = context.l10n.customerDisplayStatusConnected;
    } else {
      message = context.l10n.customerDisplayStatusWaiting;
    }

    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle : Icons.info_outline,
          color: color,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
