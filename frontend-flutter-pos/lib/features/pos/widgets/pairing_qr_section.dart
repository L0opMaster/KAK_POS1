import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// "Scan this QR code / Or enter manually" block shared by
/// [PhoneScannerReceiverButton] and [CustomerDisplayStatusButton]'s pairing
/// dialogs. Purely presentational — callers own session-code generation,
/// LAN-address lookup, and the actual manual-entry fields (session code,
/// copy button) below this section; this only renders the QR itself plus
/// the "Server: ..." line, or a fallback message when no LAN-reachable
/// address could be found yet.
class PairingQrSection extends StatelessWidget {
  const PairingQrSection({
    super.key,
    required this.scanLabel,
    required this.orManualLabel,
    required this.serverLabel,
    required this.unavailableMessage,
    required this.qrData,
  });

  /// e.g. "Scan this QR code".
  final String scanLabel;

  /// e.g. "Or enter manually".
  final String orManualLabel;

  /// Pre-formatted "Server: http://192.168.1.10:8081" line, or `null` while
  /// no LAN address has been resolved yet.
  final String? serverLabel;

  /// Shown instead of the QR image when [qrData] is `null` — i.e. no
  /// LAN-reachable address was found, so embedding one would just produce a
  /// QR code no other device could actually use (see lan_address.dart).
  final String unavailableMessage;

  /// Encoded `PairingQrData` JSON, or `null` when not ready yet.
  final String? qrData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          scanLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Center(
          child: qrData == null
              ? Container(
                  width: 180,
                  height: 180,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unavailableMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: QrImageView(
                    data: qrData!,
                    size: 180,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                orManualLabel,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        if (serverLabel != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            serverLabel!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }
}
