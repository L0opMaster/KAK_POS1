import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../models/product_models.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// product_modifier_sheet.dart` — ADAPTED, not a byte-for-byte port. The
/// STATE/VALIDATION/RESULT-BUILDING logic (`_selections` map, single vs.
/// multi-select toggling, per-group required-option validation,
/// `_selectedDelta`/`_selectedModifiers` derivations, and the exact
/// `CartItem` shape returned via `Navigator.pop`) is byte-identical to
/// source — that's the part callers (`setItemModifiers`/`addItem`) depend
/// on, and a mobile UI restyle must not change it. The VISUAL layout
/// (spacing, animation, exact typography) was simplified for a
/// bottom-sheet-on-a-phone context rather than reproducing every desktop
/// pixel value — see DAY_07.md section 10.
class ProductModifierSheet extends ConsumerStatefulWidget {
  final Product product;
  final CartItem? initialItem;

  const ProductModifierSheet({super.key, required this.product, this.initialItem});

  @override
  ConsumerState<ProductModifierSheet> createState() =>
      _ProductModifierSheetState();
}

class _ProductModifierSheetState extends ConsumerState<ProductModifierSheet> {
  int _qty = 1;
  final TextEditingController _noteCtl = TextEditingController();

  /// groupId -> set of selected optionIds.
  final Map<int, Set<int>> _selections = {};
  bool _showValidation = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialItem;
    if (initial != null) {
      _qty = initial.qty;
      _noteCtl.text = initial.note ?? '';
      for (final m in initial.selectedModifiers) {
        _selections.putIfAbsent(m.groupId, () => <int>{}).add(m.optionId);
      }
    }
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  double get _selectedDelta {
    double total = 0;
    for (final group in widget.product.modifierGroups) {
      final selectedIds = _selections[group.id] ?? const <int>{};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          total += option.priceDelta;
        }
      }
    }
    return total;
  }

  bool get _isValid {
    for (final group in widget.product.modifierGroups) {
      if (group.isRequired) {
        final selectedIds = _selections[group.id] ?? const <int>{};
        if (selectedIds.isEmpty) return false;
      }
    }
    return true;
  }

  List<SelectedModifier> get _selectedModifiers {
    final lang = ref.read(appLanguageProvider);
    final List<SelectedModifier> result = [];
    for (final group in widget.product.modifierGroups) {
      final selectedIds = _selections[group.id] ?? const <int>{};
      for (final option in group.options) {
        if (selectedIds.contains(option.id)) {
          result.add(SelectedModifier(
            groupId: group.id,
            groupName: group.localizedName(lang),
            optionId: option.id,
            optionName: option.localizedName(lang),
            priceDelta: option.priceDelta,
          ));
        }
      }
    }
    return result;
  }

  void _toggleSingleSelect(int groupId, int optionId) {
    setState(() => _selections[groupId] = {optionId});
  }

  void _toggleMultiSelect(int groupId, int optionId, bool selected) {
    setState(() {
      final set = _selections.putIfAbsent(groupId, () => <int>{});
      if (selected) {
        set.add(optionId);
      } else {
        set.remove(optionId);
      }
    });
  }

  void _confirm() {
    if (!_isValid) {
      setState(() => _showValidation = true);
      return;
    }
    final initial = widget.initialItem;
    final cartItem = CartItem(
      id: initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      product: widget.product,
      qty: _qty,
      addedAt: initial?.addedAt ?? DateTime.now().millisecondsSinceEpoch,
      note: _noteCtl.text.trim().isEmpty ? null : _noteCtl.text.trim(),
      discountAmount: initial?.discountAmount,
      selectedModifiers: _selectedModifiers,
    );
    Navigator.of(context).pop(cartItem);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final lang = ref.watch(appLanguageProvider);
    final l10n = context.l10n;
    final lineTotal = (product.price + _selectedDelta) * _qty;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              PosTheme.spacingLg, PosTheme.spacingLg, PosTheme.spacingLg, PosTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.localizedName(lang),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PosTheme.spacingMd),
              for (final group in product.modifierGroups) ...[
                _GroupHeader(
                  title: group.localizedName(lang),
                  isRequired: group.isRequired,
                  showError: _showValidation &&
                      group.isRequired &&
                      (_selections[group.id]?.isEmpty ?? true),
                ),
                for (final option in group.options)
                  group.multiSelect
                      ? CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _selections[group.id]?.contains(option.id) ??
                              false,
                          onChanged: (v) => _toggleMultiSelect(
                              group.id, option.id, v ?? false),
                          title: Text(option.localizedName(lang)),
                          secondary: option.priceDelta != 0
                              ? Text(
                                  '+${option.priceDelta.toStringAsFixed(2)}')
                              : null,
                        )
                      : RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: option.id,
                          groupValue: _selections[group.id]?.isNotEmpty ==
                                  true
                              ? _selections[group.id]!.first
                              : null,
                          onChanged: (v) =>
                              _toggleSingleSelect(group.id, option.id),
                          title: Text(option.localizedName(lang)),
                          secondary: option.priceDelta != 0
                              ? Text(
                                  '+${option.priceDelta.toStringAsFixed(2)}')
                              : null,
                        ),
                const SizedBox(height: PosTheme.spacingSm),
              ],
              Row(
                children: [
                  Text(l10n.modifierSheetQuantity),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed:
                        _qty > 1 ? () => setState(() => _qty--) : null,
                  ),
                  Text('$_qty', style: const TextStyle(fontSize: 16)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _qty++),
                  ),
                ],
              ),
              TextField(
                controller: _noteCtl,
                decoration: InputDecoration(
                  labelText: l10n.cartItemsListNoteLabel,
                  hintText: l10n.modifierSheetNoteHint,
                ),
              ),
              const SizedBox(height: PosTheme.spacingMd),
              if (_showValidation && !_isValid)
                Padding(
                  padding: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                  child: Text(
                    l10n.modifierSheetValidationError,
                    style: TextStyle(color: PosTheme.errorRed),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.modifierSheetLineTotal,
                      style: TextStyle(color: PosTheme.textSecondaryOf(context))),
                  Text('\$${lineTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: PosTheme.spacingMd),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  label: Text(widget.initialItem != null
                      ? l10n.modifierSheetUpdate
                      : '${l10n.commonAdd} $_qty'),
                  onPressed: _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(
      {required this.title, required this.isRequired, required this.showError});

  final String title;
  final bool isRequired;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: PosTheme.spacingSm),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          if (isRequired) ...[
            const SizedBox(width: 6),
            Text('*',
                style: TextStyle(
                    color: showError
                        ? PosTheme.errorRed
                        : PosTheme.textHintOf(context),
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}
