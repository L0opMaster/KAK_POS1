import 'package:flutter_pos_printer_platform_image_3/flutter_pos_printer_platform_image_3.dart';

import 'printer_transport.dart';

/// Sends raw ESC/POS bytes over USB — used for desk-mounted / larger
/// receipt printers wired directly to the till (Android and Windows).
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
    final ok = await PrinterManager.instance
        .send(type: PrinterType.usb, bytes: bytes);
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
