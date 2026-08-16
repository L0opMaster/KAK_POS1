import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import '../models/production_models.dart';
import '../providers/production_provider.dart';

class _DraftComponent {
  _DraftComponent() : qtyCtl = TextEditingController(text: '1');
  Product? product;
  final TextEditingController qtyCtl;
}

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// create_recipe.dart` — COPY/ADAPT NEARLY EXACTLY: `name` required
/// non-empty, output product required only when CREATING (locked/
/// read-only once a recipe exists — its output product can't change after
/// creation), output quantity must be `> 0`, component rows missing a
/// product or with qty `<=0` are silently dropped (not errored) — if that
/// leaves zero components, block with
/// `createRecipeAddAtLeastOneComponent`. Product pickers (both output and
/// component) are UNFILTERED, matching source. Editable — unlike
/// suppliers, a recipe's non-output fields can be changed after creation
/// via `.update()`; only `.deactivate()` has no corresponding reactivate
/// path in either project's UI.
class MobileCreateRecipeScreen extends ConsumerStatefulWidget {
  const MobileCreateRecipeScreen({super.key, this.initialRecipe});

  final Recipe? initialRecipe;

  @override
  ConsumerState<MobileCreateRecipeScreen> createState() =>
      _MobileCreateRecipeScreenState();
}

class _MobileCreateRecipeScreenState
    extends ConsumerState<MobileCreateRecipeScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _outputQtyCtl;
  late final TextEditingController _notesCtl;
  Product? _outputProduct;
  late bool _active;
  final List<_DraftComponent> _components = [_DraftComponent()];
  bool _saving = false;

  bool get _isEditing => widget.initialRecipe != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(productsProvider.notifier).loadProducts());
    final r = widget.initialRecipe;
    _nameCtl = TextEditingController(text: r?.name ?? '');
    _outputQtyCtl = TextEditingController(
      text: r != null ? r.outputQuantity.toStringAsFixed(0) : '1',
    );
    _notesCtl = TextEditingController(text: r?.notes ?? '');
    _active = r?.active ?? true;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _outputQtyCtl.dispose();
    _notesCtl.dispose();
    for (final c in _components) {
      c.qtyCtl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_nameCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createRecipeEnterName),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    if (!_isEditing && _outputProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createRecipeSelectOutputProduct),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    final outputQty = double.tryParse(_outputQtyCtl.text);
    if (outputQty == null || outputQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createRecipeEnterValidQuantity),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }
    final lines = _components
        .where((c) {
          final qty = double.tryParse(c.qtyCtl.text);
          return c.product != null && qty != null && qty > 0;
        })
        .map(
          (c) => RecipeLine(
            componentProductId: c.product!.id,
            componentQuantity: double.parse(c.qtyCtl.text),
          ),
        )
        .toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.createRecipeAddAtLeastOneComponent),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final recipe = Recipe(
        id: widget.initialRecipe?.id,
        name: _nameCtl.text.trim(),
        outputProductId:
            widget.initialRecipe?.outputProductId ?? _outputProduct!.id,
        outputQuantity: outputQty,
        active: _active,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        lines: lines,
      );
      if (_isEditing) {
        await ref.read(recipesProvider.notifier).update(recipe);
      } else {
        await ref.read(recipesProvider.notifier).create(recipe);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing ? l10n.createRecipeUpdated : l10n.createRecipeCreated,
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
    final language = ref.watch(appLanguageProvider);
    final products = ref.watch(productsProvider).products;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.createRecipeEditTitle : l10n.createRecipeNewTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        children: [
          TextField(
            controller: _nameCtl,
            decoration: InputDecoration(
              labelText: l10n.createRecipeNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          if (_isEditing)
            InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.createRecipeOutputProductLabel,
                border: const OutlineInputBorder(),
              ),
              child: Text(
                widget.initialRecipe!.outputProductNameEn ??
                    l10n.createRecipeProductNumber(
                      '${widget.initialRecipe!.outputProductId}',
                    ),
              ),
            )
          else
            DropdownButtonFormField<Product>(
              initialValue: _outputProduct,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.createRecipeOutputProductRequiredLabel,
                border: const OutlineInputBorder(),
              ),
              items: [
                for (final p in products)
                  DropdownMenuItem(
                    value: p,
                    child: Text(
                      p.localizedName(language),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _outputProduct = v),
            ),
          const SizedBox(height: PosTheme.spacingMd),
          TextField(
            controller: _outputQtyCtl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration: InputDecoration(
              labelText: l10n.createRecipeOutputQtyLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: PosTheme.spacingMd),
          TextField(
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
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: PosTheme.spacingLg),
          Text(
            l10n.createRecipeComponentsLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: PosTheme.spacingSm),
          for (var i = 0; i < _components.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: PosTheme.spacingSm),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Product>(
                      initialValue: _components[i].product,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.createRecipeComponentLabel,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        for (final p in products)
                          DropdownMenuItem(
                            value: p,
                            child: Text(
                              p.localizedName(language),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _components[i].product = v),
                    ),
                  ),
                  const SizedBox(width: PosTheme.spacingXs),
                  Expanded(
                    child: TextField(
                      controller: _components[i].qtyCtl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.cartQty,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: PosTheme.errorRed,
                    onPressed: _components.length <= 1
                        ? null
                        : () => setState(() {
                            _components[i].qtyCtl.dispose();
                            _components.removeAt(i);
                          }),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () =>
                setState(() => _components.add(_DraftComponent())),
            icon: const Icon(Icons.add),
            label: Text(l10n.createRecipeAddComponent),
          ),
          const SizedBox(height: PosTheme.spacingLg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }
}
