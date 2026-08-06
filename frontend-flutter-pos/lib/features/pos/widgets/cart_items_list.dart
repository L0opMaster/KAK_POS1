import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import 'held_tickets_dialog.dart';
import 'product_modifier_sheet.dart';
import 'qty_stepper.dart';

/// Cart items list — card-style tiles with swipe-to-delete, tap-to-edit.
class CartItemsList extends ConsumerWidget {
  const CartItemsList({
    required this.items,
    required this.notifier,
    super.key,
  });

  final List<CartItem> items;
  final dynamic notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = readCurrency(ref);
    final lang = ref.watch(appLanguageProvider);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_shopping_cart_outlined,
                size: 48, color: PosTheme.textHintOf(context)),
            const SizedBox(height: 12),
            Text(context.l10n.posEmptyCart,
                style: TextStyle(
                    color: PosTheme.textSecondaryOf(context), fontSize: 15)),
            const SizedBox(height: 4),
            Text(context.l10n.cartItemsListTapToAdd,
                style: TextStyle(
                    color: PosTheme.textHintOf(context), fontSize: 13)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.history, size: 18),
              label: Text(context.l10n.cartItemsListOpenHeldTickets),
              onPressed: () => showDialog<void>(
                  context: context, builder: (_) => const HeldTicketsDialog()),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // ── Column header row (Loyverse-style) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: PosTheme.backgroundPageOf(context),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const SizedBox(width: 32),
              Expanded(
                flex: 3,
                child: Text(context.l10n.cartItemsListDescriptionHeader,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PosTheme.textHintOf(context))),
              ),
              SizedBox(
                width: 50,
                child: Text(context.l10n.cartQty.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PosTheme.textHintOf(context))),
              ),
              SizedBox(
                width: 60,
                child: Text(context.l10n.cartPrice,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PosTheme.textHintOf(context))),
              ),
              SizedBox(width: 12),
              SizedBox(
                width: 70,
                child: Text(context.l10n.receiptAmount,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PosTheme.textHintOf(context))),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            itemCount: items.length,
            itemBuilder: (_, index) => _CartItemCard(
                item: items[index],
                notifier: notifier,
                currency: cur,
                lang: lang),
          ),
        ),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard(
      {required this.item,
      required this.notifier,
      required this.currency,
      required this.lang});
  final CartItem item;
  final dynamic notifier;
  final String currency;
  final AppLanguage lang;

  Future<void> _editModifiers(BuildContext context) async {
    final result = await showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosTheme.radiusLarge)),
      ),
      builder: (_) => ProductModifierSheet(product: item.product, initialItem: item),
    );
    if (result != null) {
      notifier.setItemModifiers(
        item.id,
        selectedModifiers: result.selectedModifiers,
        qty: result.qty,
        note: result.note,
      );
    }
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: item.qty.toString());
    final noteController = TextEditingController(text: item.note ?? '');
    final discountCtl = TextEditingController(
        text: (item.discountAmount ?? 0).toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n
            .cartItemsListEditItemTitle(item.product.localizedName(lang))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: ctx.l10n.cartItemsListQuantityLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: ctx.l10n.cartItemsListNoteLabel,
                hintText: ctx.l10n.cartItemsListNoteHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: discountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: ctx.l10n.cartItemsListDiscountPerUnitLabel,
                hintText: ctx.l10n.cartItemsListMaxDiscountHint(
                    formatAmount(item.product.price, currency)),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              final newQty = int.tryParse(controller.text.trim());
              if (newQty != null && newQty > 0) {
                notifier.setItemQuantity(item.id, newQty);
              }
              final newNote = noteController.text.trim();
              if (newNote != (item.note ?? '')) {
                notifier.setItemNote(item.id, newNote.isEmpty ? null : newNote);
              }
              final disc = double.tryParse(discountCtl.text.trim());
              if (disc != null && disc >= 0) {
                notifier.setItemDiscount(item.id, disc);
              }
              Navigator.of(ctx).pop();
            },
            child: Text(ctx.l10n.commonSave),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lineTotal = item.lineTotal;
    final hasNote = item.note != null && item.note!.isNotEmpty;
    final lowStock = item.product.trackInventory && item.product.stock <= 3;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: PosTheme.errorRed, borderRadius: BorderRadius.circular(10)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        final removed = item;
        notifier.removeItem(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.cartItemsListRemovedItem(
                removed.product.localizedName(lang))),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
                label: context.l10n.cartItemsListUndoAction,
                onPressed: () => notifier.addItem(removed)),
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showEditDialog(context),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: Offset(0, 2))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: QTY badge | Description (flex 3) | QTY | Price | Amount
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // QTY badge
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: PosTheme.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.qty}',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: PosTheme.primaryGreen),
                      ),
                    ),
                    SizedBox(width: 10),
                    // Description
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.product.localizedName(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                              ),
                              if (lowStock)
                                Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    item.product.stock == 0
                                        ? Icons.error
                                        : Icons.warning_amber_rounded,
                                    color: item.product.stock == 0
                                        ? PosTheme.errorRed
                                        : PosTheme.warningAmber,
                                    size: 14,
                                  ),
                                ),
                            ],
                          ),
                          // Show the modifier's own price before the
                          // combined unit price in the Price column, so
                          // it's clear what the modifier actually added.
                          if (item.modifierPriceDelta != 0)
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                context.l10n.cartItemsListBaseModifierBreakdown(
                                  formatAmount(item.product.price, currency),
                                  formatAmount(
                                      item.modifierPriceDelta, currency),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: PosTheme.textHintOf(context)),
                              ),
                            ),
                          if (item.modifierSummaryText.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                item.modifierSummaryText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: PosTheme.textHintOf(context)),
                              ),
                            ),
                          if (hasNote)
                            Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                item.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: PosTheme.textSecondaryOf(context),
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4),
                    // QTY (numeric)
                    SizedBox(
                      width: 50,
                      child: Text(
                        '${item.qty}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
                    // Price (unit price, including modifier surcharges)
                    SizedBox(
                      width: 60,
                      child: Text(
                        formatAmount(item.unitPrice, currency),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            fontSize: 13, color: PosTheme.textSecondaryOf(context)),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Amount (line total) + optional discount
                    SizedBox(
                      width: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatAmount(lineTotal, currency),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          if ((item.discountAmount ?? 0) > 0)
                            Text(
                              '-${formatAmount(item.discountAmount! * item.qty, currency)}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: PosTheme.warningAmber,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    QtyStepper(
                      quantity: item.qty,
                      onIncrement: () =>
                          notifier.setItemQuantity(item.id, item.qty + 1),
                      onDecrement: () {
                        if (item.qty > 1)
                          notifier.setItemQuantity(item.id, item.qty - 1);
                      },
                    ),
                    if (item.product.modifierGroups.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => _editModifiers(context),
                        child: Text(context.l10n.cartItemsListModifierLink,
                            style: TextStyle(
                                fontSize: 12,
                                color: PosTheme.primaryGreen,
                                decoration: TextDecoration.underline)),
                      ),
                      SizedBox(width: 16),
                    ],
                    Spacer(),
                    GestureDetector(
                      onTap: () => notifier.removeItem(item.id),
                      child: Text(context.l10n.cartRemove,
                          style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.errorRed,
                              decoration: TextDecoration.underline)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
