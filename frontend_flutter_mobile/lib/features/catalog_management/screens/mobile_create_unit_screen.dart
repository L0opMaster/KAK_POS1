import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/unit_models.dart';
import '../../pos/providers/unit_provider.dart';

/// Create/edit a unit of measure.
///
/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// unit_management_screen.dart`'s `_UnitFormScreen` — same fields, same
/// validation, same save payload shape. Desktop's dialog-like form screen
/// becomes a scrollable full-screen form here (source: `ListView` body,
/// mirrored) following this app's `mobile_create_supplier_screen.dart`
/// save/error-handling flow (`FilledButton`, loading state, `SnackBar`,
/// `Navigator.pop(true)` on success) instead of desktop's AppBar text
/// button.
class MobileCreateUnitScreen extends ConsumerStatefulWidget {
  const MobileCreateUnitScreen({super.key, this.initialUnit, this.allUnits = const []});

  final Unit? initialUnit;

  /// Every currently-loaded unit, so the "base unit" picker can offer
  /// existing units in the same [Unit.baseUnitGroup] without a second fetch.
  final List<Unit> allUnits;

  @override
  ConsumerState<MobileCreateUnitScreen> createState() =>
      _MobileCreateUnitScreenState();
}

class _MobileCreateUnitScreenState
    extends ConsumerState<MobileCreateUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtl;
  late final TextEditingController _nameEnCtl;
  late final TextEditingController _nameKmCtl;
  late final TextEditingController _symbolCtl;
  late final TextEditingController _groupCtl;
  late final TextEditingController _factorCtl;
  bool _isBaseUnit = true;
  int? _baseUnitId;
  bool _active = true;
  bool _saving = false;

  bool get _isEditing => widget.initialUnit != null;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUnit;
    _codeCtl = TextEditingController(text: u?.code ?? '');
    _nameEnCtl = TextEditingController(text: u?.nameEn ?? '');
    _nameKmCtl = TextEditingController(text: u?.nameKm ?? '');
    _symbolCtl = TextEditingController(text: u?.symbol ?? '');
    _groupCtl = TextEditingController(text: u?.baseUnitGroup ?? '');
    _factorCtl =
        TextEditingController(text: u == null ? '1' : '${u.conversionFactor}');
    _isBaseUnit = u?.baseUnit ?? true;
    _baseUnitId = u?.baseUnitId;
    _active = u?.active ?? true;
    _groupCtl.addListener(() => setState(() {})); // re-filter base-unit picker
  }

  @override
  void dispose() {
    _codeCtl.dispose();
    _nameEnCtl.dispose();
    _nameKmCtl.dispose();
    _symbolCtl.dispose();
    _groupCtl.dispose();
    _factorCtl.dispose();
    super.dispose();
  }

  /// Other units in the same base-unit group this unit could convert
  /// against — excludes itself (a unit can't be its own base).
  List<Unit> get _candidateBaseUnits {
    final group = _groupCtl.text.trim();
    if (group.isEmpty) return const [];
    return widget.allUnits
        .where((u) => u.baseUnitGroup == group && u.id != widget.initialUnit?.id)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    if (!_isBaseUnit && _baseUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.unitManagementPickBaseUnitError),
        backgroundColor: PosTheme.errorRed,
      ));
      return;
    }
    setState(() => _saving = true);
    final data = {
      'code': _codeCtl.text.trim(),
      'nameEn': _nameEnCtl.text.trim(),
      'nameKm': _nameKmCtl.text.trim().isEmpty
          ? _nameEnCtl.text.trim()
          : _nameKmCtl.text.trim(),
      'name': _nameEnCtl.text.trim(),
      'symbol': _symbolCtl.text.trim(),
      'baseUnitGroup': _groupCtl.text.trim(),
      'baseUnit': _isBaseUnit,
      'baseUnitId': _isBaseUnit ? null : _baseUnitId,
      'conversionFactor':
          _isBaseUnit ? 1 : double.parse(_factorCtl.text.trim()),
      'active': _active,
    };

    try {
      if (_isEditing) {
        await ref
            .read(unitProvider.notifier)
            .updateUnit(widget.initialUnit!.id, data);
      } else {
        await ref.read(unitProvider.notifier).createUnit(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEditing
            ? '"${data['nameEn']}" ${l10n.unitManagementUpdatedSuffix}'
            : '"${data['nameEn']}" ${l10n.unitManagementCreatedSuffix}'),
        backgroundColor: PosTheme.successGreen,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${l10n.unitManagementSaveFailedPrefix}: ${e is ApiException ? e.message : e}'),
        backgroundColor: PosTheme.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final candidates = _candidateBaseUnits;
    // If the previously-selected base unit fell out of the candidate list
    // (group changed), clear the stale selection rather than submit it.
    if (_baseUnitId != null && !candidates.any((u) => u.id == _baseUnitId)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _baseUnitId = null));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.unitManagementEditTitle : l10n.unitManagementNewTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          children: [
            TextFormField(
              controller: _codeCtl,
              decoration: InputDecoration(
                labelText: '${l10n.unitManagementCodeLabel} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _symbolCtl,
              decoration: InputDecoration(
                labelText: '${l10n.unitManagementSymbolLabel} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
              onChanged: (_) => setState(() {}), // refreshes factor helper text
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _nameEnCtl,
              decoration: InputDecoration(
                labelText: '${l10n.formNameEn} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _nameKmCtl,
              decoration: InputDecoration(
                labelText: l10n.formNameKm,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: _groupCtl,
              decoration: InputDecoration(
                labelText: '${l10n.unitManagementGroupLabel} *',
                helperText: l10n.unitManagementGroupHelper,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.commonRequired : null,
            ),
            const SizedBox(height: PosTheme.spacingLg),
            SwitchListTile(
              value: _isBaseUnit,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.unitManagementBaseUnitLabel),
              subtitle: Text(l10n.unitManagementBaseUnitSubtitle),
              onChanged: (v) => setState(() {
                _isBaseUnit = v;
                if (v) {
                  _baseUnitId = null;
                  _factorCtl.text = '1';
                }
              }),
            ),
            if (!_isBaseUnit) ...[
              const SizedBox(height: PosTheme.spacingSm),
              DropdownButtonFormField<int>(
                initialValue: candidates.any((u) => u.id == _baseUnitId)
                    ? _baseUnitId
                    : null,
                decoration: InputDecoration(
                  labelText: '${l10n.unitManagementBaseUnitPickerLabel} *',
                  border: const OutlineInputBorder(),
                  helperText: candidates.isEmpty
                      ? l10n.unitManagementNoCandidatesHelper
                      : null,
                ),
                items: candidates
                    .map((u) => DropdownMenuItem(
                          value: u.id,
                          child: Text('${u.nameEn} (${u.symbol})'),
                        ))
                    .toList(),
                onChanged: candidates.isEmpty
                    ? null
                    : (v) => setState(() => _baseUnitId = v),
              ),
              const SizedBox(height: PosTheme.spacingMd),
              TextFormField(
                controller: _factorCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${l10n.unitManagementConversionFactorLabel} *',
                  helperText: l10n.unitManagementConversionFactorHelper(
                      _symbolCtl.text.isEmpty ? '?' : _symbolCtl.text),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return l10n.formInvalidValue;
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: PosTheme.spacingSm),
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.commonActive),
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
