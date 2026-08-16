import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend_flutter_mobile/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/thermal_printer_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThermalPrinterService.loadConfig', () {
    test('a fresh install (nothing saved yet) returns PrinterConfig.'
        'defaultConfig', () async {
      final service = ThermalPrinterService();
      final config = await service.loadConfig();
      expect(config.transportType, PrinterTransportType.pdfDriver);
      expect(config.paperSize, PrinterPaperSize.mm80);
    });

    test('corrupt stored JSON falls back to defaultConfig instead of '
        'throwing', () async {
      SharedPreferences.setMockInitialValues({
        'thermal_printer_config': 'not valid json{{{',
      });
      final service = ThermalPrinterService();
      final config = await service.loadConfig();
      expect(config.transportType, PrinterTransportType.pdfDriver);
      expect(config.paperSize, PrinterPaperSize.mm80);
    });

    test('saveConfig then loadConfig round-trips the saved value', () async {
      final service = ThermalPrinterService();
      const saved = PrinterConfig(
        transportType: PrinterTransportType.network,
        paperSize: PrinterPaperSize.mm58,
        networkHost: '10.0.0.5',
      );
      await service.saveConfig(saved);
      final loaded = await service.loadConfig();
      expect(loaded.transportType, PrinterTransportType.network);
      expect(loaded.paperSize, PrinterPaperSize.mm58);
      expect(loaded.networkHost, '10.0.0.5');
    });
  });
}
