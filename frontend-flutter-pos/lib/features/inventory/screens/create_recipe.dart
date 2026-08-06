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
  Product? product;
  final TextEditingController qtyCtl = TextEditingController(text: '1');
}

class CreateRecipe extends ConsumerStatefulWidget {
  final Recipe? initialRecipe;

  const CreateRecipe({super.key, this.initialRecipe});

  @override
  ConsumerState<CreateRecipe> createState() => _CreateRecipeState();
}

class _CreateRecipeState extends ConsumerState<CreateRecipe> {
  final _nameCtl = TextEditingController();
  final _outputQtyCtl = TextEditingController(text: '1');
  final _notesCtl = TextEditingController();
  Product? _outputProduct;
  bool _active = true;
  final List<_DraftComponent> _components = [_DraftComponent()];
  bool _saving = false;

  bool get _isEditing => widget.initialRecipe != null;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(productsProvider.notifier).loadProducts());

    final recipe = widget.initialRecipe;
    if (recipe != null) {
      _nameCtl.text = recipe.name;
      _outputQtyCtl.text = recipe.outputQuantity.toString();
      _notesCtl.text = recipe.notes ?? '';
      _active = recipe.active;
      if (recipe.lines.isNotEmpty) {
        _components.clear();
        for (final line in recipe.lines) {
          final comp = _DraftComponent();
          comp.qtyCtl.text = line.componentQuantity.toString();
          _components.add(comp);
        }
      }
    }
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

  void _addComponent() => setState(() => _components.add(_DraftComponent()));

  void _removeComponent(int index) {
    setState(() {
      _components[index].qtyCtl.dispose();
      _components.removeAt(index);
    });
  }

  Future<void> _save() async {
    final outputQty = double.tryParse(_outputQtyCtl.text.trim());
    if (_nameCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createRecipeEnterName), backgroundColor: PosTheme.errorRed),
      );
      return;
    }
    if (!_isEditing && _outputProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createRecipeSelectOutputProduct), backgroundColor: PosTheme.errorRed),
      );
      return;
    }
    if (outputQty == null || outputQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createRecipeEnterValidQuantity), backgroundColor: PosTheme.errorRed),
      );
      return;
    }

    final lines = <RecipeLine>[];
    for (final c in _components) {
      final qty = double.tryParse(c.qtyCtl.text.trim());
      if (c.product == null || qty == null || qty <= 0) continue;
      lines.add(RecipeLine(componentProductId: c.product!.id, componentQuantity: qty));
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.createRecipeAddAtLeastOneComponent), backgroundColor: PosTheme.errorRed),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final recipe = Recipe(
        id: widget.initialRecipe?.id,
        name: _nameCtl.text.trim(),
        outputProductId: _outputProduct?.id ?? widget.initialRecipe!.outputProductId,
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_isEditing ? context.l10n.createRecipeUpdated : context.l10n.createRecipeCreated),
            backgroundColor: PosTheme.successGreen),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.inventoryFailedToSave('$e')), backgroundColor: PosTheme.errorRed),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider).products;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.l10n.createRecipeEditTitle : context.l10n.createRecipeNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.l10n.commonSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameCtl,
            decoration: InputDecoration(labelText: context.l10n.createRecipeNameLabel, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          if (_isEditing)
            InputDecorator(
              decoration: InputDecoration(labelText: context.l10n.createRecipeOutputProductLabel, border: const OutlineInputBorder()),
              child: Text(widget.initialRecipe!.outputProductNameEn ?? context.l10n.createRecipeProductNumber('${widget.initialRecipe!.outputProductId}')),
            )
          else
            DropdownButtonFormField<Product>(
              initialValue: _outputProduct,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.l10n.createRecipeOutputProductRequiredLabel, border: const OutlineInputBorder()),
              items: products
                  .map((p) => DropdownMenuItem(
                      value: p, child: Text(p.localizedName(lang), overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _outputProduct = v),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _outputQtyCtl,
            decoration: InputDecoration(labelText: context.l10n.createRecipeOutputQtyLabel, border: const OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesCtl,
            decoration: InputDecoration(labelText: context.l10n.inventoryNotesLabel, border: const OutlineInputBorder()),
            maxLines: 2,
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            value: _active,
            contentPadding: EdgeInsets.zero,
            title: Text(context.l10n.commonActive),
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(context.l10n.createRecipeComponentsLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              TextButton.icon(
                onPressed: _addComponent,
                icon: const Icon(Icons.add, size: 18),
                label: Text(context.l10n.createRecipeAddComponent),
              ),
            ],
          ),
          const Divider(),
          for (int i = 0; i < _components.length; i++) _buildComponentRow(i, products, lang),
        ],
      ),
    );
  }

  Widget _buildComponentRow(int index, List<Product> products, AppLanguage lang) {
    final comp = _components[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<Product>(
              initialValue: comp.product,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.l10n.createRecipeComponentLabel, border: const OutlineInputBorder(), isDense: true),
              items: products
                  .map((p) => DropdownMenuItem(
                      value: p, child: Text(p.localizedName(lang), overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (value) => setState(() => comp.product = value),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: comp.qtyCtl,
              decoration: InputDecoration(labelText: context.l10n.cartQty, border: const OutlineInputBorder(), isDense: true),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: PosTheme.errorRed),
            onPressed: _components.length > 1 ? () => _removeComponent(index) : null,
          ),
        ],
      ),
    );
  }
}
