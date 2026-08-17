import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/category_provider.dart';

/// Create/edit form for a category.
///
/// Ported functionality from `frontend-flutter-pos/lib/features/pos/
/// screens/category_management_screen.dart`'s `_CategoryFormScreen` — same
/// payload shape (`{'nameEn', 'nameKm', 'active'}`, blank Name (KM) falls
/// back to Name (EN) before sending) and the same create-vs-update branch
/// on whether [initialCategory] is null. Save/error-handling flow mirrors
/// `mobile_create_supplier_screen.dart` exactly (Form + `FilledButton`,
/// `_saving` guard, SnackBar feedback, `Navigator.pop(true)` on success).
///
/// Source's color swatch picker is dropped (MOBILE UI REIMPLEMENT) — color
/// is purely cosmetic and never sent to the API, so the list screen simply
/// derives it from the category id and this form doesn't need to collect
/// it at all.
class MobileCreateCategoryScreen extends ConsumerStatefulWidget {
  const MobileCreateCategoryScreen({super.key, this.initialCategory});

  final Category? initialCategory;

  @override
  ConsumerState<MobileCreateCategoryScreen> createState() =>
      _MobileCreateCategoryScreenState();
}

class _MobileCreateCategoryScreenState
    extends ConsumerState<MobileCreateCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEnCtl;
  late final TextEditingController _nameKmCtl;
  late bool _active;
  bool _saving = false;

  bool get _isEditing => widget.initialCategory != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.initialCategory;
    _nameEnCtl = TextEditingController(text: cat?.nameEn ?? '');
    _nameKmCtl = TextEditingController(text: cat?.nameKm ?? '');
    _active = cat?.active ?? true;
  }

  @override
  void dispose() {
    _nameEnCtl.dispose();
    _nameKmCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final l10n = context.l10n;

    final nameEn = _nameEnCtl.text.trim();
    final nameKm = _nameKmCtl.text.trim();
    final data = {
      'nameEn': nameEn,
      'nameKm': nameKm.isEmpty ? nameEn : nameKm,
      'active': _active,
    };

    try {
      if (_isEditing) {
        await ref
            .read(categoriesProvider.notifier)
            .updateCategory(widget.initialCategory!.id, data);
      } else {
        await ref.read(categoriesProvider.notifier).createCategory(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? '"$nameEn" ${l10n.categoryManagementUpdatedSuffix}'
                : '"$nameEn" ${l10n.categoryManagementCreatedSuffix}'),
            backgroundColor: PosTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.categoryManagementSaveFailedPrefix}: $e'),
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
          _isEditing
              ? l10n.categoryManagementEditTitle
              : l10n.categoryManagementNewTitle,
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          children: [
            TextFormField(
              controller: _nameEnCtl,
              decoration: InputDecoration(
                labelText: '${l10n.formNameEn} *',
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
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
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: PosTheme.spacingLg),
            SwitchListTile(
              value: _active,
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.commonActive),
              subtitle: Text(l10n.categoryManagementActiveSubtitle),
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: PosTheme.spacingLg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? l10n.categoryManagementSaving : l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
