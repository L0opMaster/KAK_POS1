import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/pairing_qr_data.dart';

/// Full-screen QR scanner shared by every pairing flow that can be started
/// by scanning (phone scanner, and — via the same class in the sibling
/// mobile/customer-screen apps — customer display).
///
/// Deliberately a separate [MobileScannerController] from the product
/// barcode scanners (phone_screen_scan.dart, barcode_scanner_screen.dart):
/// those restrict `formats` to 1D product codes and never include
/// [BarcodeFormat.qrCode], so pairing QR codes wouldn't be detected by
/// reusing them as-is.
///
/// Pops with a decoded, type-checked [PairingQrData] on success, or `null`
/// if the user backs out. Wrong-type/unparseable QR codes are handled here
/// (inline banner, camera keeps running) rather than by popping an error —
/// the caller only ever receives `null` or a QR that's actually usable.
class PairingQrScanScreen extends StatefulWidget {
  const PairingQrScanScreen({super.key, required this.expectedType});

  final PairingQrType expectedType;

  @override
  State<PairingQrScanScreen> createState() => _PairingQrScanScreenState();
}

class _PairingQrScanScreenState extends State<PairingQrScanScreen> {
  late final MobileScannerController _cameraController;
  String? _error;
  String? _lastRawValue;
  DateTime? _lastDetectedAt;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 700,
      formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    unawaited(_cameraController.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    String? raw;
    for (final Barcode barcode in capture.barcodes) {
      final String candidate = barcode.rawValue?.trim() ?? '';
      if (candidate.isNotEmpty) {
        raw = candidate;
        break;
      }
    }
    if (raw == null) return;

    final DateTime now = DateTime.now();
    if (_lastRawValue == raw &&
        _lastDetectedAt != null &&
        now.difference(_lastDetectedAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastRawValue = raw;
    _lastDetectedAt = now;

    final PairingQrData? data = PairingQrData.decode(raw);
    if (data == null) {
      setState(() => _error = context.l10n.pairingQrScanInvalid);
      return;
    }
    if (data.type != widget.expectedType) {
      setState(() => _error = _wrongTypeMessage(context, data.type));
      return;
    }

    Navigator.of(context).pop(data);
  }

  String _wrongTypeMessage(BuildContext context, PairingQrType actualType) {
    final String actualLabel = _typeLabel(context, actualType);
    final String expectedLabel = _typeLabel(context, widget.expectedType);
    return context.l10n.pairingQrScanWrongType(actualLabel, expectedLabel);
  }

  String _typeLabel(BuildContext context, PairingQrType type) {
    switch (type) {
      case PairingQrType.phoneScanner:
        return context.l10n.pairingQrTypePhoneScanner;
      case PairingQrType.customerDisplay:
        return context.l10n.pairingQrTypeCustomerDisplay;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.pairingQrScanTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.phoneScanScreenFlashlight,
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _cameraController.toggleTorch,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _cameraController, onDetect: _onDetect),
          IgnorePointer(
            child: Center(
              child: Container(
                width: MediaQuery.sizeOf(context).width * 0.7,
                height: MediaQuery.sizeOf(context).width * 0.7,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _error != null ? Colors.redAccent : Colors.greenAccent,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error ?? context.l10n.pairingQrScanInstructions,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _error != null ? Colors.redAccent : Colors.white,
                    fontWeight: _error != null ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
