import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';

/// Ported from the Currencies card in `frontend-flutter-pos/lib/features/
/// pos/screens/settings_modules_screen.dart` — COPY/ADAPT NEARLY EXACTLY:
/// exchange rate is editable ONLY via the edit dialog (not inline), the
/// active `Switch` is a separate optimistic toggle (revert + error on
/// failure, matching Payment Methods), and the edit dialog's save sends
/// the FULL currency record (`code`/`name`/`symbol`/`exchangeRate`/
/// `displayOrder`/`defaultCurrency`/`active` all carried over unchanged
/// except the 3 edited fields) — the backend's `CurrencyRequest` requires
/// the whole record on every PUT, matching `updateCurrency`'s own doc
/// comment. On dialog success, invalidates `tenderCurrenciesProvider` so
/// the Payment screen's cash-tendering math picks up the new rate
/// immediately.
class MobileCurrenciesScreen extends ConsumerStatefulWidget {
  const MobileCurrenciesScreen({super.key});

  @override
  ConsumerState<MobileCurrenciesScreen> createState() =>
      _MobileCurrenciesScreenState();
}

class _MobileCurrenciesScreenState
    extends ConsumerState<MobileCurrenciesScreen> {
  List<Map<String, dynamic>> _currencies = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref.read(settingsServiceProvider).getCurrencies();
      if (mounted) setState(() => _currencies = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(int index, bool active) async {
    final l10n = context.l10n;
    final previous = List<Map<String, dynamic>>.from(_currencies);
    setState(
      () => _currencies[index] = {..._currencies[index], 'active': active},
    );
    try {
      await ref
          .read(settingsServiceProvider)
          .updateCurrencyStatus(_currencies[index]['id'], active);
    } catch (e) {
      if (mounted) {
        setState(() => _currencies = previous);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.errorGeneric}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _editCurrency(int index) async {
    final l10n = context.l10n;
    final currency = _currencies[index];
    final nameCtl = TextEditingController(text: '${currency['name'] ?? ''}');
    final symbolCtl = TextEditingController(
      text: '${currency['symbol'] ?? ''}',
    );
    final rateCtl = TextEditingController(
      text: '${currency['exchangeRate'] ?? ''}',
    );
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> save() async {
            final rate = double.tryParse(rateCtl.text.trim());
            if (rate == null || rate <= 0) {
              setState(() => error = l10n.errorValidation);
              return;
            }
            try {
              await ref
                  .read(settingsServiceProvider)
                  .updateCurrency(currency['id'], {
                    'code': currency['code'],
                    'name': nameCtl.text.trim(),
                    'symbol': symbolCtl.text.trim(),
                    'exchangeRate': rate,
                    'displayOrder': currency['displayOrder'],
                    'defaultCurrency': currency['defaultCurrency'],
                    'active': currency['active'],
                  });
              ref.invalidate(tenderCurrenciesProvider);
              if (context.mounted) {
                Navigator.of(dialogContext).pop();
                this.setState(() {
                  _currencies[index] = {
                    ...currency,
                    'name': nameCtl.text.trim(),
                    'symbol': symbolCtl.text.trim(),
                    'exchangeRate': rate,
                  };
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsSaveGeneral)),
                );
              }
            } catch (e) {
              setState(() => error = '${l10n.errorGeneric}: $e');
            }
          }

          return AlertDialog(
            title: Text('${currency['code'] ?? ''}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtl,
                  decoration: InputDecoration(labelText: l10n.commonName),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: symbolCtl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCurrencySymbol,
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: rateCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: l10n.settingsExchangeRatePerUsd,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: PosTheme.spacingSm),
                  Text(error!, style: TextStyle(color: PosTheme.errorRed)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonCancel),
              ),
              FilledButton(onPressed: save, child: Text(l10n.commonSave)),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsCurrencies),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: _load,
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
                  Text('$_error'),
                  const SizedBox(height: PosTheme.spacingSm),
                  OutlinedButton(
                    onPressed: _load,
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: _currencies.length,
              itemBuilder: (context, i) {
                final c = _currencies[i];
                final isDefault = c['defaultCurrency'] as bool? ?? false;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      PosTheme.radiusMedium,
                    ),
                    side: BorderSide(color: PosTheme.borderColorOf(context)),
                  ),
                  child: ListTile(
                    title: Text('${c['code'] ?? ''} ${c['symbol'] ?? ''}'),
                    subtitle: Text(
                      '${c['name'] ?? ''} · 1 USD = ${c['exchangeRate'] ?? ''}'
                      '${isDefault ? ' · ${l10n.commonActive}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.commonEdit,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editCurrency(i),
                        ),
                        Switch(
                          value: c['active'] as bool? ?? false,
                          onChanged: (v) => _toggle(i, v),
                        ),
                      ],
                    ),
                    onTap: () => _editCurrency(i),
                  ),
                );
              },
            ),
    );
  }
}
