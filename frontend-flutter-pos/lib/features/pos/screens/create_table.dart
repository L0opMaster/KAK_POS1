import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/features/pos/models/table_models.dart';
import 'package:frontend_flutter_pos/features/pos/providers/table_provider.dart';
import '../../../core/utils/l10n_extensions.dart';

const List<String> _statuses = ['AVAILABLE', 'OCCUPIED', 'RESERVED', 'OUT_OF_ORDER'];

class CreateTable extends ConsumerStatefulWidget {
  final RestaurantTable? initialTable;

  const CreateTable({super.key, this.initialTable});

  @override
  ConsumerState<CreateTable> createState() => _CreateTableState();
}

class _CreateTableState extends ConsumerState<CreateTable> {
  final _formKey = GlobalKey<FormState>();

  final _tableNumberCtl = TextEditingController();
  final _displayNameCtl = TextEditingController();
  final _capacityCtl = TextEditingController(text: '4');
  final _sectionCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  String _status = _statuses.first;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEditing => widget.initialTable != null;

  @override
  void initState() {
    super.initState();

    final table = widget.initialTable;

    if (table != null) {
      _tableNumberCtl.text = table.tableNumber;
      _displayNameCtl.text = table.displayName;
      _capacityCtl.text = table.capacity.toString();
      _sectionCtl.text = table.section ?? '';
      _notesCtl.text = table.notes ?? '';
      _status = _statuses.contains(table.status) ? table.status : _status;
      _isActive = table.isActive;
    }
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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);

    try {
      final capacity = int.tryParse(_capacityCtl.text.trim()) ?? 4;

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

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? context.l10n.createTableUpdatedMessage
              : context.l10n.createTableCreatedMessage),
          backgroundColor: PosTheme.successGreen,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.createTableSaveFailedPrefix}: $e'),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing
            ? context.l10n.createTableEditTitle
            : context.l10n.createTableNewTitle),
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
              controller: _tableNumberCtl,
              enabled: !_isEditing,
              decoration: InputDecoration(
                labelText: context.l10n.createTableNumberLabel,
                hintText: context.l10n.createTableNumberHint,
                border: const OutlineInputBorder(),
                helperText: _isEditing
                    ? context.l10n.createTableNumberLockedHint
                    : null,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _displayNameCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createTableDisplayNameLabel,
                hintText: context.l10n.createTableDisplayNameHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _capacityCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createTableCapacityLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                final value = int.tryParse((v ?? '').trim());
                if (value == null) {
                  return context.l10n.createTableInvalidNumberError;
                }
                if (value <= 0) return context.l10n.createTableMinCapacityError;
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sectionCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createTableSectionLabel,
                hintText: context.l10n.createTableSectionHint,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: context.l10n.createTableStatusLabel,
                  border: const OutlineInputBorder(),
                ),
                items: _statuses
                    .map(
                      (status) => DropdownMenuItem(
                        value: status,
                        child: Text(status.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: _isActive,
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.commonActive),
                subtitle: Text(context.l10n.createTableActiveSubtitle),
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtl,
              decoration: InputDecoration(
                labelText: context.l10n.createTableNotesLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
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
                    ? context.l10n.createTableSavingLabel
                    : (_isEditing
                        ? context.l10n.createTableSaveChangesLabel
                        : context.l10n.createTableCreateButtonLabel)),
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
