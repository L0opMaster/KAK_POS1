import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/features/pos/services/printing/printer_pdf_format.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/printer_profile.dart';

void main() {
  group('PrinterPaperSize', () {
    test('dotWidth: 384 for mm58, 576 for mm80', () {
      expect(PrinterPaperSize.mm58.dotWidth, 384);
      expect(PrinterPaperSize.mm80.dotWidth, 576);
    });

    test('pdfPageFormat differs by paper size, not package:pdf\'s default '
        'roll57/roll80 margins', () {
      final mm58 = PrinterPaperSize.mm58.pdfPageFormat;
      final mm80 = PrinterPaperSize.mm80.pdfPageFormat;
      expect(mm58.width, lessThan(mm80.width));
      expect(mm58.marginLeft, isNot(mm80.marginLeft));
    });
  });

  group('PrinterConfig', () {
    test('defaultConfig is pdfDriver + mm80 — the fresh-install fallback', () {
      expect(
        PrinterConfig.defaultConfig.transportType,
        PrinterTransportType.pdfDriver,
      );
      expect(PrinterConfig.defaultConfig.paperSize, PrinterPaperSize.mm80);
      expect(PrinterConfig.defaultConfig.networkPort, 9100);
    });

    test('toJson/fromJson round-trips every field', () {
      const config = PrinterConfig(
        transportType: PrinterTransportType.network,
        paperSize: PrinterPaperSize.mm58,
        networkHost: '192.168.1.50',
        networkPort: 9100,
      );
      final restored = PrinterConfig.fromJson(config.toJson());
      expect(restored.transportType, PrinterTransportType.network);
      expect(restored.paperSize, PrinterPaperSize.mm58);
      expect(restored.networkHost, '192.168.1.50');
    });

    test('fromJson falls back to pdfDriver/mm80 for unknown or missing '
        'enum values', () {
      final fromEmpty = PrinterConfig.fromJson(const {});
      expect(fromEmpty.transportType, PrinterTransportType.pdfDriver);
      expect(fromEmpty.paperSize, PrinterPaperSize.mm80);

      final fromGarbage = PrinterConfig.fromJson(const {
        'transportType': 'not_a_real_type',
        'paperSize': 'also_fake',
      });
      expect(fromGarbage.transportType, PrinterTransportType.pdfDriver);
      expect(fromGarbage.paperSize, PrinterPaperSize.mm80);
    });

    test('copyWith only overrides the given fields', () {
      const config = PrinterConfig(
        transportType: PrinterTransportType.pdfDriver,
        paperSize: PrinterPaperSize.mm80,
      );
      final updated = config.copyWith(paperSize: PrinterPaperSize.mm58);
      expect(updated.paperSize, PrinterPaperSize.mm58);
      expect(updated.transportType, PrinterTransportType.pdfDriver);
    });
  });
}
