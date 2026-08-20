import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/pairing_qr_data.dart';

/// Full-screen QR scanner for pairing this phone to a POS register.
///
/// Deliberately a separate [MobileScannerController] from
/// [PhoneScannerScreen]'s product-barcode scanner: that one restricts
/// `formats` to 1D product codes and never includes [BarcodeFormat.qrCode],
/// so the POS's pairing QR wouldn't be detected by reusing it as-is.
///
/// Pops with a decoded, type-checked [PairingQrData] on success, or `null`
/// if the user backs out. An unparseable or wrong-type QR code (e.g. a
/// Customer Display pairing code) is handled here with an inline banner —
/// the camera keeps running so the user can try again.
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
      setState(() => _error = 'Invalid pairing QR code.');
      return;
    }
    if (data.type != widget.expectedType) {
      setState(() {
        _error =
            'This QR code is for ${_typeLabel(data.type)}, not ${_typeLabel(widget.expectedType)}.';
      });
      return;
    }

    Navigator.of(context).pop(data);
  }

  String _typeLabel(PairingQrType type) {
    switch (type) {
      case PairingQrType.phoneScanner:
        return 'Phone Scanner';
      case PairingQrType.customerDisplay:
        return 'Customer Display';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Pairing QR Code'),
        actions: [
          IconButton(
            tooltip: 'Flashlight',
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
                  _error ?? 'Point the camera at the QR code shown on the POS screen',
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
