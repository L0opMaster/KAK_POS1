import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/modifier_models.dart';
import '../../pos/providers/modifier_provider.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// create_modifier.dart` — BUSINESS LOGIC/VALIDATION is COPY/ADAPT NEARLY
/// EXACTLY: one "Group Name" field sent as both `nameEn`/`nameKm` (backend
/// requires a nonblank `nameKm` and there's no separate Khmer-name input
/// here, matching source's documented stopgap), option rows require a
/// name + a price delta (>= 0, 2-decimal), minimum one option is enforced,
/// unsaved-changes snapshot diff guards the back button, and the
/// create/update/delete request-building exactly matches
/// `ModifierNotifier`. The desktop card-with-max-width-650 layout is
/// MOBILE UI REIMPLEMENT: a single scrollable `ListView` with
/// full-width, stacked option rows sized for touch instead of a
/// two-column desktop form.
class MobileCreateModifierScreen extends ConsumerStatefulWidget {
  final ModifierGroupResponse? initialModifier;

  const MobileCreateModifierScreen({super.key, this.initialModifier});

  bool get isEditing => initialModifier != null;

  @override
  ConsumerState<MobileCreateModifierScreen> createState() =>
      _MobileCreateModifierScreenState();
}

class _MobileCreateModifierScreenState
    extends ConsumerState<MobileCreateModifierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();

  final List<_OptionControllers> _options = [];
  final List<int> _deletedOptionIds = [];

  late String _initialSnapshot;
  bool _allowPop = false;
  bool _isRequired = false;
  bool _multiSelect = false;

  @override
  void initState() {
    super.initState();

    final modifier = widget.initialModifier;

    if (modifier == null) {
      _options.add(_OptionControllers());
    } else {
      _nameCtl.text = modifier.nameEn;
      _isRequired = modifier.isRequired;
      _multiSelect = modifier.multiSelect;

      if (modifier.options.isEmpty) {
        _options.add(_OptionControllers());
      } else {
        for (final option in modifier.options) {
          _options.add(
            _OptionControllers(
              id: option.id,
              name: option.nameEn,
              price: _formatPrice(option.priceDelta),
            ),
          );
        }
      }
    }

    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    for (final option in _options) {
      option.dispose();
    }
    super.dispose();
  }

  String _formatPrice(double price) {
    if (price == price.truncateToDouble()) {
      return price.toInt().toString();
    }
    return price.toString();
  }

  String _snapshot() {
    return jsonEncode({
      'name': _nameCtl.text,
      'required': _isRequired,
      'multiSelect': _multiSelect,
      'options': _options
          .map(
            (o) => {
              'id': o.id,
              'name': o.nameCtl.text,
              'price': o.priceCtl.text,
            },
          )
          .toList(),
      'deletedOptionIds': _deletedOptionIds,
    });
  }

  bool get _hasUnsavedChanges => _snapshot() != _initialSnapshot;

  void _addOption() {
    setState(() => _options.add(_OptionControllers()));
  }

  void _removeOption(int index) {
    final l10n = context.l10n;

    if (_options.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createModifierMinOneOptionError)),
      );
      return;
    }

    final removed = _options.removeAt(index);
    if (removed.id != null) {
      _deletedOptionIds.add(removed.id!);
    }
    removed.dispose();

    setState(() {});
  }

  Future<void> _requestClose() async {
    if (!_hasUnsavedChanges) {
      _closePage();
      return;
    }

    final l10n = context.l10n;

    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.dialogUnsavedChangesTitle),
          content: Text(l10n.createModifierDiscardChangesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.createModifierContinueEditingButton),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: PosTheme.errorRed),
              child: Text(l10n.createModifierDiscardChangesButton),
            ),
          ],
        );
      },
    );

    if (discard == true) {
      _closePage();
    }
  }

  void _closePage([bool? result]) {
    if (!mounted) return;

    setState(() => _allowPop = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  Future<void> _save() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final l10n = context.l10n;
    final name = _nameCtl.text.trim();

    final groupRequest = ModifierGroupRequest(
      nameEn: name,

      // Backend requires nameKm to be nonblank.
      // Replace this with a Khmer controller when needed.
      nameKm: name,

      isRequired: _isRequired,
      multiSelect: _multiSelect,
      active: true,
      displayOrder: widget.initialModifier?.displayOrder ?? 0,
    );

    try {
      if (widget.isEditing) {
        final upserts = List.generate(_options.length, (index) {
          final option = _options[index];
          final optionName = option.nameCtl.text.trim();

          return ModifierOptionUpsert(
            id: option.id,
            request: ModifierOptionRequest(
              nameEn: optionName,
              nameKm: optionName,
              priceDelta: double.tryParse(option.priceCtl.text.trim()) ?? 0,
              active: true,
              displayOrder: index,
            ),
          );
        });

        await ref.read(modifierProvider.notifier).updateModifier(
              groupId: widget.initialModifier!.id,
              groupRequest: groupRequest,
              optionUpserts: upserts,
              deletedOptionIds: _deletedOptionIds,
            );
      } else {
        final requests = List.generate(_options.length, (index) {
          final option = _options[index];
          final optionName = option.nameCtl.text.trim();

          return ModifierOptionRequest(
            nameEn: optionName,
            nameKm: optionName,
            priceDelta: double.tryParse(option.priceCtl.text.trim()) ?? 0,
            active: true,
            displayOrder: index,
          );
        });

        await ref.read(modifierProvider.notifier).createModifier(
              groupRequest: groupRequest,
              optionRequests: requests,
            );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? l10n.createModifierUpdatedMessage
                : l10n.createModifierCreatedMessage,
          ),
        ),
      );

      _closePage(true);
    } catch (_) {
      if (!mounted) return;

      final error = ref.read(modifierProvider).error ??
          l10n.createModifierSaveFailedFallback;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: PosTheme.errorRed),
      );
    }
  }

  Future<void> _delete() async {
    final modifier = widget.initialModifier;
    if (modifier == null) return;

    final l10n = context.l10n;
    final lang = ref.read(appLanguageProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.createModifierDeleteTitle),
          content: Text(
            '${l10n.createModifierDeleteConfirmPrefix} '
            '"${modifier.localizedName(lang)}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref.read(modifierProvider.notifier).deleteModifier(modifier.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createModifierDeletedMessage)),
      );

      _closePage(true);
    } catch (_) {
      if (!mounted) return;

      final error = ref.read(modifierProvider).error ??
          l10n.createModifierDeleteFailedFallback;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: PosTheme.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(modifierProvider);

    return PopScope<bool>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing
                ? l10n.createModifierEditTitle
                : l10n.createModifierCreateTitle,
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
                  labelText: l10n.createModifierNameLabel,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.createModifierNameRequiredError
                    : null,
              ),
              const SizedBox(height: PosTheme.spacingLg),
              Text(
                l10n.modifierManagementSectionHeader,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: PosTheme.spacingSm),
              ...List.generate(
                _options.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: PosTheme.spacingMd),
                  child: _buildOptionRow(index),
                ),
              ),
              OutlinedButton.icon(
                onPressed: state.isSaving ? null : _addOption,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(l10n.createModifierAddOptionButton),
              ),
              const SizedBox(height: PosTheme.spacingMd),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.commonRequired),
                subtitle: Text(l10n.createModifierRequiredSubtitle),
                value: _isRequired,
                onChanged: state.isSaving
                    ? null
                    : (v) => setState(() => _isRequired = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.createModifierMultiSelectTitle),
                subtitle: Text(l10n.createModifierMultiSelectSubtitle),
                value: _multiSelect,
                onChanged: state.isSaving
                    ? null
                    : (v) => setState(() => _multiSelect = v),
              ),
              const SizedBox(height: PosTheme.spacingXl),
              if (widget.isEditing) ...[
                OutlinedButton.icon(
                  onPressed: state.isDeleting || state.isSaving ? null : _delete,
                  style: OutlinedButton.styleFrom(foregroundColor: PosTheme.errorRed),
                  icon: state.isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  label: Text(l10n.commonDelete),
                ),
                const SizedBox(height: PosTheme.spacingMd),
              ],
              FilledButton(
                onPressed: state.isSaving ? null : _save,
                child: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
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
      ),
    );
  }

  Widget _buildOptionRow(int index) {
    final option = _options[index];
    final l10n = context.l10n;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${l10n.createModifierOptionNameLabel} ${index + 1}',
                    style: TextStyle(
                      fontSize: PosTheme.fontSizeXs,
                      color: PosTheme.textSecondaryOf(context),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.createModifierDeleteOptionTooltip,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeOption(index),
                ),
              ],
            ),
            TextFormField(
              controller: option.nameCtl,
              decoration: InputDecoration(
                labelText: l10n.createModifierOptionNameLabel,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? l10n.createModifierOptionNameRequiredError
                  : null,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextFormField(
              controller: option.priceCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: l10n.formPrice,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return l10n.createModifierPriceRequiredError;
                }
                final price = double.tryParse(v.trim());
                if (price == null) {
                  return l10n.createModifierInvalidPriceError;
                }
                if (price < 0) {
                  return l10n.createModifierNegativePriceError;
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionControllers {
  final int? id;
  final TextEditingController nameCtl;
  final TextEditingController priceCtl;

  _OptionControllers({this.id, String name = '', String price = '0'})
      : nameCtl = TextEditingController(text: name),
        priceCtl = TextEditingController(text: price);

  void dispose() {
    nameCtl.dispose();
    priceCtl.dispose();
  }
}
