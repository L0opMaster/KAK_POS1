import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import 'held_tickets_picker_sheet.dart';
import 'product_modifier_sheet.dart';
import 'qty_stepper.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// cart_items_list.dart` — ADAPTED. Business behavior (swipe-to-delete +
/// undo, tap-to-edit qty/note/discount, icon-based remove/modifier actions
/// with tooltips — the CURRENT source shape, per this task's "IMPORTANT
/// RECENT CHANGES" list: Remove/Modifier are icons, not text) is preserved
/// exactly, including the exact callback targets
/// (`notifier.removeItem`/`setItemQuantity`/`setItemNote`/
/// `setItemDiscount`/`setItemModifiers`/`addItem` for undo). The dense
/// 5-column desktop row (qty badge | description | qty number | unit price
/// | line total, each in a fixed-width `SizedBox`) is replaced with a
/// 2-line card (name+details on top, price+total right-aligned; controls
/// below) — fixed pixel-width columns don't survive a phone's narrower
/// viewport. The empty-cart state's "Open Held Tickets" button opens
/// `held_tickets_picker_sheet.dart`'s bottom sheet instead of source's
/// `HeldTicketsDialog` — same restore-a-held-ticket purpose, phone-shaped
/// presentation.
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
    final cur = watchCurrency(ref);
    final lang = ref.watch(appLanguageProvider);

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_shopping_cart_outlined,
                size: 48, color: PosTheme.textHintOf(context)),
            const SizedBox(height: PosTheme.spacingMd),
            Text(context.l10n.posEmptyCart,
                style: TextStyle(
                    color: PosTheme.textSecondaryOf(context), fontSize: 15)),
            const SizedBox(height: PosTheme.spacingXs),
            Text(context.l10n.cartItemsListTapToAdd,
                style: TextStyle(
                    color: PosTheme.textHintOf(context), fontSize: 13)),
            const SizedBox(height: PosTheme.spacingLg),
            OutlinedButton.icon(
              onPressed: () => showHeldTicketsPickerSheet(context, ref),
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(context.l10n.cartItemsListOpenHeldTickets),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(PosTheme.spacingMd),
      itemCount: items.length,
      itemBuilder: (context, index) => _CartItemCard(
        item: items[index],
        notifier: notifier,
        currency: cur,
        lang: lang,
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.notifier,
    required this.currency,
    required this.lang,
  });

  final CartItem item;
  final dynamic notifier;
  final String currency;
  final AppLanguage lang;

  Future<void> _editModifiers(BuildContext context) async {
    final result = await showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(PosTheme.radiusLarge)),
      ),
      builder: (_) =>
          ProductModifierSheet(product: item.product, initialItem: item),
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            ctx.l10n.cartItemsListEditItemTitle(item.product.localizedName(lang))),
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
            const SizedBox(height: PosTheme.spacingMd),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: ctx.l10n.cartItemsListNoteLabel,
                hintText: ctx.l10n.cartItemsListNoteHint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: PosTheme.spacingMd),
            TextField(
              controller: discountCtl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                notifier.setItemQuantity(item.id, newQty).then((result) {
                  if (!result.ok && context.mounted) {
                    _showBlockedSnackBar(context, result);
                  }
                });
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
        margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
        decoration: BoxDecoration(
            color: PosTheme.errorRed,
            borderRadius: BorderRadius.circular(PosTheme.radiusMedium)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) {
        final removed = item;
        notifier.removeItem(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n
                .cartItemsListRemovedItem(removed.product.localizedName(lang))),
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
          margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          decoration: BoxDecoration(
            color: PosTheme.backgroundCardOf(context),
            borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            border: Border.all(color: PosTheme.borderColorOf(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.product.localizedName(lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 15),
                              ),
                            ),
                            if (lowStock)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
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
                        if (item.modifierPriceDelta != 0)
                          Text(
                            context.l10n.cartItemsListBaseModifierBreakdown(
                              formatAmount(item.product.price, currency),
                              formatAmount(item.modifierPriceDelta, currency),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: PosTheme.textHintOf(context)),
                          ),
                        if (item.modifierSummaryText.isNotEmpty)
                          Text(
                            item.modifierSummaryText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11, color: PosTheme.textHintOf(context)),
                          ),
                        if (hasNote)
                          Text(
                            item.note!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: PosTheme.textSecondaryOf(context),
                                fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: PosTheme.spacingSm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatAmount(lineTotal, currency),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      Text(
                        '${formatAmount(item.unitPrice, currency)} x ${item.qty}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: PosTheme.textHintOf(context)),
                      ),
                      if ((item.discountAmount ?? 0) > 0)
                        Text(
                          '-${formatAmount(item.discountAmount! * item.qty, currency)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: PosTheme.warningAmber),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: PosTheme.spacingSm),
              Row(
                children: [
                  QtyStepper(
                    quantity: item.qty,
                    onIncrement: () async {
                      final result = await notifier.setItemQuantity(
                          item.id, item.qty + 1);
                      if (!result.ok && context.mounted) {
                        _showBlockedSnackBar(context, result);
                      }
                    },
                    onDecrement: () {
                      if (item.qty > 1) {
                        notifier.setItemQuantity(item.id, item.qty - 1);
                      }
                    },
                  ),
                  if (item.product.modifierGroups.isNotEmpty) ...[
                    const SizedBox(width: PosTheme.spacingSm),
                    Tooltip(
                      message: context.l10n.cartItemsListModifierLink,
                      child: InkWell(
                        onTap: () => _editModifiers(context),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.tune,
                              size: 18, color: PosTheme.primaryGreen),
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Tooltip(
                    message: context.l10n.cartRemove,
                    child: InkWell(
                      onTap: () => notifier.removeItem(item.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.delete_outline,
                            size: 18, color: PosTheme.errorRed),
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
}

/// Shows the "Only N available" (or inactive/not-sellable) message for a
/// [CartMutationResult]-shaped block from `CartNotifier.setItemQuantity` —
/// [result] is `dynamic` (this widget accepts a `dynamic notifier` so tests
/// can supply a fake) but always duck-types to `.ok`/`.message`/
/// `.stockCapAvailableQty` at runtime, matching `CartMutationResult`.
void _showBlockedSnackBar(BuildContext context, dynamic result) {
  final String text = result.stockCapAvailableQty != null
      ? context.l10n.cartOnlyStockAvailable(result.stockCapAvailableQty)
      : ((result.message as String?) ?? '');
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
