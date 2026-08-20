import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/main_color_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/lan_address.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'print_test_screen.dart';
import '../services/print_service.dart';
import '../services/printing/bluetooth_printer_transport.dart';
import '../services/printing/printer_profile.dart';
import '../services/printing/receipt_bitmap_renderer.dart';
import '../services/printing/receipt_view_model.dart';
import '../services/printing/thermal_printer_service.dart';
import '../services/settings_service.dart';

/// Accessibility label for a main-color swatch — kMainColorOptions is a
/// fixed, ordered palette (see main_color_provider.dart), so matching by
/// index here is safe and doesn't need per-color hex-based lookup logic.
String _mainColorName(AppLocalizations l10n, Color color) {
  final index = kMainColorOptions.indexOf(color);
  switch (index) {
    case 0:
      return l10n.settingsMainColorGreen;
    case 1:
      return l10n.settingsMainColorBlue;
    case 2:
      return l10n.settingsMainColorPurple;
    case 3:
      return l10n.settingsMainColorOrange;
    case 4:
      return l10n.settingsMainColorRed;
    case 5:
      return l10n.settingsMainColorTeal;
    default:
      return l10n.settingsMainColor;
  }
}

class SettingsModulesScreen extends ConsumerStatefulWidget {
  const SettingsModulesScreen({super.key});

  @override
  ConsumerState<SettingsModulesScreen> createState() =>
      _SettingsModulesScreenState();
}

class _SettingsModulesScreenState extends ConsumerState<SettingsModulesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _paymentMethods = const [];
  List<Map<String, dynamic>> _currencies = const [];

  bool _savingGeneral = false;
  bool _savingCompany = false;
  bool _savingTax = false;
  bool _savingPrinters = false;

  late final TextEditingController _languageCtl;
  String? _selectedCurrencyCode;
  late final TextEditingController _receiptFooterCtl;
  late final TextEditingController _businessNameCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _websiteCtl;
  late final TextEditingController _printerNameCtl;
  late final TextEditingController _printerTypeCtl;
  late final TextEditingController _printerAddressCtl;
  late final TextEditingController _printerFooterCtl;

  bool _requireShiftForSales = false;
  bool _showKhqr = false;
  bool _showTax = true;

  // ── Direct thermal printer config (device-local, separate from the
  // backend-persisted `printers` settings above — see PrinterConfig) ──
  PrinterTransportType _transportType = PrinterTransportType.pdfDriver;
  PrinterPaperSize _paperSize = PrinterPaperSize.mm80;
  String? _bluetoothAddress;
  late final TextEditingController _networkHostCtl;
  late final TextEditingController _networkPortCtl;
  late final TextEditingController _usbVendorCtl;
  late final TextEditingController _usbProductCtl;
  bool _savingThermalConfig = false;
  bool _testPrinting = false;

  // ── Pairing server address override (device-local, separate from
  // everything above — see lan_address.dart's PairingServerOverride) ──
  late final TextEditingController _pairingServerCtl;
  bool _savingPairingServer = false;

  @override
  void initState() {
    super.initState();
    _languageCtl = TextEditingController();
    _receiptFooterCtl = TextEditingController();
    _businessNameCtl = TextEditingController();
    _addressCtl = TextEditingController();
    _phoneCtl = TextEditingController();
    _websiteCtl = TextEditingController();
    _printerNameCtl = TextEditingController();
    _printerTypeCtl = TextEditingController();
    _printerAddressCtl = TextEditingController();
    _printerFooterCtl = TextEditingController();
    _networkHostCtl = TextEditingController();
    _networkPortCtl = TextEditingController(text: '9100');
    _usbVendorCtl = TextEditingController();
    _usbProductCtl = TextEditingController();
    _pairingServerCtl = TextEditingController();
    Future.microtask(_load);
    Future.microtask(_loadThermalConfig);
    Future.microtask(_loadPairingServer);
  }

  @override
  void dispose() {
    _languageCtl.dispose();
    _receiptFooterCtl.dispose();
    _businessNameCtl.dispose();
    _addressCtl.dispose();
    _phoneCtl.dispose();
    _websiteCtl.dispose();
    _printerNameCtl.dispose();
    _printerTypeCtl.dispose();
    _printerAddressCtl.dispose();
    _printerFooterCtl.dispose();
    _networkHostCtl.dispose();
    _networkPortCtl.dispose();
    _usbVendorCtl.dispose();
    _usbProductCtl.dispose();
    _pairingServerCtl.dispose();
    super.dispose();
  }

  Future<void> _loadThermalConfig() async {
    final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
    if (!mounted) return;
    setState(() {
      _transportType = config.transportType;
      _paperSize = config.paperSize;
      _bluetoothAddress = config.bluetoothAddress;
      _networkHostCtl.text = config.networkHost ?? '';
      _networkPortCtl.text = '${config.networkPort}';
      _usbVendorCtl.text = config.usbVendorId?.toString() ?? '';
      _usbProductCtl.text = config.usbProductId?.toString() ?? '';
    });
  }

  Future<void> _saveThermalConfig() async {
    final l10n = context.l10n;
    setState(() => _savingThermalConfig = true);
    try {
      final config = PrinterConfig(
        transportType: _transportType,
        paperSize: _paperSize,
        bluetoothAddress: _bluetoothAddress,
        usbVendorId: int.tryParse(_usbVendorCtl.text.trim()),
        usbProductId: int.tryParse(_usbProductCtl.text.trim()),
        networkHost: _networkHostCtl.text.trim().isEmpty
            ? null
            : _networkHostCtl.text.trim(),
        networkPort: int.tryParse(_networkPortCtl.text.trim()) ?? 9100,
      );
      await ref.read(thermalPrinterServiceProvider).saveConfig(config);
      _toast(l10n.settingsPrinters);
    } finally {
      if (mounted) setState(() => _savingThermalConfig = false);
    }
  }

  Future<void> _loadPairingServer() async {
    final saved = await PairingServerOverride.load();
    if (!mounted) return;
    setState(() => _pairingServerCtl.text = saved ?? '');
  }

  Future<void> _savePairingServer() async {
    final l10n = context.l10n;
    setState(() => _savingPairingServer = true);
    try {
      await PairingServerOverride.save(_pairingServerCtl.text);
      if (mounted) _toast(l10n.settingsSavePairing);
    } finally {
      if (mounted) setState(() => _savingPairingServer = false);
    }
  }

  Future<void> _testPrint() async {
    final l10n = context.l10n;
    final language = ref.read(appLanguageProvider);
    setState(() => _testPrinting = true);
    try {
      final config = PrinterConfig(
        transportType: _transportType,
        paperSize: _paperSize,
        bluetoothAddress: _bluetoothAddress,
        usbVendorId: int.tryParse(_usbVendorCtl.text.trim()),
        usbProductId: int.tryParse(_usbProductCtl.text.trim()),
        networkHost: _networkHostCtl.text.trim().isEmpty
            ? null
            : _networkHostCtl.text.trim(),
        networkPort: int.tryParse(_networkPortCtl.text.trim()) ?? 9100,
      );
      final sample = _sampleReceipt(language, l10n);
      if (config.transportType == PrinterTransportType.pdfDriver) {
        // Same PrintService.buildReceiptPdf every real receipt renders
        // through — a test print must exercise the actual PDF pipeline
        // (Khmer font, layout, ...), not just show a fake success toast.
        final pdfBytes = await ref
            .read(printServiceProvider)
            .buildReceiptPdf(sample, config.paperSize, context: context);
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'receipt_test',
        );
      } else {
        if (!mounted) return;
        await ref
            .read(thermalPrinterServiceProvider)
            .printReceipt(context, sample, config);
      }
      if (mounted) _toast(l10n.printerPrintSuccess);
    } catch (e) {
      if (mounted) {
        final message = e is ApiException
            ? e.message
            : e is ReceiptRenderException
                ? e.message
                : l10n.printerPrintFailed;
        _toast(message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _testPrinting = false);
    }
  }

  ReceiptViewModel _sampleReceipt(AppLanguage language, AppLocalizations l10n) {
    return ReceiptViewModel(
      language: language,
      businessName: l10n.appName,
      invoiceNumber: 'TEST-0001',
      date: '01/01/2026',
      time: '12:00:00',
      lines: [
        ReceiptLineViewModel(
          name: language.isKhmer ? 'ទំនិញសាកល្បង' : 'Test Item',
          qty: 1,
          unitPrice: 1.00,
          lineTotal: 1.00,
        ),
      ],
      subtotal: 1.00,
      total: 1.00,
      paidAmount: 1.00,
      currencyCode: 'KHR',
      footer: l10n.receiptThankYou,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = ref.read(settingsServiceProvider);
    try {
      final general = await service.getGeneral();
      final company = await service.getCompanyProfile();
      final tax = await service.getTax();
      final printers = await service.getPrinters();
      final paymentMethods = await service.getPaymentMethods();
      final currencies = await service.getCurrencies();

      _languageCtl.text = '${general['defaultLanguage'] ?? ''}';
      _selectedCurrencyCode = (general['currency'] as String?)?.toUpperCase();
      _receiptFooterCtl.text = '${general['receiptFooter'] ?? ''}';
      _businessNameCtl.text = '${company['businessName'] ?? ''}';
      _addressCtl.text = '${company['address'] ?? ''}';
      _phoneCtl.text = '${company['phone'] ?? ''}';
      _websiteCtl.text = '${company['website'] ?? ''}';
      _printerNameCtl.text = '${printers['printerName'] ?? ''}';
      _printerTypeCtl.text = '${printers['printerType'] ?? ''}';
      _printerAddressCtl.text = '${printers['printerAddress'] ?? ''}';
      _printerFooterCtl.text = '${printers['invoiceFooter'] ?? ''}';
      _requireShiftForSales = general['requireShiftForSales'] as bool? ?? false;
      _showKhqr = general['showKhqr'] as bool? ?? false;
      _showTax = tax['showTax'] as bool? ?? true;
      _paymentMethods = List<Map<String, dynamic>>.from(paymentMethods);
      _currencies = List<Map<String, dynamic>>.from(currencies);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  Future<void> _saveGeneral() async {
    final l10n = context.l10n;
    if (_selectedCurrencyCode == null || _selectedCurrencyCode!.isEmpty) {
      _toast(l10n.errorValidation, isError: true);
      return;
    }
    final service = ref.read(settingsServiceProvider);
    setState(() => _savingGeneral = true);
    try {
      await service.updateGeneral({
        'defaultLanguage': _languageCtl.text.trim(),
        'currency': _selectedCurrencyCode,
        'receiptFooter': _receiptFooterCtl.text.trim(),
        'showKhqr': _showKhqr,
        'requireShiftForSales': _requireShiftForSales,
      });
      ref.invalidate(currencyCodeProvider);
      _toast(l10n.settingsSaveGeneral);
    } catch (e) {
      _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _savingGeneral = false);
    }
  }

  Future<void> _saveCompany() async {
    final l10n = context.l10n;
    if (_businessNameCtl.text.trim().isEmpty) {
      _toast(l10n.formPleaseEnterValue, isError: true);
      return;
    }
    final service = ref.read(settingsServiceProvider);
    setState(() => _savingCompany = true);
    try {
      await service.updateCompanyProfile({
        'businessName': _businessNameCtl.text.trim(),
        'address': _addressCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
        'website': _websiteCtl.text.trim(),
        'receiptFooter': _receiptFooterCtl.text.trim(),
      });
      // Only reached on a successful save — every screen watching
      // companyProfileProvider (POS AppBar, POS drawer) picks up the new
      // name immediately, no reload. A failed save never reaches this
      // line, so stale/invalid data is never pushed to shared state.
      ref.invalidate(companyProfileProvider);
      _toast(l10n.settingsCompanyProfile);
    } catch (e) {
      _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _savingCompany = false);
    }
  }

  /// Tax is per-product now (set on each item, see item_management_screen.dart)
  /// — this no longer saves a store-wide rate, only the receipt tax-line
  /// visibility toggle.
  Future<void> _saveTax() async {
    final l10n = context.l10n;
    final service = ref.read(settingsServiceProvider);
    setState(() => _savingTax = true);
    try {
      await service.updateTax({'showTax': _showTax});
      _toast(l10n.settingsTax);
    } catch (e) {
      _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _savingTax = false);
    }
  }

  Future<void> _savePrinters() async {
    final l10n = context.l10n;
    final service = ref.read(settingsServiceProvider);
    setState(() => _savingPrinters = true);
    try {
      await service.updatePrinters({
        'printerName': _printerNameCtl.text.trim(),
        'printerType': _printerTypeCtl.text.trim(),
        'printerAddress': _printerAddressCtl.text.trim(),
        'invoiceFooter': _printerFooterCtl.text.trim(),
      });
      _toast(l10n.settingsPrinters);
    } catch (e) {
      _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true);
    } finally {
      if (mounted) setState(() => _savingPrinters = false);
    }
  }

  Future<void> _togglePaymentMethod(int index, bool active) async {
    final l10n = context.l10n;
    final method = _paymentMethods[index];
    final id = method['id'];
    setState(() {
      _paymentMethods = List<Map<String, dynamic>>.from(_paymentMethods);
      _paymentMethods[index] = {...method, 'active': active};
    });
    try {
      final service = ref.read(settingsServiceProvider);
      await service.updatePaymentMethodStatus(id, active);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentMethods = List<Map<String, dynamic>>.from(_paymentMethods);
        _paymentMethods[index] = method;
      });
      _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true);
    }
  }

  Future<void> _toggleCurrency(int index, bool active) async {
    final l10n = context.l10n;
    final currency = _currencies[index];
    final id = currency['id'];
    setState(() {
      _currencies = List<Map<String, dynamic>>.from(_currencies);
      _currencies[index] = {...currency, 'active': active};
    });
    try {
      final service = ref.read(settingsServiceProvider);
      await service.updateCurrencyStatus(id, active);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currencies = List<Map<String, dynamic>>.from(_currencies);
        _currencies[index] = currency;
      });
      _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true);
    }
  }

  /// Opens a dialog to edit a currency's exchange rate (units of that
  /// currency per 1 USD — e.g. 4000 for KHR), name, and symbol. There is
  /// no other UI for this — the currencies list otherwise only exposes an
  /// active/inactive toggle, even though the backend has supported editing
  /// these fields since `PUT /api/settings/currencies/{id}` was added.
  Future<void> _editCurrency(int index) async {
    final l10n = context.l10n;
    final currency = _currencies[index];
    final nameCtl = TextEditingController(text: '${currency['name'] ?? ''}');
    final symbolCtl =
        TextEditingController(text: '${currency['symbol'] ?? ''}');
    final rateCtl = TextEditingController(
        text: '${(currency['exchangeRate'] as num?) ?? ''}');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.settingsCurrencies} — ${currency['code']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _textField(nameCtl, l10n.commonName),
            _textField(symbolCtl, l10n.settingsCurrencySymbol),
            _textField(
              rateCtl,
              l10n.settingsExchangeRatePerUsd,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final rate = double.tryParse(rateCtl.text.trim());
    if (rate == null || rate <= 0) {
      _toast(l10n.errorValidation, isError: true);
      return;
    }

    final id = currency['id'];
    final updated = {
      ...currency,
      'name': nameCtl.text.trim(),
      'symbol': symbolCtl.text.trim(),
      'exchangeRate': rate,
    };
    setState(() {
      _currencies = List<Map<String, dynamic>>.from(_currencies);
      _currencies[index] = updated;
    });
    try {
      final service = ref.read(settingsServiceProvider);
      await service.updateCurrency(id, {
        'code': currency['code'],
        'name': updated['name'],
        'symbol': updated['symbol'],
        'exchangeRate': rate,
        'displayOrder': currency['displayOrder'] ?? 0,
        'defaultCurrency': currency['defaultCurrency'] ?? false,
        'active': currency['active'] ?? true,
      });
      // The rate that matters for NEW receipts is whatever Settings has
      // right now — refresh the cached provider so the rest of the app
      // (payment screen, receipt preview) picks it up immediately instead
      // of waiting for its own next unrelated reload.
      ref.invalidate(tenderCurrenciesProvider);
      if (mounted) _toast(l10n.settingsSaveGeneral);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currencies = List<Map<String, dynamic>>.from(_currencies);
        _currencies[index] = currency;
      });
      _toast(e is ApiException ? e.message : l10n.errorGeneric, isError: true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? PosTheme.errorRed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.commonRefresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(PosTheme.spacingLg),
                    children: [
                      _SectionCard(
                        title: l10n.settingsGeneral,
                        icon: Icons.tune,
                        children: [
                          _textField(
                              _languageCtl, l10n.settingsDefaultLanguage),
                          _currencyDropdown(),
                          _textField(
                              _receiptFooterCtl, l10n.settingsReceiptFooter),
                          SwitchListTile(
                            value: _requireShiftForSales,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.settingsRequireShiftForSales),
                            onChanged: (value) => setState(
                              () => _requireShiftForSales = value,
                            ),
                          ),
                          SwitchListTile(
                            value: _showKhqr,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.settingsShowKhqrOnReceipts),
                            onChanged: (value) =>
                                setState(() => _showKhqr = value),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.language, size: 20),
                            title: Text(l10n.settingsLanguage),
                            trailing: SegmentedButton<AppLanguage>(
                              segments: [
                                ButtonSegment(
                                  value: AppLanguage.en,
                                  label: Text(l10n.languageEnglish),
                                ),
                                ButtonSegment(
                                  value: AppLanguage.km,
                                  label: Text(l10n.languageKhmer),
                                ),
                              ],
                              selected: {ref.watch(appLanguageProvider)},
                              onSelectionChanged: (selection) => ref
                                  .read(appLanguageProvider.notifier)
                                  .setLanguage(selection.first),
                            ),
                          ),
                          SwitchListTile(
                            value: ref.watch(themeModeProvider).value ==
                                ThemeMode.dark,
                            contentPadding: EdgeInsets.zero,
                            secondary: Icon(
                              ref.watch(themeModeProvider).value ==
                                      ThemeMode.dark
                                  ? Icons.dark_mode
                                  : Icons.light_mode,
                              size: 20,
                            ),
                            title: Text(l10n.settingsDarkMode),
                            onChanged: (value) {
                              ref.read(themeModeProvider.notifier).toggle();
                            },
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading:
                                const Icon(Icons.palette_outlined, size: 20),
                            title: Text(l10n.settingsMainColor),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: kMainColorOptions.map((color) {
                                  final selected =
                                      ref.watch(mainColorProvider) == color;
                                  return Semantics(
                                    button: true,
                                    selected: selected,
                                    label: _mainColorName(l10n, color),
                                    child: GestureDetector(
                                      onTap: () => ref
                                          .read(mainColorProvider.notifier)
                                          .setMainColor(color),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected
                                                ? PosTheme.textPrimaryOf(
                                                    context)
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: selected
                                            ? const Icon(Icons.check,
                                                color: Colors.white, size: 18)
                                            : null,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          _saveButton(
                            l10n.settingsSaveGeneral,
                            _savingGeneral,
                            _saveGeneral,
                          ),
                        ],
                      ),
                      _SectionCard(
                        title: l10n.settingsCompanyProfile,
                        icon: Icons.storefront_outlined,
                        children: [
                          _textField(_businessNameCtl, l10n.formName),
                          _textField(_addressCtl, l10n.formAddress),
                          _textField(
                            _phoneCtl,
                            l10n.formPhone,
                            keyboardType: TextInputType.phone,
                          ),
                          _textField(
                            _websiteCtl,
                            l10n.formWebsite,
                            keyboardType: TextInputType.url,
                          ),
                          _saveButton(
                            l10n.settingsSaveCompany,
                            _savingCompany,
                            _saveCompany,
                          ),
                        ],
                      ),
                      _SectionCard(
                        title: l10n.settingsTax,
                        icon: Icons.receipt_long_outlined,
                        children: [
                          // Tax rate is per-product now (see
                          // item_management_screen.dart) — this section only
                          // controls whether the tax line prints on receipts.
                          SwitchListTile(
                            value: _showTax,
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.receiptTax),
                            onChanged: (value) =>
                                setState(() => _showTax = value),
                          ),
                          _saveButton(
                              l10n.settingsSaveTax, _savingTax, _saveTax),
                        ],
                      ),
                      _SectionCard(
                        title: l10n.settingsPrinters,
                        icon: Icons.print_outlined,
                        children: [
                          _textField(_printerNameCtl, l10n.formName),
                          _textField(
                              _printerTypeCtl, l10n.printerTransportType),
                          _textField(_printerAddressCtl, l10n.printerIpAddress),
                          _textField(
                              _printerFooterCtl, l10n.settingsReceiptFooter),
                          _saveButton(
                            l10n.settingsSavePrinters,
                            _savingPrinters,
                            _savePrinters,
                          ),
                          const Divider(height: PosTheme.spacingXl),
                          _thermalPrinterSection(l10n),
                        ],
                      ),
                      _SectionCard(
                        title: l10n.settingsPairing,
                        icon: Icons.wifi_tethering,
                        children: [
                          Text(
                            l10n.settingsPairingServerAddressHelp,
                            style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                          const SizedBox(height: PosTheme.spacingMd),
                          _textField(
                            _pairingServerCtl,
                            l10n.settingsPairingServerAddress,
                            keyboardType: TextInputType.url,
                            hintText: l10n.settingsPairingServerAddressHint,
                          ),
                          _saveButton(
                            l10n.settingsSavePairing,
                            _savingPairingServer,
                            _savePairingServer,
                          ),
                        ],
                      ),
                      _SectionCard(
                        title: l10n.settingsPaymentMethods,
                        icon: Icons.payments_outlined,
                        children: _paymentMethods.isEmpty
                            ? [_emptyState(l10n.commonNone)]
                            : _paymentMethods
                                .asMap()
                                .entries
                                .map(
                                  (entry) => _PaymentMethodTile(
                                    name: '${entry.value['name']}',
                                    code: '${entry.value['code']}',
                                    isCash: entry.value['cash'] == true ||
                                        entry.value['isCash'] == true,
                                    active: entry.value['active'] == true,
                                    onToggle: (value) => _togglePaymentMethod(
                                      entry.key,
                                      value,
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                      _SectionCard(
                        title: l10n.settingsPosSettings,
                        icon: Icons.point_of_sale,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: PosTheme.primaryGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.grid_view,
                                color: PosTheme.primaryGreen,
                                size: 20,
                              ),
                            ),
                            title: Text(l10n.settingsPosSettings),
                            subtitle: Text(l10n.settingsReceiptFooter),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context)
                                .pushNamed('/pos-settings'),
                          ),
                        ],
                      ),
                      _SectionCard(
                        title: l10n.settingsCurrencies,
                        icon: Icons.currency_exchange,
                        children: _currencies.isEmpty
                            ? [_emptyState(l10n.commonNone)]
                            : _currencies
                                .asMap()
                                .entries
                                .map(
                                  (entry) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () => _editCurrency(entry.key),
                                    title: Text(
                                      '${entry.value['code']} ${entry.value['symbol'] ?? ''}',
                                    ),
                                    subtitle: Text(
                                      '${entry.value['name']}'
                                      ' · 1 USD = ${entry.value['exchangeRate'] ?? '—'}'
                                      '${entry.value['defaultCurrency'] == true ? ' · ${l10n.commonActive}' : ''}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined,
                                              size: 20),
                                          tooltip: l10n.commonEdit,
                                          onPressed: () =>
                                              _editCurrency(entry.key),
                                        ),
                                        Switch(
                                          value: entry.value['active'] == true,
                                          onChanged: (value) =>
                                              _toggleCurrency(entry.key, value),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PosTheme.spacingMd),
      child: Text(
        message,
        style: TextStyle(color: PosTheme.textSecondaryOf(context)),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    String? hintText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PosTheme.spacingMd),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          suffixText: suffixText,
          hintText: hintText,
        ),
      ),
    );
  }

  /// Direct thermal printer configuration (req. 10-13): which transport to
  /// use for raw ESC/POS printing — Bluetooth, USB or Network — plus paper
  /// width. Kept separate from the backend `printers` fields above, which
  /// only describe a document label/footer, not a live connection.
  Widget _thermalPrinterSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<PrinterTransportType>(
          initialValue: _transportType,
          decoration: InputDecoration(labelText: l10n.printerTransportType),
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
          onChanged: (value) =>
              setState(() => _transportType = value ?? _transportType),
        ),
        const SizedBox(height: PosTheme.spacingMd),
        DropdownButtonFormField<PrinterPaperSize>(
          initialValue: _paperSize,
          decoration: InputDecoration(labelText: l10n.printerPaperSize),
          items: [
            DropdownMenuItem(
              value: PrinterPaperSize.mm58,
              child: Text(l10n.printerPaper58mm),
            ),
            DropdownMenuItem(
              value: PrinterPaperSize.mm80,
              child: Text(l10n.printerPaper80mm),
            ),
          ],
          onChanged: (value) =>
              setState(() => _paperSize = value ?? _paperSize),
        ),
        const SizedBox(height: PosTheme.spacingMd),
        if (_transportType == PrinterTransportType.bluetooth)
          FutureBuilder<List<BluetoothInfo>>(
            future: BluetoothPrinterTransport.pairedDevices(),
            builder: (context, snapshot) {
              final devices = snapshot.data ?? const [];
              return Padding(
                padding: const EdgeInsets.only(bottom: PosTheme.spacingMd),
                child: DropdownButtonFormField<String>(
                  initialValue:
                      devices.any((d) => d.macAdress == _bluetoothAddress)
                          ? _bluetoothAddress
                          : null,
                  decoration:
                      InputDecoration(labelText: l10n.printerSelectDevice),
                  items: devices
                      .map((d) => DropdownMenuItem(
                            value: d.macAdress,
                            child: Text('${d.name} (${d.macAdress})'),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _bluetoothAddress = value),
                ),
              );
            },
          ),
        if (_transportType == PrinterTransportType.usb) ...[
          _textField(_usbVendorCtl, 'Vendor ID',
              keyboardType: TextInputType.number),
          _textField(_usbProductCtl, 'Product ID',
              keyboardType: TextInputType.number),
        ],
        if (_transportType == PrinterTransportType.network) ...[
          _textField(_networkHostCtl, l10n.printerIpAddress),
          _textField(_networkPortCtl, l10n.printerPort,
              keyboardType: TextInputType.number),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.only(right: PosTheme.spacingSm),
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PrintTestScreen()),
                  ),
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Print test suite'),
                ),
              ),
            OutlinedButton.icon(
              onPressed: _testPrinting ? null : _testPrint,
              icon: _testPrinting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print, size: 18),
              label: Text(l10n.printerTestPrint),
            ),
            const SizedBox(width: PosTheme.spacingSm),
            _saveButton(
                l10n.commonSave, _savingThermalConfig, _saveThermalConfig),
          ],
        ),
      ],
    );
  }

  /// The currency picker for General settings. Options come from the
  /// Currencies section below (active currencies); the currently selected
  /// code is always included even if it isn't in that list, so a legacy
  /// value never disappears from the field.
  Widget _currencyDropdown() {
    final options = <String>{
      for (final currency in _currencies)
        if (currency['active'] == true) '${currency['code']}',
      if (_selectedCurrencyCode != null && _selectedCurrencyCode!.isNotEmpty)
        _selectedCurrencyCode!,
    }.toList()
      ..sort();
    final byCode = {
      for (final currency in _currencies) '${currency['code']}': currency,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: PosTheme.spacingMd),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(_selectedCurrencyCode)
            ? _selectedCurrencyCode
            : null,
        decoration: InputDecoration(labelText: context.l10n.settingsCurrencies),
        items: options
            .map(
              (code) => DropdownMenuItem(
                value: code,
                child: Text(
                  byCode[code] != null
                      ? '$code · ${byCode[code]!['name']} (${byCode[code]!['symbol'] ?? ''})'
                      : code,
                ),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedCurrencyCode = value),
      ),
    );
  }

  Widget _saveButton(
      String label, bool saving, Future<void> Function() onPressed) {
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: saving ? null : onPressed,
        child: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: PosTheme.errorRed,
              size: 40,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: PosTheme.textSecondaryOf(context)),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: PosTheme.spacingLg),
      padding: const EdgeInsets.all(PosTheme.spacingLg),
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.borderColorOf(context)),
        boxShadow: PosTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: PosTheme.primaryGreenDark),
              const SizedBox(width: PosTheme.spacingSm),
              Text(
                title,
                style: TextStyle(
                  fontSize: PosTheme.fontSizeLg,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.spacingMd),
          ...children,
        ],
      ),
    );
  }
}

/// A styled payment method tile matching Loyverse / POS screen icons.
class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.name,
    required this.code,
    required this.isCash,
    required this.active,
    required this.onToggle,
  });

  final String name;
  final String code;
  final bool isCash;
  final bool active;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForCode(code);
    final color = _colorForCode(code);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: active ? Colors.white : PosTheme.backgroundPageOf(context),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(
          color: active
              ? PosTheme.borderColorOf(context)
              : PosTheme.dividerColorOf(context),
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.12) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
          ),
          child: Icon(
            iconData,
            color: active ? color : PosTheme.textHintOf(context),
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: active
                ? PosTheme.textPrimaryOf(context)
                : PosTheme.textHintOf(context),
          ),
        ),
        subtitle: Text(
          code,
          style: TextStyle(
            fontSize: 11,
            color: PosTheme.textHintOf(context),
          ),
        ),
        trailing: Switch(
          value: active,
          activeColor: PosTheme.primaryGreen,
          onChanged: onToggle,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        ),
      ),
    );
  }

  static IconData _iconForCode(String code) {
    switch (code.toUpperCase()) {
      case 'CASH':
        return Icons.money;
      case 'CARD':
        return Icons.credit_card;
      case 'ABA':
        return Icons.phone_android;
      case 'KHQR':
        return Icons.qr_code;
      case 'BANK_TRANSFER':
        return Icons.account_balance;
      case 'WING':
        return Icons.phone_iphone;
      case 'ACLEDA':
        return Icons.account_balance;
      case 'CHECK':
        return Icons.receipt;
      case 'MOBILE_WALLET':
        return Icons.mobile_friendly;
      default:
        return Icons.payment;
    }
  }

  static Color _colorForCode(String code) {
    switch (code.toUpperCase()) {
      case 'CASH':
        return const Color(0xFF4CAF50);
      case 'CARD':
        return const Color(0xFF2196F3);
      case 'ABA':
        return const Color(0xFFE91E63);
      case 'KHQR':
        return const Color(0xFF9C27B0);
      case 'BANK_TRANSFER':
        return const Color(0xFF607D8B);
      case 'WING':
        return const Color(0xFFFF5722);
      case 'ACLEDA':
        return const Color(0xFF795548);
      case 'CHECK':
        return const Color(0xFFFF9800);
      case 'MOBILE_WALLET':
        return const Color(0xFF00BCD4);
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}
