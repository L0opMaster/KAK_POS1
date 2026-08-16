import 'dart:io';

import 'printer_transport.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// network_printer_transport.dart` — COPY/ADAPT NEARLY EXACTLY, full file.
/// Zero platform changes needed — this transport actually works BETTER on
/// mobile than on web (web's `Socket` throws `UnsupportedError` at
/// runtime; Android/iOS both support `dart:io Socket` natively).
///
/// Sends raw ESC/POS bytes over a plain TCP socket to a network printer's
/// raw-print port (9100 is the universal default for thermal/receipt
/// printers with an Ethernet/Wi-Fi interface — no driver needed).
class NetworkPrinterTransport implements PrinterTransport {
  NetworkPrinterTransport(this.host, {this.port = 9100});

  final String host;
  final int port;

  Socket? _socket;

  @override
  bool get isConnected => _socket != null;

  @override
  Future<void> connect() async {
    _socket = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 5),
    );
  }

  @override
  Future<void> write(List<int> bytes) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Network printer is not connected');
    }
    socket.add(bytes);
    await socket.flush();
  }

  @override
  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}
