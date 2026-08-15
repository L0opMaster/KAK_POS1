/// POS Settings — Loyverse-inspired POS configuration screen.
///
/// Controls sale screen layout, receipt defaults, cash rounding,
/// discount presets, and kitchen display settings.
/// All changes are persisted to the backend via SettingsService.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../services/settings_service.dart';
import '../../../core/utils/l10n_extensions.dart';

class PosSettingsScreen extends ConsumerStatefulWidget {
  const PosSettingsScreen({super.key});

  @override
  ConsumerState<PosSettingsScreen> createState() => _PosSettingsScreenState();
}

class _PosSettingsScreenState extends ConsumerState<PosSettingsScreen> {
  bool _loading = true;
  String? _error;
  bool _saving = false;

  // POS Layout
  String _saleScreenLayout = 'GRID';
  int _productGridColumns = 4;
  bool _enableFavorites = false;

  // Cash Rounding
  String _cashRoundingMode = 'NONE';
  int _cashRoundingInterval = 0;

  // Receipt
  bool _autoPrintReceipt = false;
  bool _receiptShowCustomer = true;
  bool _receiptShowBarcode = false;
  int _receiptPaperWidth = 58;

  // Discount
  bool _requireDiscountReason = false;
  List<Map<String, dynamic>> _discountPresets = [];

  // Security
  bool _requirePinForPos = false;

  // Kitchen Display
  bool _enableKitchenDisplay = false;
  late final TextEditingController _kitchenPrinterNameCtl;

  // Stock Alert
  bool _lowStockAlert = true;
  late final TextEditingController _lowStockAlertEmailCtl;

  @override
  void initState() {
    super.initState();
    _kitchenPrinterNameCtl = TextEditingController();
    _lowStockAlertEmailCtl = TextEditingController();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _kitchenPrinterNameCtl.dispose();
    _lowStockAlertEmailCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(settingsServiceProvider);
      final pos = await service.getPosSettings();
      final discount = await service.getDiscountPresets();

      _saleScreenLayout = pos['saleScreenLayout'] as String? ?? 'GRID';
      _productGridColumns = pos['productGridColumns'] as int? ?? 4;
      _enableFavorites = pos['enableFavorites'] as bool? ?? false;
      _cashRoundingMode = pos['cashRoundingMode'] as String? ?? 'NONE';
      _cashRoundingInterval = pos['cashRoundingInterval'] as int? ?? 0;
      _autoPrintReceipt = pos['autoPrintReceipt'] as bool? ?? false;
      _receiptShowCustomer = pos['receiptShowCustomer'] as bool? ?? true;
      _receiptShowBarcode = pos['receiptShowBarcode'] as bool? ?? false;
      _receiptPaperWidth = pos['receiptPaperWidth'] as int? ?? 58;
      _requireDiscountReason = pos['requireDiscountReason'] as bool? ?? false;
      _requirePinForPos = pos['requirePinForPos'] as bool? ?? false;
      _enableKitchenDisplay = pos['enableKitchenDisplay'] as bool? ?? false;
      _kitchenPrinterNameCtl.text = pos['kitchenPrinterName'] as String? ?? '';
      _lowStockAlert = pos['lowStockAlert'] as bool? ?? true;
      _lowStockAlertEmailCtl.text = pos['lowStockAlertEmail'] as String? ?? '';

      if (discount['presets'] is List) {
        _discountPresets =
            List<Map<String, dynamic>>.from(discount['presets'] as List);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = ref.read(settingsServiceProvider);
      await service.updatePosSettings({
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
        'kitchenPrinterName': _kitchenPrinterNameCtl.text.trim(),
        'lowStockAlert': _lowStockAlert,
        'lowStockAlertEmail': _lowStockAlertEmailCtl.text.trim(),
      });
      ref.invalidate(posSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.posSettingsScreenSaved)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.posSettingsScreenSaveFailed(e.toString()),
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsPosSettings),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: context.l10n.posSettingsScreenSaveAllTooltip,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: PosTheme.errorRed, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        label: Text(context.l10n.commonRetry),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Sale Screen Layout ──
                    _SectionCard(
                      title: context.l10n.posSettingsScreenSaleScreen,
                      icon: Icons.grid_view,
                      children: [
                        _dropdownField(
                          context.l10n.posSettingsScreenDefaultLayout,
                          _saleScreenLayout,
                          ['GRID', 'LIST', 'COMPACT'],
                          (v) => setState(() => _saleScreenLayout = v!),
                        ),
                        _dropdownField(
                          context.l10n.posSettingsScreenColumns,
                          _productGridColumns.toString(),
                          ['3', '4', '5', '6'],
                          (v) => setState(
                              () => _productGridColumns = int.parse(v!)),
                        ),
                        SwitchListTile(
                          value: _enableFavorites,
                          contentPadding: EdgeInsets.zero,
                          title:
                              Text(context.l10n.posSettingsScreenEnableFavorites),
                          subtitle: Text(
                              context.l10n.posSettingsScreenPinFavoriteProducts),
                          onChanged: (v) =>
                              setState(() => _enableFavorites = v),
                        ),
                      ],
                    ),
                    // ── Cash Rounding ──
                    _SectionCard(
                      title: context.l10n.posSettingsScreenCashRounding,
                      icon: Icons.monetization_on_outlined,
                      children: [
                        _dropdownField(
                          context.l10n.posSettingsScreenRoundingMode,
                          _cashRoundingMode,
                          ['NONE', 'ROUND_UP', 'ROUND_DOWN', 'ROUND_NEAREST'],
                          (v) => setState(() => _cashRoundingMode = v!),
                        ),
                        if (_cashRoundingMode != 'NONE')
                          _dropdownField(
                            context.l10n.posSettingsScreenRoundingInterval,
                            _cashRoundingInterval.toString(),
                            ['50', '100', '500'],
                            (v) => setState(
                                () => _cashRoundingInterval = int.parse(v!)),
                          ),
                      ],
                    ),
                    // ── Receipt ──
                    _SectionCard(
                      title: context.l10n.receiptTitle,
                      icon: Icons.receipt_long,
                      children: [
                        _dropdownField(
                          context.l10n.posSettingsScreenPaperWidth,
                          _receiptPaperWidth.toString(),
                          ['58', '80'],
                          (v) => setState(
                              () => _receiptPaperWidth = int.parse(v!)),
                        ),
                        SwitchListTile(
                          value: _autoPrintReceipt,
                          contentPadding: EdgeInsets.zero,
                          title: Text(context.l10n.posSettingsScreenAutoPrint),
                          onChanged: (v) =>
                              setState(() => _autoPrintReceipt = v),
                        ),
                        SwitchListTile(
                          value: _receiptShowCustomer,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              context.l10n.posSettingsScreenShowCustomerInfo),
                          onChanged: (v) =>
                              setState(() => _receiptShowCustomer = v),
                        ),
                        SwitchListTile(
                          value: _receiptShowBarcode,
                          contentPadding: EdgeInsets.zero,
                          title:
                              Text(context.l10n.posSettingsScreenShowBarcodes),
                          onChanged: (v) =>
                              setState(() => _receiptShowBarcode = v),
                        ),
                      ],
                    ),
                    // ── Discount ──
                    _SectionCard(
                      title: context.l10n.posSettingsScreenDiscount,
                      icon: Icons.sell_outlined,
                      children: [
                        SwitchListTile(
                          value: _requireDiscountReason,
                          contentPadding: EdgeInsets.zero,
                          title: Text(context
                              .l10n.posSettingsScreenRequireDiscountReason),
                          onChanged: (v) =>
                              setState(() => _requireDiscountReason = v),
                        ),
                        if (_discountPresets.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              context.l10n.posSettingsScreenQuickPresets(
                                _discountPresets
                                    .map((d) => d['label'])
                                    .join(', '),
                              ),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: PosTheme.textSecondaryOf(context)),
                            ),
                          ),
                      ],
                    ),
                    // ── Security ──
                    _SectionCard(
                      title: context.l10n.posSettingsScreenSecurity,
                      icon: Icons.lock_outline,
                      children: [
                        SwitchListTile(
                          value: _requirePinForPos,
                          contentPadding: EdgeInsets.zero,
                          title:
                              Text(context.l10n.posSettingsScreenRequirePin),
                          subtitle:
                              Text(context.l10n.posSettingsScreenPinSubtitle),
                          onChanged: (v) =>
                              setState(() => _requirePinForPos = v),
                        ),
                      ],
                    ),
                    // ── Kitchen Display ──
                    _SectionCard(
                      title: context.l10n.posSettingsScreenKitchenDisplay,
                      icon: Icons.dining_outlined,
                      children: [
                        SwitchListTile(
                          value: _enableKitchenDisplay,
                          contentPadding: EdgeInsets.zero,
                          title: Text(context
                              .l10n.posSettingsScreenEnableKitchenDisplay),
                          subtitle: Text(
                              context.l10n.posSettingsScreenKitchenSubtitle),
                          onChanged: (v) =>
                              setState(() => _enableKitchenDisplay = v),
                        ),
                        if (_enableKitchenDisplay)
                          _textField(_kitchenPrinterNameCtl,
                              context.l10n.posSettingsScreenKitchenPrinterLabel),
                      ],
                    ),
                    // ── Stock Alerts ──
                    _SectionCard(
                      title: context.l10n.posSettingsScreenStockAlerts,
                      icon: Icons.inventory_2_outlined,
                      children: [
                        SwitchListTile(
                          value: _lowStockAlert,
                          contentPadding: EdgeInsets.zero,
                          title:
                              Text(context.l10n.posSettingsScreenLowStockAlert),
                          onChanged: (v) => setState(() => _lowStockAlert = v),
                        ),
                        if (_lowStockAlert)
                          _textField(_lowStockAlertEmailCtl,
                              context.l10n.posSettingsScreenAlertEmailLabel,
                              keyboardType: TextInputType.emailAddress),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving
                            ? context.l10n.posSettingsScreenSaving
                            : context.l10n.posSettingsScreenSaveAll),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _dropdownField(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options
            .map((o) => DropdownMenuItem(value: o, child: Text(o)))
            .toList(),
        onChanged: onChanged,
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
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        border: Border.all(color: PosTheme.borderColorOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: PosTheme.primaryGreenDark),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
