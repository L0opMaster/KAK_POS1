import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_transport.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// bluetooth_printer_transport.dart` — COPY/ADAPT NEARLY EXACTLY, full
/// file. The code itself is portable and correct as-is; what's new in this
/// port (Day 16) is a caller gating `connect()` behind
/// `ensurePrinterPermission` (see `printer_permission.dart`), since
/// neither project had an existing pattern for that to copy.
///
/// Sends raw ESC/POS bytes over a paired Bluetooth (classic) connection —
/// the common transport for handheld/mini and 58mm/80mm thermal printers.
class BluetoothPrinterTransport implements PrinterTransport {
  BluetoothPrinterTransport(this.macAddress);

  final String macAddress;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect() async {
    _connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );
    if (!_connected) {
      throw StateError('Could not connect to Bluetooth printer $macAddress');
    }
  }

  @override
  Future<void> write(List<int> bytes) async {
    if (!_connected) {
      throw StateError('Bluetooth printer is not connected');
    }
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    if (!ok) {
      throw StateError('Failed to write to Bluetooth printer');
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    await PrintBluetoothThermal.disconnect;
    _connected = false;
  }

  /// Paired devices the user can pick from in Settings.
  static Future<List<BluetoothInfo>> pairedDevices() =>
      PrintBluetoothThermal.pairedBluetooths;
}
