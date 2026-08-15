import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'printer_profile.dart';

const _printerConfigPrefKey = 'thermal_printer_config';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// thermal_printer_service.dart` — PARTIAL PORT. `loadConfig`/`saveConfig`
/// (SharedPreferences-backed persistence for Settings → Printers, Day 19 —
/// not built yet, so nothing calls `saveConfig` today either, but it's the
/// natural pair of `loadConfig` and equally self-contained) are COPY/ADAPT
/// NEARLY EXACTLY. Everything else — the actual ESC/POS transport dispatch
/// (`printReceipt`/`printReceipts`/`_transportFor`, and the
/// `EscPosReceiptBuilder` field they depend on) — is dropped until Day
/// 15/16 build the bluetooth/usb/network transports it needs; until then
/// `print_service.dart`'s `printReceipt` only ever takes the `pdfDriver`
/// branch, which never touches any of that.
class ThermalPrinterService {
  const ThermalPrinterService();

  Future<PrinterConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_printerConfigPrefKey);
    if (raw == null) return PrinterConfig.defaultConfig;
    try {
      return PrinterConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return PrinterConfig.defaultConfig;
    }
  }

  Future<void> saveConfig(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerConfigPrefKey, jsonEncode(config.toJson()));
  }
}

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return const ThermalPrinterService();
});

final printerConfigProvider = FutureProvider<PrinterConfig>((ref) async {
  return ref.read(thermalPrinterServiceProvider).loadConfig();
});
