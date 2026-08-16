import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/print_service.dart';
import '../../pos/services/printing/bluetooth_printer_transport.dart';
import '../../pos/services/printing/printer_permission.dart';
import '../../pos/services/printing/printer_profile.dart';
import '../../pos/services/printing/receipt_view_model.dart';
import '../../pos/services/printing/thermal_printer_service.dart';

/// Ported from `_thermalPrinterSection` in `frontend-flutter-pos/lib/
/// features/pos/screens/settings_modules_screen.dart` — COPY/ADAPT NEARLY
/// EXACTLY: transport/paper-size pickers, conditional per-transport
/// fields (Bluetooth device dropdown from `BluetoothPrinterTransport.
/// pairedDevices()`, USB vendor/product ID text fields, network host/port
/// fields), `_saveThermalConfig`'s exact no-validation save-whatever's-
/// entered behavior (matching source — a network transport with an empty
/// host saves with `networkHost: null`, no error shown), and Test Print
/// building the same hardcoded sample `ReceiptViewModel` from the
/// in-memory (possibly-unsaved) form values, not from disk. Debug-only
/// "Print test suite" entry dropped (no `print_test_screen.dart`
/// equivalent in this port). NEW in this port only:
/// `ensurePrinterPermission` is called before Test Print for Bluetooth —
/// source never gates `connect()` behind a permission check at all (Day
/// 16's own doc comment).
///
/// This screen — not `mobile_pos_settings_screen.dart`'s `receiptPaperWidth`
/// dropdown — is the one whose paper-size value the print pipeline (Day
/// 13-16) actually reads (`PrinterConfig.paperSize` via `ThermalPrinterService
/// .loadConfig()`). Both fields exist, matching source's own duplication;
/// see that screen's doc comment for the same note from the other side.
class MobilePrinterSettingsScreen extends ConsumerStatefulWidget {
  const MobilePrinterSettingsScreen({super.key});

  @override
  ConsumerState<MobilePrinterSettingsScreen> createState() =>
      _MobilePrinterSettingsScreenState();
}

class _MobilePrinterSettingsScreenState
    extends ConsumerState<MobilePrinterSettingsScreen> {
  PrinterTransportType _transportType = PrinterTransportType.pdfDriver;
  PrinterPaperSize _paperSize = PrinterPaperSize.mm80;
  String? _bluetoothAddress;
  final _usbVendorCtl = TextEditingController();
  final _usbProductCtl = TextEditingController();
  final _hostCtl = TextEditingController();
  final _portCtl = TextEditingController(text: '9100');
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _usbVendorCtl.dispose();
    _usbProductCtl.dispose();
    _hostCtl.dispose();
    _portCtl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
    if (!mounted) return;
    setState(() {
      _transportType = config.transportType;
      _paperSize = config.paperSize;
      _bluetoothAddress = config.bluetoothAddress;
      _usbVendorCtl.text = config.usbVendorId?.toString() ?? '';
      _usbProductCtl.text = config.usbProductId?.toString() ?? '';
      _hostCtl.text = config.networkHost ?? '';
      _portCtl.text = '${config.networkPort}';
      _loading = false;
    });
  }

  PrinterConfig _currentConfig() => PrinterConfig(
    transportType: _transportType,
    paperSize: _paperSize,
    bluetoothAddress: _bluetoothAddress,
    usbVendorId: int.tryParse(_usbVendorCtl.text.trim()),
    usbProductId: int.tryParse(_usbProductCtl.text.trim()),
    networkHost: _hostCtl.text.trim().isEmpty ? null : _hostCtl.text.trim(),
    networkPort: int.tryParse(_portCtl.text.trim()) ?? 9100,
  );

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref
          .read(thermalPrinterServiceProvider)
          .saveConfig(_currentConfig());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsSavePrinters)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _testPrint() async {
    final l10n = context.l10n;
    final config = _currentConfig();
    if (config.transportType == PrinterTransportType.bluetooth) {
      final granted = await ensurePrinterPermission(config.transportType);
      if (!granted) return;
    }
    setState(() => _testing = true);
    const sample = ReceiptViewModel(
      language: AppLanguage.en,
      businessName: 'Test Business',
      invoiceNumber: 'TEST-0001',
      date: '2026-01-01',
      time: '12:00:00',
      lines: [
        ReceiptLineViewModel(
          name: 'Test Item',
          qty: 1,
          unitPrice: 1,
          lineTotal: 1,
        ),
      ],
      subtotal: 1,
      total: 1,
      paidAmount: 1,
      footer: 'Thank you!',
      currencyCode: 'USD',
    );
    try {
      if (config.transportType == PrinterTransportType.pdfDriver) {
        final bytes = await ref
            .read(printServiceProvider)
            .buildReceiptPdf(sample, config.paperSize, context: context);
        await Printing.layoutPdf(onLayout: (_) => bytes, name: 'test_print.pdf');
      } else {
        if (!mounted) return;
        await ref
            .read(thermalPrinterServiceProvider)
            .printReceipt(context, sample, config);
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.printerPrintSuccess)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.printerPrintFailed}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.settingsPrinters)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrinters)),
      body: ListView(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        children: [
          DropdownButtonFormField<PrinterTransportType>(
            initialValue: _transportType,
            decoration: InputDecoration(
              labelText: l10n.printerTransportType,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: PrinterTransportType.pdfDriver,
                child: Text(l10n.printerPdfDriver),
              ),
              DropdownMenuItem(
                value: PrinterTransportType.bluetooth,
                child: Text(l10n.printerBluetooth),
              ),
              DropdownMenuItem(
                value: PrinterTransportType.usb,
                child: Text(l10n.printerUsb),
              ),
              DropdownMenuItem(
                value: PrinterTransportType.network,
                child: Text(l10n.printerNetwork),
              ),
            ],
            onChanged: (v) => setState(() => _transportType = v!),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          DropdownButtonFormField<PrinterPaperSize>(
            initialValue: _paperSize,
            decoration: InputDecoration(
              labelText: l10n.printerPaperSize,
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: PrinterPaperSize.mm58,
                child: Text('58mm'),
              ),
              DropdownMenuItem(
                value: PrinterPaperSize.mm80,
                child: Text('80mm'),
              ),
            ],
            onChanged: (v) => setState(() => _paperSize = v!),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          if (_transportType == PrinterTransportType.bluetooth)
            FutureBuilder<List<BluetoothInfo>>(
              future: BluetoothPrinterTransport.pairedDevices(),
              builder: (context, snapshot) {
                final devices = snapshot.data ?? const [];
                return DropdownButtonFormField<String>(
                  initialValue:
                      devices.any((d) => d.macAdress == _bluetoothAddress)
                      ? _bluetoothAddress
                      : null,
                  decoration: InputDecoration(
                    labelText: l10n.printerSelectDevice,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final d in devices)
                      DropdownMenuItem(
                        value: d.macAdress,
                        child: Text('${d.name} (${d.macAdress})'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _bluetoothAddress = v),
                );
              },
            ),
          if (_transportType == PrinterTransportType.usb) ...[
            TextField(
              controller: _usbVendorCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Vendor ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextField(
              controller: _usbProductCtl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Product ID',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_transportType == PrinterTransportType.network) ...[
            TextField(
              controller: _hostCtl,
              decoration: InputDecoration(
                labelText: l10n.printerIpAddress,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextField(
              controller: _portCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.printerPort,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: PosTheme.spacingLg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _testPrint,
                  child: Text(l10n.printerTestPrint),
                ),
              ),
              const SizedBox(width: PosTheme.spacingMd),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.commonSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
