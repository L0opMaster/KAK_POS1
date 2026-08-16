import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';

const List<String> _kSupplierCurrencies = ['KHR', 'USD'];

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// create_supplier.dart` — COPY/ADAPT NEARLY EXACTLY: `name` is the only
/// validated field (`Form`/`GlobalKey<FormState>`); every other field
/// (contact/phone/email/address/paymentTerms/leadTimeDays/taxId/notes) has
/// no validator, matching source exactly. `leadTimeDays` silently becomes
/// `null` on unparsable input. `defaultCurrency` is constrained to
/// `['KHR', 'USD']`, falling back to `'KHR'` if an existing supplier's
/// value isn't one of those two. `active` (switch) has no separate Save
/// step — it's part of the same form submit as everything else, unlike
/// Settings' Main Color swatch (Day 19).
class MobileCreateSupplierScreen extends ConsumerStatefulWidget {
  const MobileCreateSupplierScreen({super.key, this.initialSupplier});

  final Supplier? initialSupplier;

  @override
  ConsumerState<MobileCreateSupplierScreen> createState() =>
      _MobileCreateSupplierScreenState();
}

class _MobileCreateSupplierScreenState
    extends ConsumerState<MobileCreateSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _contactCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _paymentTermsCtl;
  late final TextEditingController _leadTimeCtl;
  late final TextEditingController _taxIdCtl;
  late final TextEditingController _notesCtl;
  late String _currency;
  late bool _active;
  bool _saving = false;

  bool get _isEditing => widget.initialSupplier != null;

  @override
  void initState() {
    super.initState();
    final s = widget.initialSupplier;
    _nameCtl = TextEditingController(text: s?.name ?? '');
    _contactCtl = TextEditingController(text: s?.contactPerson ?? '');
    _phoneCtl = TextEditingController(text: s?.phone ?? '');
    _emailCtl = TextEditingController(text: s?.email ?? '');
    _addressCtl = TextEditingController(text: s?.address ?? '');
    _paymentTermsCtl = TextEditingController(text: s?.paymentTerms ?? '');
    _leadTimeCtl = TextEditingController(
      text: s?.leadTimeDays?.toString() ?? '',
    );
    _taxIdCtl = TextEditingController(text: s?.taxId ?? '');
    _notesCtl = TextEditingController(text: s?.notes ?? '');
    _currency = _kSupplierCurrencies.contains(s?.defaultCurrency)
        ? s!.defaultCurrency
        : 'KHR';
    _active = s?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _contactCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _addressCtl.dispose();
    _paymentTermsCtl.dispose();
    _leadTimeCtl.dispose();
    _taxIdCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = context.l10n;
    final supplier = Supplier(
      id: widget.initialSupplier?.id,
      name: _nameCtl.text.trim(),
      contactPerson: _contactCtl.text.trim().isEmpty
          ? null
          : _contactCtl.text.trim(),
      phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
      email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
      address: _addressCtl.text.trim().isEmpty
          ? null
          : _addressCtl.text.trim(),
      paymentTerms: _paymentTermsCtl.text.trim().isEmpty
          ? null
          : _paymentTermsCtl.text.trim(),
      leadTimeDays: int.tryParse(_leadTimeCtl.text.trim()),
      taxId: _taxIdCtl.text.trim().isEmpty ? null : _taxIdCtl.text.trim(),
      defaultCurrency: _currency,
      active: _active,
      notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
    );
    try {
      if (_isEditing) {
        await ref.read(suppliersProvider.notifier).updateSupplier(supplier);
      } else {
        await ref.read(suppliersProvider.notifier).createSupplier(supplier);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? l10n.createSupplierUpdated : l10n.createSupplierCreated,
            ),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.inventoryFailedToSave('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.createSupplierEditTitle : l10n.createSupplierNewTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          children: [
            TextFormField(
              controller: _nameCtl,
              decoration: InputDecoration(
                labelText: l10n.createSupplierNameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _contactCtl,
              decoration: InputDecoration(
                labelText: l10n.createSupplierContactPerson,
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
              controller: _emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.formEmail,
                border: const OutlineInputBorder(),
              ),
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
              controller: _paymentTermsCtl,
              decoration: InputDecoration(
                labelText: l10n.createSupplierPaymentTerms,
                hintText: l10n.createSupplierPaymentTermsHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _leadTimeCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.createSupplierLeadTime,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _taxIdCtl,
              decoration: InputDecoration(
                labelText: l10n.createSupplierTaxId,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: InputDecoration(
                labelText: l10n.createSupplierDefaultCurrency,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final c in _kSupplierCurrencies)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _notesCtl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.inventoryNotesLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.commonActive),
              subtitle: Text(l10n.createSupplierActiveSubtitle),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? l10n.createSupplierSaving
                    : (_isEditing
                          ? l10n.createSupplierSaveChanges
                          : l10n.createSupplierCreateButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
