import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';

/// Ported from the Tax card in `frontend-flutter-pos/lib/features/pos/
/// screens/settings_modules_screen.dart` — COPY/ADAPT NEARLY EXACTLY:
/// `taxRate` is a fraction (0–1) on the wire, edited here as a percent
/// (0–100) — same `percent/100` conversion on save, same `0 <= percent
/// <= 100` validation.
class MobileTaxSettingsScreen extends ConsumerStatefulWidget {
  const MobileTaxSettingsScreen({super.key});

  @override
  ConsumerState<MobileTaxSettingsScreen> createState() =>
      _MobileTaxSettingsScreenState();
}

class _MobileTaxSettingsScreenState
    extends ConsumerState<MobileTaxSettingsScreen> {
  final _rateCtl = TextEditingController();
  bool _showTax = true;
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
    _rateCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tax = await ref.read(settingsServiceProvider).getTax();
      final fraction = (tax['taxRate'] as num?)?.toDouble() ?? 0;
      _rateCtl.text = (fraction * 100).toStringAsFixed(2);
      _showTax = tax['showTax'] as bool? ?? true;
      _loaded = true;
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final percent = double.tryParse(_rateCtl.text.trim());
    if (percent == null || percent < 0 || percent > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.formInvalidValue),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(settingsServiceProvider).updateTax({
        'taxRate': percent / 100,
        'showTax': _showTax,
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsSaveTax)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorGeneric}: $e'),
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
      appBar: AppBar(title: Text(l10n.settingsTax)),
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
                TextField(
                  controller: _rateCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.settingsTaxRateLabel,
                    suffixText: '%',
                    border: const OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.receiptTax),
                  value: _showTax,
                  onChanged: (v) => setState(() => _showTax = v),
                ),
                const SizedBox(height: PosTheme.spacingLg),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
    );
  }
}
