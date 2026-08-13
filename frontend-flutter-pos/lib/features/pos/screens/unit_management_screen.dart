/// Unit Management — list/add/edit units of measure (kg, g, box, pcs, ...),
/// matching the backend UnitController REST API. Same list/FAB/edit-form
/// shape as CategoryManagementScreen, extended for the fields units have
/// that categories don't: code, symbol, a base-unit-group grouping (e.g.
/// "weight"), and a conversion factor relative to that group's base unit.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/unit_models.dart';
import '../services/unit_service.dart';

class UnitManagementScreen extends ConsumerStatefulWidget {
  const UnitManagementScreen({super.key});

  @override
  ConsumerState<UnitManagementScreen> createState() =>
      _UnitManagementScreenState();
}

class _UnitManagementScreenState extends ConsumerState<UnitManagementScreen> {
  List<Unit> _units = [];
  bool _loading = true;
  String? _error;
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(unitServiceProvider);
      final list = await service.list(query: _searchCtl.text.trim());
      setState(() {
        _units = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e is ApiException ? e.message : e.toString();
      });
    }
  }

  Future<void> _showForm({Unit? unit}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _UnitFormScreen(unit: unit, allUnits: _units),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _toggleActive(Unit unit) async {
    try {
      final service = ref.read(unitServiceProvider);
      await service.updateStatus(unit.id, !unit.active);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${context.l10n.unitManagementUpdateFailedPrefix}: ${e is ApiException ? e.message : e}'),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.posDrawerUnits),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtl,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: context.l10n.commonSearch,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                suffixIcon: _searchCtl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtl.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _body(context)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.unitManagementAddButton),
        backgroundColor: PosTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: PosTheme.errorRed, size: 40),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    if (_units.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.straighten_rounded,
                size: 48, color: PosTheme.textHintOf(context)),
            const SizedBox(height: 12),
            Text(context.l10n.unitManagementEmptyTitle,
                style: const TextStyle(
                    color: PosTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 4),
            Text(context.l10n.unitManagementEmptyHint,
                style:
                    TextStyle(color: PosTheme.textHintOf(context), fontSize: 13)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _units.length,
        itemBuilder: (context, index) {
          final unit = _units[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
              side: BorderSide(
                color: unit.active
                    ? PosTheme.borderColorOf(context)
                    : PosTheme.dividerColorOf(context),
              ),
            ),
            child: ListTile(
              onTap: () => _showForm(unit: unit),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: PosTheme.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                alignment: Alignment.center,
                child: Text(
                  unit.symbol.isEmpty ? '?' : unit.symbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: PosTheme.primaryGreen,
                  ),
                ),
              ),
              title: Text(
                '${unit.nameEn} (${unit.code})',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: unit.active
                      ? PosTheme.textPrimaryOf(context)
                      : PosTheme.textHintOf(context),
                ),
              ),
              subtitle: Text(
                unit.baseUnit
                    ? '${unit.nameKm} · ${context.l10n.unitManagementBaseUnitGroupLabel}: ${unit.baseUnitGroup} · ${context.l10n.unitManagementBaseUnitLabel}'
                    : '${unit.nameKm} · 1 ${unit.symbol} = ${unit.conversionFactor} ${unit.baseUnitCode ?? unit.baseUnitGroup}',
                style: TextStyle(
                  fontSize: 12,
                  color: unit.active
                      ? PosTheme.textSecondaryOf(context)
                      : PosTheme.textHintOf(context),
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!unit.active)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: PosTheme.dividerColorOf(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(context.l10n.commonInactive,
                          style: const TextStyle(
                              fontSize: 10, color: PosTheme.textHint)),
                    ),
                  Switch(
                    value: unit.active,
                    activeColor: PosTheme.primaryGreen,
                    onChanged: (_) => _toggleActive(unit),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Form for creating or editing a unit of measure.
class _UnitFormScreen extends ConsumerStatefulWidget {
  final Unit? unit;

  /// Every currently-loaded unit, so the "base unit" picker can offer
  /// existing units in the same [baseUnitGroup] without a second fetch.
  final List<Unit> allUnits;

  const _UnitFormScreen({this.unit, required this.allUnits});

  @override
  ConsumerState<_UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends ConsumerState<_UnitFormScreen> {
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

  @override
  void initState() {
    super.initState();
    final u = widget.unit;
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
        .where((u) => u.baseUnitGroup == group && u.id != widget.unit?.id)
        .toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isBaseUnit && _baseUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.l10n.unitManagementPickBaseUnitError),
        backgroundColor: PosTheme.errorRed,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final service = ref.read(unitServiceProvider);
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

      if (widget.unit != null) {
        await service.update(widget.unit!.id, data);
      } else {
        await service.create(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.unit != null
            ? '"${data['nameEn']}" ${context.l10n.unitManagementUpdatedSuffix}'
            : '"${data['nameEn']}" ${context.l10n.unitManagementCreatedSuffix}'),
        backgroundColor: PosTheme.successGreen,
      ));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${context.l10n.unitManagementSaveFailedPrefix}: ${e is ApiException ? e.message : e}'),
        backgroundColor: PosTheme.errorRed,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.unit != null;
    final candidates = _candidateBaseUnits;
    // If the previously-selected base unit fell out of the candidate list
    // (group changed), clear the stale selection rather than submit it.
    if (_baseUnitId != null && !candidates.any((u) => u.id == _baseUnitId)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _baseUnitId = null));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? context.l10n.unitManagementEditTitle
            : context.l10n.unitManagementNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonSave,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _codeCtl,
                    decoration: InputDecoration(
                      labelText: '${context.l10n.unitManagementCodeLabel} *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.commonRequired
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _symbolCtl,
                    decoration: InputDecoration(
                      labelText: '${context.l10n.unitManagementSymbolLabel} *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.commonRequired
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameEnCtl,
              decoration: InputDecoration(
                labelText: '${context.l10n.formNameEn} *',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameKmCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formNameKm,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _groupCtl,
              decoration: InputDecoration(
                labelText: '${context.l10n.unitManagementGroupLabel} *',
                helperText: context.l10n.unitManagementGroupHelper,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isBaseUnit,
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.unitManagementBaseUnitLabel),
              subtitle: Text(context.l10n.unitManagementBaseUnitSubtitle),
              onChanged: (v) => setState(() {
                _isBaseUnit = v;
                if (v) {
                  _baseUnitId = null;
                  _factorCtl.text = '1';
                }
              }),
            ),
            if (!_isBaseUnit) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                initialValue: candidates.any((u) => u.id == _baseUnitId)
                    ? _baseUnitId
                    : null,
                decoration: InputDecoration(
                  labelText: '${context.l10n.unitManagementBaseUnitPickerLabel} *',
                  border: const OutlineInputBorder(),
                  helperText: candidates.isEmpty
                      ? context.l10n.unitManagementNoCandidatesHelper
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
              const SizedBox(height: 12),
              TextFormField(
                controller: _factorCtl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${context.l10n.unitManagementConversionFactorLabel} *',
                  helperText: context.l10n.unitManagementConversionFactorHelper(
                      _symbolCtl.text.isEmpty ? '?' : _symbolCtl.text),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final parsed = double.tryParse((v ?? '').trim());
                  if (parsed == null || parsed <= 0) {
                    return context.l10n.formInvalidValue;
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 16),
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.commonActive),
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
        ),
      ),
    );
  }
}
