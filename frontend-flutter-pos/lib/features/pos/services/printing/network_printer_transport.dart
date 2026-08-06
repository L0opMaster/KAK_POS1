import 'dart:io';

import 'printer_transport.dart';

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
    _socket = await Socket.connect(host, port,
        timeout: const Duration(seconds: 5));
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
