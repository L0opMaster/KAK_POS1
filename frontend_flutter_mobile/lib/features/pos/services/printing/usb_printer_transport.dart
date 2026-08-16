import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

import 'printer_transport.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// usb_printer_transport.dart` — COPY/ADAPT NEARLY EXACTLY, full file.
/// iOS USB support is genuinely uncertain (MFi certification may block
/// it) — a real open question, not assumed either way; this transport is
/// primarily an Android path.
///
/// CONFIRMED BROKEN on Android 13+ (API 33+) with the pinned plugin
/// version (`flutter_pos_printer_platform_image_3: ^1.2.4`, resolves to
/// the newest available `1.2.4` — no fix released) — found via real
/// on-device testing (Day 20), not simulated. The plugin's own
/// `USBPrinterService.kt` (`init()`, called from
/// `FlutterPosPrinterPlatformPlugin.onAttachedToActivity`) calls
/// `Context.registerReceiver()` without the `RECEIVER_EXPORTED`/
/// `RECEIVER_NOT_EXPORTED` flag Android 13+ requires, throwing a
/// `SecurityException` INSIDE THE PLUGIN'S OWN registration — Flutter's
/// `GeneratedPluginRegistrant` catches it per-plugin and logs
/// "Error registering plugin flutter_pos_printer_platform_image_3"
/// rather than crashing the app, but the practical effect is the same:
/// this plugin's platform channel never registers, so every method call
/// this class makes (`connect`/`send`/`disconnect`/`discovery`) will fail
/// at runtime on any Android 13+ device. Not fixable from this repo — the
/// bug is in the plugin's native Kotlin, not in this file or anything
/// else under `mobile-flutter-pos`. `frontend-flutter-pos` pins the
/// identical plugin version, so this isn't a regression introduced by
/// the mobile port — it would reproduce there too, on Android. A real
/// fix needs either an upstream plugin release or forking/patching the
/// plugin's Android source, both bigger decisions than this port's scope.
///
/// Sends raw ESC/POS bytes over USB — used for desk-mounted / larger
/// receipt printers wired directly to the till.
class UsbPrinterTransport implements PrinterTransport {
  UsbPrinterTransport({this.vendorId, this.productId, this.name});

  final String? vendorId;
  final String? productId;
  final String? name;

  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = await PrinterManager.instance.connect(
      type: PrinterType.usb,
      model: UsbPrinterInput(
        name: name,
        vendorId: vendorId,
        productId: productId,
      ),
    );
    if (!_connected) {
      throw StateError('Could not connect to USB printer');
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!_connected) {
      throw StateError('USB printer is not connected');
    }
    final ok = await PrinterManager.instance.send(
      type: PrinterType.usb,
      bytes: bytes,
    );
    if (!ok) {
      throw StateError('Failed to write to USB printer');
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    await PrinterManager.instance.disconnect(type: PrinterType.usb);
    _connected = false;
  }

  /// Discovers connected USB printers (Android / Windows only).
  static Stream<PrinterDevice> discover() =>
      PrinterManager.instance.discovery(type: PrinterType.usb);
}
