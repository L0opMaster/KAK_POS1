import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';

/// ADAPTED from `frontend-flutter-pos/lib/features/pos/screens/
/// phone_screen_scan.dart`. Source's `PhoneScannerScreen` is designed for
/// the DESKTOP app's use case — a desktop has no camera, so a SEPARATE
/// phone (running either that same screen, or the standalone
/// `frontend_flutter_barcode_scanner` companion app) connects over a
/// WebSocket relay (`ScannerRelayClient`, session-code pairing) and sends
/// scanned codes to the desktop's cart.
///
/// `frontend_flutter_mobile` IS the phone — it already has the cart AND a
/// camera in the same process, so none of the relay/session/WebSocket
/// machinery applies here; this is the "source project does something
/// differently" case this task's instructions call out explicitly. What
/// WAS ported directly, byte-identical: the `MobileScannerController`
/// setup (same barcode formats, detection speed/timeout, back camera,
/// autoZoom) and the `_onDetect` de-duplication logic (ignore repeat
/// detections of the same value within 1200ms, haptic feedback on a new
/// detection). What replaces the relay send: a direct call to
/// `cartProvider.notifier.addProductByBarcode()` — the exact same method
/// `[OLD/SOURCE]` `pos_screen.dart`'s manual barcode `TextField` submit
/// handler (`_submitBarcode`) calls, so scanning and manual entry both
/// funnel through identical business logic. A manual-entry fallback field
/// (also ported from `_submitBarcode`'s clear-on-success/select-all-on-
/// failure behavior) sits below the camera for barcodes that won't scan
/// cleanly.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  late final MobileScannerController _cameraController;
  final TextEditingController _manualCtl = TextEditingController();
  final FocusNode _manualFocusNode = FocusNode(debugLabel: 'barcode-input');

  String? _statusMessage;
  String? _lastBarcode;
  String? _lastDetectedValue;
  DateTime? _lastDetectedAt;
  bool _lookupInProgress = false;

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 700,
      autoZoom: true,
      formats: const <BarcodeFormat>[
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  @override
  void dispose() {
    _manualCtl.dispose();
    _manualFocusNode.dispose();
    unawaited(_cameraController.dispose());
    super.dispose();
  }

  /// REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` `PhoneScannerScreen
  /// ._onDetect` — identical dedup/haptic logic. The relay send
  /// (`_relay.sendBarcode(value)`) is replaced with `_lookupBarcode(value)`.
  void _onDetect(BarcodeCapture capture) {
    String? value;
    for (final Barcode barcode in capture.barcodes) {
      final String candidate = barcode.rawValue?.trim() ?? '';
      if (candidate.isNotEmpty) {
        value = candidate;
        break;
      }
    }
    if (value == null) return;

    final DateTime now = DateTime.now();
    if (_lastDetectedValue == value &&
        _lastDetectedAt != null &&
        now.difference(_lastDetectedAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastDetectedValue = value;
    _lastDetectedAt = now;

    HapticFeedback.mediumImpact();
    _lookupBarcode(value);
  }

  /// REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` `pos_screen.dart`'s
  /// `_PosScreenState._submitBarcode()` — same target method
  /// (`cartProvider.notifier.addProductByBarcode`), same success/failure
  /// UI reaction. Shared by both the camera detector and the manual-entry
  /// field below, so scanning and typing behave identically.
  Future<void> _lookupBarcode(String barcode) async {
    if (_lookupInProgress) return;
    setState(() => _lookupInProgress = true);

    final result =
        await ref.read(cartProvider.notifier).addProductByBarcode(barcode);

    if (!mounted) return;
    setState(() {
      _lookupInProgress = false;
      _lastBarcode = barcode;
      _statusMessage = result.message;
    });

    if (result.added) {
      _manualCtl.clear();
    } else {
      _manualCtl.selection =
          TextSelection(baseOffset: 0, extentOffset: _manualCtl.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.barcodeScannerScreenTitle),
        actions: [
          IconButton(
            tooltip: l10n.phoneScanScreenFlashlight,
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: _cameraController.toggleTorch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _cameraController, onDetect: _onDetect),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: MediaQuery.sizeOf(context).width * 0.82,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.greenAccent, width: 3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Card(
                    color: Colors.black87,
                    child: Padding(
                      padding: const EdgeInsets.all(PosTheme.spacingMd),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _statusMessage ?? l10n.phoneScanScreenReadyToScan,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          if (_lastBarcode != null) ...[
                            const SizedBox(height: PosTheme.spacingSm),
                            Text(
                              l10n.phoneScanScreenLastBarcode(_lastBarcode!),
                              style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: TextField(
              controller: _manualCtl,
              focusNode: _manualFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => _lookupBarcode(value.trim()),
              decoration: InputDecoration(
                hintText: l10n.posBarcodeHint,
                prefixIcon: const Icon(Icons.keyboard),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
