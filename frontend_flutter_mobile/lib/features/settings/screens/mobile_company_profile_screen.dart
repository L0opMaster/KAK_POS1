import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/services/settings_service.dart';

/// Ported from the Company Profile card in `frontend-flutter-pos/lib/
/// features/pos/screens/settings_modules_screen.dart` — COPY/ADAPT NEARLY
/// EXACTLY for validation (`businessName` required) and the save payload
/// shape. `receiptFooter` differs deliberately from source: desktop reads
/// it from a `TextEditingController` SHARED with the General card on the
/// same long scroll (both cards' save handlers send whatever's currently
/// in that one field) — an accident of both cards sharing one scrollable
/// form, not a real design decision worth reproducing across two separate
/// mobile screens. Here, `receiptFooter` is this screen's own field (a
/// receipt/business-identity value fits Company Profile more naturally
/// than General); `mobile_general_settings_screen.dart`'s save instead
/// re-sends the last-known `receiptFooter` from `companyProfileProvider`
/// unchanged, so saving General can never silently blank it out.
class MobileCompanyProfileScreen extends ConsumerStatefulWidget {
  const MobileCompanyProfileScreen({super.key});

  @override
  ConsumerState<MobileCompanyProfileScreen> createState() =>
      _MobileCompanyProfileScreenState();
}

class _MobileCompanyProfileScreenState
    extends ConsumerState<MobileCompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _websiteCtl = TextEditingController();
  final _footerCtl = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtl.dispose();
    _addressCtl.dispose();
    _phoneCtl.dispose();
    _websiteCtl.dispose();
    _footerCtl.dispose();
    super.dispose();
  }

  void _populate(Map<String, dynamic> company) {
    if (_loaded) return;
    _loaded = true;
    _nameCtl.text = (company['businessName'] as String?) ?? '';
    _addressCtl.text = (company['address'] as String?) ?? '';
    _phoneCtl.text = (company['phone'] as String?) ?? '';
    _websiteCtl.text = (company['website'] as String?) ?? '';
    _footerCtl.text = (company['receiptFooter'] as String?) ?? '';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      await ref.read(settingsServiceProvider).updateCompanyProfile({
        'businessName': _nameCtl.text.trim(),
        'address': _addressCtl.text.trim(),
        'phone': _phoneCtl.text.trim(),
        'website': _websiteCtl.text.trim(),
        'receiptFooter': _footerCtl.text.trim(),
      });
      ref.invalidate(companyProfileProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.settingsSaveCompany)));
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
    final companyAsync = ref.watch(companyProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCompanyProfile)),
      body: companyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (company) {
          _populate(company);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              children: [
                TextFormField(
                  controller: _nameCtl,
                  decoration: InputDecoration(
                    labelText: l10n.formName,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.formPleaseEnterValue
                      : null,
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextFormField(
                  controller: _addressCtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.formAddress,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextFormField(
                  controller: _phoneCtl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: l10n.formPhone,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextFormField(
                  controller: _websiteCtl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: l10n.formWebsite,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextFormField(
                  controller: _footerCtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.settingsReceiptFooter,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingLg),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(l10n.commonSave),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
