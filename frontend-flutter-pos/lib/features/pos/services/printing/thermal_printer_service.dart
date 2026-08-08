import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bluetooth_printer_transport.dart';
import 'escpos_receipt_builder.dart';
import 'network_printer_transport.dart';
import 'printer_profile.dart';
import 'printer_transport.dart';
import 'receipt_view_model.dart';
import 'usb_printer_transport.dart';

const _printerConfigPrefKey = 'thermal_printer_config';

/// Persists the selected printer transport/paper-size (Settings → Printers)
/// and drives an ESC/POS print job end-to-end: connect the configured
/// transport, build the receipt bytes (native text or Khmer bitmap — see
/// [EscPosReceiptBuilder]), write them, disconnect.
class ThermalPrinterService {
  ThermalPrinterService({
    this.builder = const EscPosReceiptBuilder(),
  });

  final EscPosReceiptBuilder builder;

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

  PrinterTransport _transportFor(PrinterConfig config) {
    switch (config.transportType) {
      case PrinterTransportType.bluetooth:
        final address = config.bluetoothAddress;
        if (address == null || address.isEmpty) {
          throw StateError('No Bluetooth printer selected');
        }
        return BluetoothPrinterTransport(address);
      case PrinterTransportType.usb:
        return UsbPrinterTransport(
          vendorId: config.usbVendorId?.toString(),
          productId: config.usbProductId?.toString(),
        );
      case PrinterTransportType.network:
        final host = config.networkHost;
        if (host == null || host.isEmpty) {
          throw StateError('No printer IP address configured');
        }
        return NetworkPrinterTransport(host, port: config.networkPort);
      case PrinterTransportType.pdfDriver:
        throw StateError(
          'pdfDriver is handled by PrintService, not ThermalPrinterService',
        );
    }
  }

  /// Connects, prints [receipt] and disconnects. [context] is used only if
  /// the receipt needs bitmap rendering (Khmer content) — caller must check
  /// `mounted` before invoking this after any prior `await`.
  Future<void> printReceipt(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterConfig config,
  ) async {
    final transport = _transportFor(config);
    await transport.connect();
    try {
      final bytes = await builder.build(context, receipt, config.paperSize);
      await transport.write(bytes);
    } finally {
      await transport.disconnect();
    }
  }

  /// Prints every receipt in [receipts] over a single connect/disconnect
  /// cycle instead of one per receipt — reconnecting per receipt (Bluetooth
  /// especially) is slow enough to make a large "Print All" batch
  /// impractical. Each receipt still gets its own feed+cut, exactly as
  /// [EscPosReceiptBuilder.build] already appends for a single receipt, so
  /// physical output is identical to calling [printReceipt] N times — only
  /// the connection overhead is batched, not the per-receipt formatting.
  ///
  /// [onProgress], if given, is called with (receipts printed so far, total)
  /// after each receipt is written. [context] must stay mounted for the
  /// whole call (used for Khmer bitmap rendering, same as [printReceipt]).
  Future<void> printReceipts(
    BuildContext context,
    List<ReceiptViewModel> receipts,
    PrinterConfig config, {
    void Function(int done, int total)? onProgress,
  }) async {
    final transport = _transportFor(config);
    await transport.connect();
    try {
      for (var i = 0; i < receipts.length; i++) {
        if (!context.mounted) return;
        final bytes =
            await builder.build(context, receipts[i], config.paperSize);
        await transport.write(bytes);
        onProgress?.call(i + 1, receipts.length);
      }
    } finally {
      await transport.disconnect();
    }
  }
}

final thermalPrinterServiceProvider = Provider<ThermalPrinterService>((ref) {
  return ThermalPrinterService();
});

final printerConfigProvider = FutureProvider<PrinterConfig>((ref) async {
  return ref.read(thermalPrinterServiceProvider).loadConfig();
});
