import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/core/utils/l10n_extensions.dart';
import 'package:frontend_flutter_pos/features/inventory/models/inventory_models.dart';
import 'package:frontend_flutter_pos/features/inventory/providers/inventory_provider.dart';

const List<String> _currencies = ['KHR', 'USD'];

class CreateSupplier extends ConsumerStatefulWidget {
  final Supplier? initialSupplier;

  const CreateSupplier({super.key, this.initialSupplier});

  @override
  ConsumerState<CreateSupplier> createState() => _CreateSupplierState();
}

class _CreateSupplierState extends ConsumerState<CreateSupplier> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtl = TextEditingController();
  final _contactPersonCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _paymentTermsCtl = TextEditingController();
  final _leadTimeCtl = TextEditingController();
  final _taxIdCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  String _currency = _currencies.first;
  bool _active = true;
  bool _saving = false;

  bool get _isEditing => widget.initialSupplier != null;

  @override
  void initState() {
    super.initState();
    final supplier = widget.initialSupplier;
    if (supplier != null) {
      _nameCtl.text = supplier.name;
      _contactPersonCtl.text = supplier.contactPerson ?? '';
      _phoneCtl.text = supplier.phone ?? '';
      _emailCtl.text = supplier.email ?? '';
      _addressCtl.text = supplier.address ?? '';
      _paymentTermsCtl.text = supplier.paymentTerms ?? '';
      _leadTimeCtl.text = supplier.leadTimeDays?.toString() ?? '';
      _taxIdCtl.text = supplier.taxId ?? '';
      _notesCtl.text = supplier.notes ?? '';
      _currency =
          _currencies.contains(supplier.defaultCurrency) ? supplier.defaultCurrency : _currency;
      _active = supplier.active;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _contactPersonCtl.dispose();
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final supplier = Supplier(
        id: widget.initialSupplier?.id,
        name: _nameCtl.text.trim(),
        contactPerson: _contactPersonCtl.text.trim().isEmpty
            ? null
            : _contactPersonCtl.text.trim(),
        phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        address:
            _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
        paymentTerms: _paymentTermsCtl.text.trim().isEmpty
            ? null
            : _paymentTermsCtl.text.trim(),
        leadTimeDays: int.tryParse(_leadTimeCtl.text.trim()),
        taxId: _taxIdCtl.text.trim().isEmpty ? null : _taxIdCtl.text.trim(),
        defaultCurrency: _currency,
        active: _active,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );

      if (_isEditing) {
        await ref.read(suppliersProvider.notifier).updateSupplier(supplier);
      } else {
        await ref.read(suppliersProvider.notifier).createSupplier(supplier);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? context.l10n.createSupplierUpdated : context.l10n.createSupplierCreated),
          backgroundColor: PosTheme.successGreen,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.inventoryFailedToSave('$e')),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.l10n.createSupplierEditTitle : context.l10n.createSupplierNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createSupplierNameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? context.l10n.commonRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactPersonCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createSupplierContactPerson,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.formPhone,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _emailCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.formEmail,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formAddress,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _paymentTermsCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.createSupplierPaymentTerms,
                      hintText: context.l10n.createSupplierPaymentTermsHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _leadTimeCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.createSupplierLeadTime,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _taxIdCtl,
                    decoration: InputDecoration(
                      labelText: context.l10n.createSupplierTaxId,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: InputDecoration(
                      labelText: context.l10n.createSupplierDefaultCurrency,
                      border: const OutlineInputBorder(),
                    ),
                    items: _currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setState(() => _currency = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtl,
              decoration: InputDecoration(
                labelText: context.l10n.inventoryNotesLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.commonActive),
              subtitle: Text(context.l10n.createSupplierActiveSubtitle),
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving
                    ? context.l10n.createSupplierSaving
                    : (_isEditing ? context.l10n.createSupplierSaveChanges : context.l10n.createSupplierCreateButton)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
