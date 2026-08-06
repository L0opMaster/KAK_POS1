import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../models/modifier_models.dart';
import '../models/product_models.dart';

/// Loyverse-style bottom sheet for customizing a product before adding to cart.
/// Shows product details, modifier group selection, quantity stepper, and
/// note field.
///
/// Pass [initialItem] (an existing cart line for this same product) to open
/// the sheet in "edit" mode instead: fields are pre-filled from it, the
/// returned [CartItem] carries over its `id`/`addedAt`, and the caller should
/// apply the result back onto that same line instead of adding a new one.
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
    setState(() {
      _selections[groupId] = {optionId};
    });
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

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final lineTotal = (product.price + _selectedDelta) * _qty;
    final lang = ref.watch(appLanguageProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: PosTheme.primaryGreenLight,
                      borderRadius:
                          BorderRadius.circular(PosTheme.radiusMedium),
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(PosTheme.radiusMedium),
                            child: Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2,
                                  color: PosTheme.primaryGreen,
                                  size: 28),
                            ),
                          )
                        : const Icon(Icons.inventory_2,
                            color: PosTheme.primaryGreen, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.localizedName(lang),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: PosTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: PosTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Modifier groups ──
              if (product.modifierGroups.isNotEmpty) ...[
                ...product.modifierGroups.map(_buildGroupSection),
              ],

              // ── Quantity stepper ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l10n.modifierSheetQuantity,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: PosTheme.textPrimaryOf(context))),
                  Row(
                    children: [
                      _qtyButton(Icons.remove, _qty > 1, () {
                        setState(() => _qty--);
                      }),
                      Container(
                        width: 48,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('$_qty',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 18)),
                      ),
                      _qtyButton(Icons.add, true, () {
                        setState(() => _qty++);
                      }),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Note field ──
              TextField(
                controller: _noteCtl,
                decoration: InputDecoration(
                  hintText: context.l10n.modifierSheetNoteHint,
                  prefixIcon: const Icon(Icons.notes, size: 20),
                  filled: true,
                  fillColor: PosTheme.backgroundPageOf(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),

              if (_showValidation && !_isValid) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: PosTheme.errorRed),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.modifierSheetValidationError,
                        style: const TextStyle(
                            fontSize: 12, color: PosTheme.errorRed),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),

              // ── Line total + Add button ──
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l10n.modifierSheetLineTotal,
                            style: TextStyle(
                                fontSize: 12,
                                color: PosTheme.textSecondaryOf(context))),
                        Text('\$${lineTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: PosTheme.textPrimaryOf(context))),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_shopping_cart, size: 20),
                      label: Text(
                          widget.initialItem != null
                              ? context.l10n.modifierSheetUpdate
                              : '${context.l10n.commonAdd} $_qty',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      onPressed: () {
                        if (!_isValid) {
                          setState(() => _showValidation = true);
                          return;
                        }
                        final initial = widget.initialItem;
                        final cartItem = CartItem(
                          id: initial?.id ??
                              DateTime.now().microsecondsSinceEpoch.toString(),
                          product: product,
                          qty: _qty,
                          addedAt: initial?.addedAt ??
                              DateTime.now().millisecondsSinceEpoch,
                          note: _noteCtl.text.trim().isEmpty
                              ? null
                              : _noteCtl.text.trim(),
                          discountAmount: initial?.discountAmount,
                          selectedModifiers: _selectedModifiers,
                        );
                        Navigator.of(context).pop(cartItem);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PosTheme.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusMedium),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSection(ModifierGroupResponse group) {
    final selectedIds = _selections[group.id] ?? const <int>{};
    final lang = ref.watch(appLanguageProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.localizedName(lang),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
              if (group.isRequired) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: PosTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.commonRequired,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: PosTheme.errorRed),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 6),
                Text(
                  context.l10n.commonOptional,
                  style: TextStyle(
                      fontSize: 11, color: PosTheme.textHintOf(context)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: PosTheme.backgroundPageOf(context),
              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            ),
            child: Column(
              children: group.options.map((option) {
                final label = option.localizedName(lang);
                final priceLabel = option.priceDelta == 0
                    ? ''
                    : (option.priceDelta > 0
                        ? '+\$${option.priceDelta.toStringAsFixed(2)}'
                        : '-\$${option.priceDelta.abs().toStringAsFixed(2)}');
                if (group.multiSelect) {
                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: PosTheme.primaryGreen,
                    value: selectedIds.contains(option.id),
                    onChanged: (checked) => _toggleMultiSelect(
                        group.id, option.id, checked ?? false),
                    title: Text(label,
                        style: const TextStyle(fontSize: 14)),
                    secondary: priceLabel.isEmpty
                        ? null
                        : Text(priceLabel,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: PosTheme.textSecondaryOf(context))),
                  );
                }
                return RadioListTile<int>(
                  dense: true,
                  activeColor: PosTheme.primaryGreen,
                  value: option.id,
                  groupValue:
                      selectedIds.isEmpty ? null : selectedIds.first,
                  onChanged: (value) {
                    if (value != null) {
                      _toggleSingleSelect(group.id, value);
                    }
                  },
                  title: Text(label, style: const TextStyle(fontSize: 14)),
                  secondary: priceLabel.isEmpty
                      ? null
                      : Text(priceLabel,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PosTheme.textSecondaryOf(context))),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, bool enabled, VoidCallback onTap) {
    return Material(
      color: enabled ? PosTheme.primaryGreenLight : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(icon,
              size: 18,
              color: enabled
                  ? PosTheme.primaryGreen
                  : PosTheme.textHintOf(context)),
        ),
      ),
    );
  }
}
