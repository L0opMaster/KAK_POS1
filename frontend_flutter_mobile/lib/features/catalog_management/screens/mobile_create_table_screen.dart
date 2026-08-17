import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/table_models.dart';
import '../../pos/providers/table_provider.dart';

const List<String> _kStatuses = [
  'AVAILABLE',
  'OCCUPIED',
  'RESERVED',
  'OUT_OF_ORDER',
];

/// Create/edit form for a physical restaurant table (admin CRUD). Ported
/// business logic from `frontend-flutter-pos/lib/features/pos/screens/
/// create_table.dart`: Table Number is required and locked once editing
/// (the backend's `TableUpdateRequest` has no `tableNumber` field — table
/// numbers are immutable after creation), Capacity is required and must be
/// a positive integer, Display Name/Section/Notes are optional free text,
/// and the Status dropdown + Active switch are shown ONLY when editing —
/// new tables always start `AVAILABLE` + active server-side, matching
/// `TableCreateRequest` having no status field at all.
///
/// Mirrors `mobile_create_supplier_screen.dart`'s save/error-handling flow
/// (`FilledButton`, loading state, `SnackBar`, `Navigator.pop(true)` on
/// success) rather than desktop's AppBar-action Save button + fixed-width
/// `ListView` form.
class MobileCreateTableScreen extends ConsumerStatefulWidget {
  const MobileCreateTableScreen({super.key, this.initialTable});

  final RestaurantTable? initialTable;

  @override
  ConsumerState<MobileCreateTableScreen> createState() =>
      _MobileCreateTableScreenState();
}

class _MobileCreateTableScreenState
    extends ConsumerState<MobileCreateTableScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _tableNumberCtl;
  late final TextEditingController _displayNameCtl;
  late final TextEditingController _capacityCtl;
  late final TextEditingController _sectionCtl;
  late final TextEditingController _notesCtl;

  late String _status;
  late bool _isActive;
  bool _saving = false;

  bool get _isEditing => widget.initialTable != null;

  @override
  void initState() {
    super.initState();
    final table = widget.initialTable;
    _tableNumberCtl = TextEditingController(text: table?.tableNumber ?? '');
    _displayNameCtl = TextEditingController(text: table?.displayName ?? '');
    _capacityCtl =
        TextEditingController(text: (table?.capacity ?? 4).toString());
    _sectionCtl = TextEditingController(text: table?.section ?? '');
    _notesCtl = TextEditingController(text: table?.notes ?? '');
    _status = (table != null && _kStatuses.contains(table.status))
        ? table.status
        : _kStatuses.first;
    _isActive = table?.isActive ?? true;
  }

  @override
  void dispose() {
    _tableNumberCtl.dispose();
    _displayNameCtl.dispose();
    _capacityCtl.dispose();
    _sectionCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final l10n = context.l10n;
    final capacity = int.tryParse(_capacityCtl.text.trim()) ?? 4;

    try {
      if (_isEditing) {
        final request = TableUpdateRequest(
          displayName: _displayNameCtl.text.trim().isEmpty
              ? null
              : _displayNameCtl.text.trim(),
          capacity: capacity,
          section:
              _sectionCtl.text.trim().isEmpty ? null : _sectionCtl.text.trim(),
          notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
          status: _status,
          isActive: _isActive,
        );
        await ref
            .read(tableProvider.notifier)
            .update(widget.initialTable!.id, request);
      } else {
        final request = TableCreateRequest(
          tableNumber: _tableNumberCtl.text.trim(),
          displayName: _displayNameCtl.text.trim().isEmpty
              ? null
              : _displayNameCtl.text.trim(),
          capacity: capacity,
          section:
              _sectionCtl.text.trim().isEmpty ? null : _sectionCtl.text.trim(),
          notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        );
        await ref.read(tableProvider.notifier).create(request);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? l10n.createTableUpdatedMessage
                : l10n.createTableCreatedMessage,
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
          content: Text('${l10n.createTableSaveFailedPrefix}: $e'),
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
          _isEditing ? l10n.createTableEditTitle : l10n.createTableNewTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          children: [
            TextFormField(
              controller: _tableNumberCtl,
              enabled: !_isEditing,
              decoration: InputDecoration(
                labelText: l10n.createTableNumberLabel,
                hintText: l10n.createTableNumberHint,
                border: const OutlineInputBorder(),
                helperText:
                    _isEditing ? l10n.createTableNumberLockedHint : null,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _displayNameCtl,
              decoration: InputDecoration(
                labelText: l10n.createTableDisplayNameLabel,
                hintText: l10n.createTableDisplayNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _capacityCtl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.createTableCapacityLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final value = int.tryParse((v ?? '').trim());
                if (value == null) return l10n.createTableInvalidNumberError;
                if (value <= 0) return l10n.createTableMinCapacityError;
                return null;
              },
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _sectionCtl,
              decoration: InputDecoration(
                labelText: l10n.createTableSectionLabel,
                hintText: l10n.createTableSectionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: PosTheme.spacingMd),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: l10n.createTableStatusLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final status in _kStatuses)
                    DropdownMenuItem(
                      value: status,
                      child: Text(status.replaceAll('_', ' ')),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                title: Text(l10n.commonActive),
                subtitle: Text(l10n.createTableActiveSubtitle),
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _notesCtl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.createTableNotesLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? l10n.createTableSavingLabel
                    : (_isEditing
                        ? l10n.createTableSaveChangesLabel
                        : l10n.createTableCreateButtonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
