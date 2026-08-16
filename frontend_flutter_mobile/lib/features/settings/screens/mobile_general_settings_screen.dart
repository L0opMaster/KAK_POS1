import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/providers/currency_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/providers/main_color_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';

String _mainColorLabel(dynamic l10n, Color color) {
  if (color.toARGB32() == kMainColorOptions[0].toARGB32()) {
    return l10n.settingsMainColorGreen;
  }
  if (color.toARGB32() == kMainColorOptions[1].toARGB32()) {
    return l10n.settingsMainColorBlue;
  }
  if (color.toARGB32() == kMainColorOptions[2].toARGB32()) {
    return l10n.settingsMainColorPurple;
  }
  if (color.toARGB32() == kMainColorOptions[3].toARGB32()) {
    return l10n.settingsMainColorOrange;
  }
  if (color.toARGB32() == kMainColorOptions[4].toARGB32()) {
    return l10n.settingsMainColorRed;
  }
  return l10n.settingsMainColorTeal;
}

/// Ported from the General card in `frontend-flutter-pos/lib/features/pos/
/// screens/settings_modules_screen.dart` — COPY/ADAPT NEARLY EXACTLY for
/// the backend-persisted fields (`defaultLanguage`/`currency`/
/// `requireShiftForSales`/`showKhqr`, saved together via one
/// `updateGeneral` call that also invalidates `currencyCodeProvider`) and
/// for the three device-local, instant-apply controls this section hosts
/// alongside them: app language (`appLanguageProvider`), dark mode
/// (`themeModeProvider.notifier.toggle()`), and Main Color (the swatch
/// `Wrap`, `Semantics`-wrapped, no Save button — `mainColorProvider
/// .notifier.setMainColor()` fires immediately on tap, exactly as this
/// project's Day 3 work and this plan's own Day 19 notes describe).
///
/// `receiptFooter` is intentionally NOT edited here — see
/// `mobile_company_profile_screen.dart`'s doc comment for why this port
/// splits that field differently from source's shared-controller
/// approach. This screen's save re-sends the current
/// `companyProfileProvider` value unchanged so saving General can never
/// blank it out server-side.
class MobileGeneralSettingsScreen extends ConsumerStatefulWidget {
  const MobileGeneralSettingsScreen({super.key});

  @override
  ConsumerState<MobileGeneralSettingsScreen> createState() =>
      _MobileGeneralSettingsScreenState();
}

class _MobileGeneralSettingsScreenState
    extends ConsumerState<MobileGeneralSettingsScreen> {
  final _defaultLanguageCtl = TextEditingController();
  String? _currency;
  bool _requireShiftForSales = false;
  bool _showKhqr = false;
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
    _defaultLanguageCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final general = await ref.read(settingsServiceProvider).getGeneral();
      _defaultLanguageCtl.text = (general['defaultLanguage'] as String?) ?? '';
      _currency = (general['currency'] as String?)?.toUpperCase();
      _requireShiftForSales = general['requireShiftForSales'] as bool? ?? false;
      _showKhqr = general['showKhqr'] as bool? ?? false;
      _loaded = true;
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_currency == null || _currency!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.errorValidation),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final currentFooter =
          ref.read(companyProfileProvider).valueOrNull?['receiptFooter']
              as String? ??
          '';
      await ref.read(settingsServiceProvider).updateGeneral({
        'defaultLanguage': _defaultLanguageCtl.text.trim(),
        'currency': _currency,
        'receiptFooter': currentFooter,
        'showKhqr': _showKhqr,
        'requireShiftForSales': _requireShiftForSales,
      });
      ref.invalidate(currencyCodeProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsSaveGeneral)));
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
    final language = ref.watch(appLanguageProvider);
    final themeModeNotifier = ref.watch(themeModeProvider);
    final currentMainColor = ref.watch(mainColorProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsGeneral)),
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
                  l10n.settingsLanguage,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: PosTheme.spacingSm),
                SegmentedButton<AppLanguage>(
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
                  selected: {language},
                  onSelectionChanged: (s) => ref
                      .read(appLanguageProvider.notifier)
                      .setLanguage(s.first),
                ),
                const SizedBox(height: PosTheme.spacingLg),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsDarkMode),
                  value: themeModeNotifier.value == ThemeMode.dark,
                  onChanged: (_) => themeModeNotifier.toggle(),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.palette_outlined, size: 20),
                  title: Text(l10n.settingsMainColor),
                  subtitle: Wrap(
                    spacing: PosTheme.spacingSm,
                    runSpacing: PosTheme.spacingSm,
                    children: kMainColorOptions.map((color) {
                      final selected =
                          color.toARGB32() == currentMainColor.toARGB32();
                      return Semantics(
                        button: true,
                        selected: selected,
                        label: _mainColorLabel(l10n, color),
                        child: GestureDetector(
                          onTap: () => ref
                              .read(mainColorProvider.notifier)
                              .setMainColor(color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                              border: selected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.6),
                                        blurRadius: 4,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(height: PosTheme.spacingXl),
                TextField(
                  controller: _defaultLanguageCtl,
                  decoration: InputDecoration(
                    labelText: l10n.settingsDefaultLanguage,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: InputDecoration(
                    labelText: l10n.settingsCurrencies,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in {'USD', 'KHR', _currency}.whereType<String>())
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _currency = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsRequireShiftForSales),
                  value: _requireShiftForSales,
                  onChanged: (v) => setState(() => _requireShiftForSales = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsShowKhqrOnReceipts),
                  value: _showKhqr,
                  onChanged: (v) => setState(() => _showKhqr = v),
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
