import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/customer_models.dart';
import '../../pos/providers/customer_provider.dart';

/// Create/edit form for a customer (admin CRUD). Single screen serves both
/// — `initialCustomer == null` means create. Ported business logic from
/// `frontend-flutter-pos/lib/features/pos/screens/customer_management_
/// screen.dart`'s `CustomerFormScreen`: desktop exposes a single "Name"
/// field that maps to BOTH `nameEn` and `displayName` (no separate
/// nameEn/displayName/nameKm inputs), Credit Limit defaults to `'0'` and is
/// parsed leniently (`double.tryParse(...) ?? 0`, no validator — garbage
/// silently becomes 0), and `type`/`status` are always hardcoded
/// `'WALK_IN'`/`'ACTIVE'` (not user-editable on this form).
///
/// Mirrors `mobile_create_table_screen.dart`'s save/error-handling flow
/// (`FilledButton`, loading state, `SnackBar`, `Navigator.pop(true)` on
/// success) rather than desktop's AppBar-action Save button + fixed-width
/// `ListView` form.
class MobileCreateCustomerScreen extends ConsumerStatefulWidget {
  const MobileCreateCustomerScreen({super.key, this.initialCustomer});

  final Customer? initialCustomer;

  @override
  ConsumerState<MobileCreateCustomerScreen> createState() =>
      _MobileCreateCustomerScreenState();
}

class _MobileCreateCustomerScreenState
    extends ConsumerState<MobileCreateCustomerScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _creditCtl;
  late final TextEditingController _notesCtl;

  bool _saving = false;

  bool get _isEditing => widget.initialCustomer != null;

  @override
  void initState() {
    super.initState();
    final c = widget.initialCustomer;
    _nameCtl = TextEditingController(
      text: c?.displayName.isNotEmpty == true ? c!.displayName : c?.nameEn ?? '',
    );
    _phoneCtl = TextEditingController(text: c?.phone ?? '');
    _emailCtl = TextEditingController(text: c?.email ?? '');
    _addressCtl = TextEditingController(text: c?.address ?? '');
    _creditCtl = TextEditingController(
      text: c != null ? c.creditLimit.toStringAsFixed(2) : '0',
    );
    _notesCtl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _addressCtl.dispose();
    _creditCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final l10n = context.l10n;

    try {
      final request = CreateCustomerRequest(
        nameEn: _nameCtl.text.trim(),
        displayName: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        address:
            _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        type: 'WALK_IN',
        status: 'ACTIVE',
        creditLimit: double.tryParse(_creditCtl.text.trim()) ?? 0,
      );

      if (_isEditing) {
        await ref
            .read(customerProvider.notifier)
            .update(widget.initialCustomer!.id, request);
      } else {
        await ref.read(customerProvider.notifier).create(request);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? l10n.customerManagementUpdatedMessage
                : l10n.customerManagementCreatedMessage,
          ),
          backgroundColor: PosTheme.successGreen,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.customerManagementSaveFailedPrefix}: $e'),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? l10n.customerManagementEditTitle
              : l10n.customerManagementNewTitle,
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
                labelText: l10n.customerManagementNameLabel,
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _phoneCtl,
              decoration: InputDecoration(
                labelText: l10n.formPhone,
                hintText: '+855 12 345 678',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _emailCtl,
              decoration: InputDecoration(
                labelText: l10n.formEmail,
                hintText: 'customer@example.com',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _addressCtl,
              decoration: InputDecoration(
                labelText: l10n.formAddress,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _creditCtl,
              decoration: InputDecoration(
                labelText: l10n.customerManagementCreditLimitLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _notesCtl,
              decoration: InputDecoration(
                labelText: l10n.customerManagementNotesLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? l10n.customerManagementSavingLabel
                    : (_isEditing
                        ? l10n.customerManagementUpdateButtonLabel
                        : l10n.customerManagementCreateButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
