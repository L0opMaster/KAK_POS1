/// A physical connection to a thermal printer capable of accepting raw
/// ESC/POS bytes. Implementations: [BluetoothPrinterTransport],
/// [UsbPrinterTransport], [NetworkPrinterTransport].
abstract class PrinterTransport {
  Future<void> connect();
  Future<void> write(List<int> bytes);
  Future<void> disconnect();

  /// Whether [connect] has succeeded and [disconnect] hasn't been called.
  bool get isConnected;
}
