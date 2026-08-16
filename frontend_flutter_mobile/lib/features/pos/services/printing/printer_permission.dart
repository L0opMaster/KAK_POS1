import 'package:permission_handler/permission_handler.dart';

import 'printer_profile.dart';

/// Genuinely new in this port — there is no `[OLD/SOURCE]` equivalent to
/// adapt. Confirmed by grep of `frontend-flutter-pos/lib/`:
/// `permission_handler` is a declared dependency there but imported
/// nowhere — neither `BluetoothPrinterTransport`/`UsbPrinterTransport` nor
/// any settings screen requests a runtime permission before calling
/// `connect()`. This app requests one before ever attempting a Bluetooth
/// connection.
///
/// Android 12+ (API 31+) gates classic Bluetooth connect/discovery behind
/// the runtime `BLUETOOTH_CONNECT`/`BLUETOOTH_SCAN` permissions
/// (`android/app/src/main/AndroidManifest.xml`); iOS gates it behind
/// `NSBluetoothAlwaysUsageDescription` (`ios/Runner/Info.plist`), which the
/// OS prompts for automatically the first time a Bluetooth API is touched
/// — `permission_handler`'s `Permission.bluetoothConnect` maps to the
/// right platform check on either OS.
///
/// USB has no comparable *app-level* runtime permission on Android — the
/// OS shows its own one-time "Allow this app to access the USB device?"
/// dialog the first time `PrinterManager.instance.connect` actually opens
/// the device, driven by the platform plugin itself, not by
/// `permission_handler`. There is nothing for this function to request
/// ahead of time for USB, so it's a pass-through returning `true`.
Future<bool> ensurePrinterPermission(PrinterTransportType type) async {
  if (type == PrinterTransportType.bluetooth) {
    final status = await Permission.bluetoothConnect.request();
    return status.isGranted;
  }
  return true;
}
