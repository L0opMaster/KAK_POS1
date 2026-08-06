import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

/// Physical paper widths this app knows how to print at. Maps to the raster
/// dot-width thermal printers expect (384 dots @ 8 dots/mm for 58mm stock,
/// 576 dots for 80mm) and to `esc_pos_utils_plus`'s [PaperSize].
enum PrinterPaperSize {
  mm58,
  mm80;

  int get dotWidth => this == PrinterPaperSize.mm58 ? 384 : 576;

  PaperSize get escPosPaperSize =>
      this == PrinterPaperSize.mm58 ? PaperSize.mm58 : PaperSize.mm80;
}

/// How the app reaches the physical printer. [pdfDriver] hands a PDF to the
/// OS print dialog (works for anything with an installed driver — large
/// format printers, network printers already registered with the OS). The
/// other three send raw ESC/POS bytes directly over the named transport,
/// for thermal printers with no OS driver at all.
enum PrinterTransportType {
  pdfDriver,
  bluetooth,
  usb,
  network,
}

/// A saved printer configuration, persisted in Settings.
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
  }) =>
      PrinterConfig(
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
