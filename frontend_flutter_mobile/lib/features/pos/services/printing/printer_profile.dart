/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// printer_profile.dart` — PARTIAL PORT. `PrinterPaperSize.escPosPaperSize`
/// (maps to `esc_pos_utils_plus`'s `PaperSize`) is dropped — it's needed
/// only by the raw ESC/POS thermal transport path (Day 15/16), which
/// doesn't exist in this port yet, and adding the `esc_pos_utils_plus`
/// package now just for an unused getter isn't worth the dependency.
/// `dotWidth` is kept even though nothing calls it until Day 14's bitmap
/// rasterizer exists — it's a zero-cost `int` getter describing the same
/// physical paper property `mm58`/`mm80` already name, not a new
/// dependency. Everything else (`PrinterTransportType`, `PrinterConfig`)
/// is COPY/ADAPT NEARLY EXACTLY, full shape — a settings model is more
/// useful ported whole than split across days, same reasoning as
/// `sale_service.dart` (Day 11).
enum PrinterPaperSize {
  mm58,
  mm80;

  int get dotWidth => this == PrinterPaperSize.mm58 ? 384 : 576;
}

/// How the app reaches the physical printer. [pdfDriver] hands a PDF to the
/// OS print dialog/share sheet — the only transport this port implements
/// so far (Day 13). The other three (raw ESC/POS over a named transport)
/// are Day 15/16 scope.
enum PrinterTransportType { pdfDriver, bluetooth, usb, network }

/// A saved printer configuration, persisted in Settings (Day 19 — not
/// built yet; `ThermalPrinterService.loadConfig()` falls back to
/// [defaultConfig] until then).
class PrinterConfig {
  const PrinterConfig({
    required this.transportType,
    required this.paperSize,
    this.bluetoothAddress,
    this.usbVendorId,
    this.usbProductId,
    this.networkHost,
    this.networkPort = 9100,
  });

  final PrinterTransportType transportType;
  final PrinterPaperSize paperSize;
  final String? bluetoothAddress;
  final int? usbVendorId;
  final int? usbProductId;
  final String? networkHost;
  final int networkPort;

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
    transportType: PrinterTransportType.values.firstWhere(
      (t) => t.name == json['transportType'],
      orElse: () => PrinterTransportType.pdfDriver,
    ),
    paperSize: PrinterPaperSize.values.firstWhere(
      (p) => p.name == json['paperSize'],
      orElse: () => PrinterPaperSize.mm80,
    ),
    bluetoothAddress: json['bluetoothAddress'] as String?,
    usbVendorId: (json['usbVendorId'] as num?)?.toInt(),
    usbProductId: (json['usbProductId'] as num?)?.toInt(),
    networkHost: json['networkHost'] as String?,
    networkPort: (json['networkPort'] as num?)?.toInt() ?? 9100,
  );

  Map<String, dynamic> toJson() => {
    'transportType': transportType.name,
    'paperSize': paperSize.name,
    if (bluetoothAddress != null) 'bluetoothAddress': bluetoothAddress,
    if (usbVendorId != null) 'usbVendorId': usbVendorId,
    if (usbProductId != null) 'usbProductId': usbProductId,
    if (networkHost != null) 'networkHost': networkHost,
    'networkPort': networkPort,
  };

  PrinterConfig copyWith({
    PrinterTransportType? transportType,
    PrinterPaperSize? paperSize,
    String? bluetoothAddress,
    int? usbVendorId,
    int? usbProductId,
    String? networkHost,
    int? networkPort,
  }) => PrinterConfig(
    transportType: transportType ?? this.transportType,
    paperSize: paperSize ?? this.paperSize,
    bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
    usbVendorId: usbVendorId ?? this.usbVendorId,
    usbProductId: usbProductId ?? this.usbProductId,
    networkHost: networkHost ?? this.networkHost,
    networkPort: networkPort ?? this.networkPort,
  );

  static const defaultConfig = PrinterConfig(
    transportType: PrinterTransportType.pdfDriver,
    paperSize: PrinterPaperSize.mm80,
  );
}
