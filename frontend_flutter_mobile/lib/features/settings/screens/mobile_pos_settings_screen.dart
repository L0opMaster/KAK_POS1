import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';

const _kSaleScreenLayouts = ['GRID', 'LIST', 'COMPACT'];
const _kCashRoundingModes = [
  'NONE',
  'ROUND_UP',
  'ROUND_DOWN',
  'ROUND_NEAREST',
];

/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// pos_settings_screen.dart` — COPY/ADAPT NEARLY EXACTLY: same field list,
/// same JSON keys, same single combined `updatePosSettings` payload, same
/// conditional fields (`cashRoundingInterval` only when mode != `NONE`,
/// `kitchenPrinterName` only when kitchen display enabled,
/// `lowStockAlertEmail` only when low-stock alerts enabled). Discount
/// Presets stays read-only here too — source never wires an edit UI for
/// it on this screen either (see this port's research notes).
///
/// `receiptPaperWidth` here is a SEPARATE, backend-persisted value from
/// `mobile_printer_settings_screen.dart`'s `PrinterConfig.paperSize` (kept
/// locally via `ThermalPrinterService`) — the two are never synced,
/// matching source exactly. The print pipeline reads
/// `PrinterConfig.paperSize`, not this field — see the printer settings
/// screen's doc comment for the fuller explanation. This field exists
/// here only because the backend's POS-layout record has it; changing it
/// alone will not change what a printed receipt actually looks like.
class MobilePosSettingsScreen extends ConsumerStatefulWidget {
  const MobilePosSettingsScreen({super.key});

  @override
  ConsumerState<MobilePosSettingsScreen> createState() =>
      _MobilePosSettingsScreenState();
}

class _MobilePosSettingsScreenState
    extends ConsumerState<MobilePosSettingsScreen> {
  String _saleScreenLayout = 'GRID';
  int _productGridColumns = 5;
  bool _enableFavorites = true;
  String _cashRoundingMode = 'NONE';
  int _cashRoundingInterval = 100;
  bool _autoPrintReceipt = false;
  bool _receiptShowCustomer = false;
  bool _receiptShowBarcode = false;
  int _receiptPaperWidth = 80;
  bool _requireDiscountReason = false;
  bool _requirePinForPos = false;
  bool _enableKitchenDisplay = false;
  final _kitchenPrinterCtl = TextEditingController();
  bool _lowStockAlert = false;
  final _lowStockEmailCtl = TextEditingController();
  List<String> _discountPresetLabels = const [];

  bool _loaded = false;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _kitchenPrinterCtl.dispose();
    _lowStockEmailCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(settingsServiceProvider);
      final settings = await service.getPosSettings();
      _saleScreenLayout =
          settings['saleScreenLayout'] as String? ?? 'GRID';
      _productGridColumns = (settings['productGridColumns'] as num?)?.toInt() ?? 5;
      _enableFavorites = settings['enableFavorites'] as bool? ?? true;
      _cashRoundingMode = settings['cashRoundingMode'] as String? ?? 'NONE';
      _cashRoundingInterval =
          (settings['cashRoundingInterval'] as num?)?.toInt() ?? 100;
      _autoPrintReceipt = settings['autoPrintReceipt'] as bool? ?? false;
      _receiptShowCustomer = settings['receiptShowCustomer'] as bool? ?? false;
      _receiptShowBarcode = settings['receiptShowBarcode'] as bool? ?? false;
      _receiptPaperWidth = (settings['receiptPaperWidth'] as num?)?.toInt() ?? 80;
      _requireDiscountReason = settings['requireDiscountReason'] as bool? ?? false;
      _requirePinForPos = settings['requirePinForPos'] as bool? ?? false;
      _enableKitchenDisplay = settings['enableKitchenDisplay'] as bool? ?? false;
      _kitchenPrinterCtl.text = settings['kitchenPrinterName'] as String? ?? '';
      _lowStockAlert = settings['lowStockAlert'] as bool? ?? false;
      _lowStockEmailCtl.text = settings['lowStockAlertEmail'] as String? ?? '';

      try {
        final presets = await service.getDiscountPresets();
        _discountPresetLabels = (presets['presets'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>()
            .map((p) => '${p['label'] ?? ''}')
            .where((l) => l.isNotEmpty)
            .toList();
      } catch (_) {
        _discountPresetLabels = const [];
      }
      _loaded = true;
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(settingsServiceProvider).updatePosSettings({
        'saleScreenLayout': _saleScreenLayout,
        'productGridColumns': _productGridColumns,
        'enableFavorites': _enableFavorites,
        'cashRoundingMode': _cashRoundingMode,
        'cashRoundingInterval': _cashRoundingInterval,
        'autoPrintReceipt': _autoPrintReceipt,
        'receiptShowCustomer': _receiptShowCustomer,
        'receiptShowBarcode': _receiptShowBarcode,
        'receiptPaperWidth': _receiptPaperWidth,
        'requireDiscountReason': _requireDiscountReason,
        'requirePinForPos': _requirePinForPos,
        'enableKitchenDisplay': _enableKitchenDisplay,
        'kitchenPrinterName': _kitchenPrinterCtl.text.trim(),
        'lowStockAlert': _lowStockAlert,
        'lowStockAlertEmail': _lowStockEmailCtl.text.trim(),
      });
      ref.invalidate(posSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.posSettingsScreenSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.posSettingsScreenSaveFailed}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsPosSettings),
        actions: [
          IconButton(
            tooltip: l10n.posSettingsScreenSaveAllTooltip,
            icon: const Icon(Icons.save_outlined),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && !_loaded
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$_error'),
                  const SizedBox(height: PosTheme.spacingSm),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              children: [
                Text(
                  l10n.posSettingsScreenSaleScreen,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _saleScreenLayout,
                  decoration: InputDecoration(
                    labelText: l10n.posSettingsScreenDefaultLayout,
                  ),
                  items: [
                    for (final layout in _kSaleScreenLayouts)
                      DropdownMenuItem(value: layout, child: Text(layout)),
                  ],
                  onChanged: (v) => setState(() => _saleScreenLayout = v!),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _productGridColumns,
                  decoration: InputDecoration(
                    labelText: l10n.posSettingsScreenColumns,
                  ),
                  items: [
                    for (final n in [3, 4, 5, 6])
                      DropdownMenuItem(value: n, child: Text('$n')),
                  ],
                  onChanged: (v) => setState(() => _productGridColumns = v!),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenEnableFavorites),
                  value: _enableFavorites,
                  onChanged: (v) => setState(() => _enableFavorites = v),
                ),
                const Divider(height: PosTheme.spacingXl),
                Text(
                  l10n.posSettingsScreenCashRounding,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _cashRoundingMode,
                  decoration: InputDecoration(
                    labelText: l10n.posSettingsScreenRoundingMode,
                  ),
                  items: [
                    for (final mode in _kCashRoundingModes)
                      DropdownMenuItem(value: mode, child: Text(mode)),
                  ],
                  onChanged: (v) => setState(() => _cashRoundingMode = v!),
                ),
                if (_cashRoundingMode != 'NONE')
                  DropdownButtonFormField<int>(
                    initialValue: _cashRoundingInterval,
                    decoration: InputDecoration(
                      labelText: l10n.posSettingsScreenRoundingInterval,
                    ),
                    items: [
                      for (final n in [50, 100, 500])
                        DropdownMenuItem(value: n, child: Text('$n')),
                    ],
                    onChanged: (v) =>
                        setState(() => _cashRoundingInterval = v!),
                  ),
                const Divider(height: PosTheme.spacingXl),
                Text(
                  l10n.receiptTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenAutoPrint),
                  value: _autoPrintReceipt,
                  onChanged: (v) => setState(() => _autoPrintReceipt = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenShowCustomerInfo),
                  value: _receiptShowCustomer,
                  onChanged: (v) => setState(() => _receiptShowCustomer = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenShowBarcodes),
                  value: _receiptShowBarcode,
                  onChanged: (v) => setState(() => _receiptShowBarcode = v),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _receiptPaperWidth,
                  decoration: InputDecoration(
                    labelText: l10n.posSettingsScreenPaperWidth,
                  ),
                  items: [
                    for (final w in [58, 80])
                      DropdownMenuItem(value: w, child: Text('${w}mm')),
                  ],
                  onChanged: (v) => setState(() => _receiptPaperWidth = v!),
                ),
                const Divider(height: PosTheme.spacingXl),
                Text(
                  l10n.posSettingsScreenSecurity,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenRequireDiscountReason),
                  subtitle: _discountPresetLabels.isEmpty
                      ? null
                      : Text(_discountPresetLabels.join(', ')),
                  value: _requireDiscountReason,
                  onChanged: (v) => setState(() => _requireDiscountReason = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenRequirePin),
                  subtitle: Text(l10n.posSettingsScreenPinSubtitle),
                  value: _requirePinForPos,
                  onChanged: (v) => setState(() => _requirePinForPos = v),
                ),
                const Divider(height: PosTheme.spacingXl),
                Text(
                  l10n.posSettingsScreenKitchenDisplay,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenEnableKitchenDisplay),
                  subtitle: Text(l10n.posSettingsScreenKitchenSubtitle),
                  value: _enableKitchenDisplay,
                  onChanged: (v) => setState(() => _enableKitchenDisplay = v),
                ),
                if (_enableKitchenDisplay)
                  TextField(
                    controller: _kitchenPrinterCtl,
                    decoration: InputDecoration(
                      labelText: l10n.posSettingsScreenKitchenPrinterLabel,
                    ),
                  ),
                const Divider(height: PosTheme.spacingXl),
                Text(
                  l10n.posSettingsScreenStockAlerts,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.posSettingsScreenLowStockAlert),
                  value: _lowStockAlert,
                  onChanged: (v) => setState(() => _lowStockAlert = v),
                ),
                if (_lowStockAlert)
                  TextField(
                    controller: _lowStockEmailCtl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.posSettingsScreenAlertEmailLabel,
                    ),
                  ),
                const SizedBox(height: PosTheme.spacingLg),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? l10n.posSettingsScreenSaving
                        : l10n.posSettingsScreenSaveAll,
                  ),
                ),
              ],
            ),
    );
  }
}
