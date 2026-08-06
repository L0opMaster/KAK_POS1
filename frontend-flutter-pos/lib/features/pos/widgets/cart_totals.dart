import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cart_provider.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/held_ticket_provider.dart';
import '../screens/payment_screen.dart';
import '../services/settings_service.dart';
import '../providers/waiting_ticket_provider.dart' as waiting;

/// Loyverse-inspired cart totals panel.
///
/// Shows:
/// - Subtotal, tax, discount (if any)
/// - Total with large prominent amount
/// - Hold / Clear action buttons
/// - Prominent green "Charge $X.XX" button (always visible)
class CartTotals extends ConsumerWidget {
  const CartTotals({
    required this.cart,
    required this.notifier,
    final Key? key,
  }) : super(key: key);

  final CartState cart;
  final dynamic notifier;

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final cur = watchCurrency(ref);
    final subtotal = cart.total;
    final hasItemDiscounts = cart.items.any((i) => (i.discountAmount ?? 0) > 0);
    final tax = cart.taxAmount;
    final discount = cart.discount;
    final finalTotal = cart.finalTotal;

    return Container(
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        border: Border(
          top: BorderSide(color: PosTheme.dividerColorOf(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Subtotal ──
          _buildRow(context.l10n.cartSubtotal, formatAmount(subtotal, cur)),
          const SizedBox(height: 4),
          // ── Tax ──
          _buildRow(
              '${context.l10n.cartTax} (${(cart.taxRate * 100).toStringAsFixed(0)}%)',
              formatAmount(tax, cur)),
          // ── Item-level discounts (if any) ──
          if (hasItemDiscounts) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  context.l10n.cartTotalsItemDiscounts,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PosTheme.warningAmber,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${formatAmount(cart.total - cart.items.fold<double>(0, (s, i) => s + i.lineTotal), cur)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PosTheme.warningAmber,
                  ),
                ),
              ],
            ),
          ],
          // ── Cart-level discount (if any) ──
          if (discount > 0) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  context.l10n.cartDiscount,
                  style: const TextStyle(
                    fontSize: 13,
                    color: PosTheme.accentBlue,
                  ),
                ),
                const Spacer(),
                Text(
                  '-\$${discount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PosTheme.accentBlue,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          // ── Divider ──
          Divider(height: 1, color: PosTheme.dividerColorOf(context)),
          const SizedBox(height: 8),
          // ── Total ──
          Row(
            children: [
              Text(
                context.l10n.cartTotal,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: PosTheme.textSecondaryOf(context),
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatAmount(finalTotal, cur),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: PosTheme.textPrimaryOf(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Action buttons row ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: cart.items.isNotEmpty
                        ? () async {
                            final List<CartItem> itemsSnapshot =
                                List<CartItem>.from(cart.items);

                            final OrderMode orderModeSnapshot = cart.orderMode;

                            final double totalSnapshot = cart.finalTotal;

                            try {
                              final int waitingNumber =
                                  await notifier.ensureWaitingNumber();

                              final int? heldTicketId = await ref
                                  .read(heldTicketProvider.notifier)
                                  .holdCurrentCart(
                                    itemsSnapshot,
                                    ticketId: cart.heldTicketId,
                                  );

                              if (heldTicketId == null) {
                                // holdCurrentCart() swallows its own errors
                                // into heldTicketProvider's state and
                                // returns null on failure (e.g. the
                                // selected table is already in use) —
                                // surface that here instead of silently
                                // reporting success and wiping the cart.
                                throw Exception(
                                  ref.read(heldTicketProvider).error ??
                                      'Failed to hold ticket',
                                );
                              }

                              await ref
                                  .read(
                                    waiting.waitingNumberServiceProvider,
                                  )
                                  .saveWaitingTicket(
                                    waitingNumber: waitingNumber,
                                    items: itemsSnapshot,
                                    orderMode: orderModeSnapshot,
                                    status: WaitingTicketStatus.held,
                                    total: totalSnapshot,
                                    orderId: heldTicketId,
                                  );

                              ref.invalidate(
                                waiting.waitingTicketsProvider,
                              );

                              // Clear the current cart, but do not release
                              // the held customer's waiting number.
                              await notifier.clear(
                                releaseWaitingNumber: false,
                              );

                              if (!context.mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.l10n.cartTotalsTicketHeld(
                                      waitingNumber.toString().padLeft(3, '0'),
                                    ),
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    context.l10n.cartTotalsHoldFailed(
                                      error.toString(),
                                    ),
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PosTheme.textSecondaryOf(context),
                      side: BorderSide(color: PosTheme.borderColorOf(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pause, size: 16),
                        const SizedBox(width: 4),
                        Text(context.l10n.cartTotalsHold,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: cart.items.isNotEmpty
                        ? () => ref
                            .read(heldTicketProvider.notifier)
                            .cancelResume()
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PosTheme.textSecondaryOf(context),
                      side: BorderSide(color: PosTheme.borderColorOf(context)),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete_sweep, size: 16),
                        const SizedBox(width: 4),
                        Text(context.l10n.cartClear,
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ── Discount row (Loyverse-style) ──
          if (cart.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 36,
              child: OutlinedButton.icon(
                icon: Icon(
                  cart.discount > 0 ? Icons.discount : Icons.discount_outlined,
                  size: 16,
                  color: cart.discount > 0
                      ? PosTheme.accentBlue
                      : PosTheme.textSecondaryOf(context),
                ),
                label: Text(
                  cart.discount > 0
                      ? '${context.l10n.cartDiscount} ${cart.discountType == DiscountType.fixed ? '${formatAmount(cart.discount, cur)}' : '${cart.discount.toStringAsFixed(0)}%'}'
                      : context.l10n.cartTotalsAddDiscount,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        cart.discount > 0 ? FontWeight.w600 : FontWeight.w400,
                    color: cart.discount > 0
                        ? PosTheme.accentBlue
                        : PosTheme.textSecondaryOf(context),
                  ),
                ),
                onPressed: () =>
                    _showDiscountDialog(context, ref, notifier, cart),
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosTheme.textSecondaryOf(context),
                  side: BorderSide(
                    color: cart.discount > 0
                        ? PosTheme.accentBlue.withOpacity(0.3)
                        : PosTheme.borderColorOf(context),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
                  ),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          // ── Quick discount preset row (Loyverse style) ──
          if (cart.items.isNotEmpty && discount <= 0) ...[
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _presetChip(
                      '10%',
                      () => notifier.applyDiscount(10,
                          type: DiscountType.percent)),
                  const SizedBox(width: 6),
                  _presetChip(
                      '15%',
                      () => notifier.applyDiscount(15,
                          type: DiscountType.percent)),
                  const SizedBox(width: 6),
                  _presetChip(
                      '20%',
                      () => notifier.applyDiscount(20,
                          type: DiscountType.percent)),
                  const SizedBox(width: 6),
                  _presetChip(
                      r'$1',
                      () =>
                          notifier.applyDiscount(1, type: DiscountType.fixed)),
                  const SizedBox(width: 6),
                  _presetChip(
                      r'$5',
                      () =>
                          notifier.applyDiscount(5, type: DiscountType.fixed)),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // ── Prominent Charge button (Loyverse style) ──
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: finalTotal > 0
                  ? () async {
                      final int waitingNumber =
                          await notifier.ensureWaitingNumber();
                      // Build sale lines from cart items for backend integration
                      final saleLines = cart.items.map((item) {
                        return <String, dynamic>{
                          'productId': item.product.id,
                          'quantity': item.qty,
                          if (item.note != null) 'note': item.note,
                          if (item.discountAmount != null &&
                              item.discountAmount! > 0)
                            'lineDiscount': item.discountAmount! * item.qty,
                          if (item.selectedModifiers.isNotEmpty) ...{
                            'modifierSummary': item.modifierSummaryText,
                            'modifierData': item.modifierDataJson,
                          },
                        };
                      }).toList();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          total: finalTotal,
                          saleLines: saleLines,
                          customerId: cart.customerId,
                          tableId: cart.tableId,
                          waitingNumber: waitingNumber,
                          heldTicketId: cart.heldTicketId,
                        ),
                      ));
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: PosTheme.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                disabledBackgroundColor: PosTheme.dividerColorOf(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Charge  ${formatAmount(finalTotal, cur)}',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: PosTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PosTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Shows a Loyverse-style discount dialog (amount or percent) with presets from settings.
void _showDiscountDialog(
  BuildContext context,
  WidgetRef ref,
  dynamic notifier,
  CartState cart,
) {
  final amountCtl = TextEditingController(
    text: cart.discount > 0 ? cart.discount.toStringAsFixed(2) : '',
  );
  DiscountType type = cart.discountType;
  bool hasDiscount = cart.discount > 0;
  List<Map<String, dynamic>> presets = [];

  // Load presets from backend
  try {
    final service = ref.read(settingsServiceProvider);
    service.getDiscountPresets().then((resp) {
      if (resp['presets'] is List) {
        presets = List<Map<String, dynamic>>.from(resp['presets'] as List);
      }
    });
  } catch (_) {}

  // Fallback presets if backend fails
  if (presets.isEmpty) {
    presets = [
      {'label': '10% Off', 'percent': 10, 'amount': 0},
      {'label': '15% Off', 'percent': 15, 'amount': 0},
      {'label': '20% Off', 'percent': 20, 'amount': 0},
      {'label': '\$1 Off', 'percent': 0, 'amount': 1.0},
      {'label': '\$5 Off', 'percent': 0, 'amount': 5.0},
    ];
  }

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: PosTheme.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  ),
                  child: const Icon(Icons.discount,
                      color: PosTheme.accentBlue, size: 20),
                ),
                const SizedBox(width: 12),
                Text(ctx.l10n.cartDiscount,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Type toggle
                  Row(
                    children: [
                      _typeChip(ctx.l10n.cartTotalsFixedAmount,
                          DiscountType.fixed, type,
                          (t) => setDialogState(() => type = t)),
                      const SizedBox(width: 8),
                      _typeChip(ctx.l10n.cartTotalsPercentAmount,
                          DiscountType.percent, type,
                          (t) => setDialogState(() => type = t)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: type == DiscountType.fixed
                          ? ctx.l10n.cartTotalsAmountLabel
                          : ctx.l10n.cartTotalsPercentLabel,
                      prefixIcon: Icon(
                        type == DiscountType.fixed
                            ? Icons.attach_money
                            : Icons.percent,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium),
                      ),
                      filled: true,
                      fillColor: PosTheme.backgroundPageOf(ctx),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quick presets row
                  Text(ctx.l10n.cartTotalsQuickSelect,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PosTheme.textSecondaryOf(ctx))),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((preset) {
                      final pct = (preset['percent'] as num?)?.toDouble() ?? 0;
                      final amt = (preset['amount'] as num?)?.toDouble() ?? 0;
                      final label = preset['label'] as String? ?? '';
                      return ActionChip(
                        label:
                            Text(label, style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          if (pct > 0) {
                            type = DiscountType.percent;
                            amountCtl.text = pct.toStringAsFixed(0);
                          } else if (amt > 0) {
                            type = DiscountType.fixed;
                            amountCtl.text = amt.toStringAsFixed(2);
                          }
                          setDialogState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  // Percent quick picks
                  if (type == DiscountType.percent)
                    Wrap(
                      spacing: 6,
                      children: [5, 10, 15, 20, 25, 50]
                          .map((pct) => ChoiceChip(
                                label: Text('$pct%',
                                    style: const TextStyle(fontSize: 12)),
                                selected: amountCtl.text == pct.toString(),
                                onSelected: (_) => setDialogState(
                                    () => amountCtl.text = pct.toString()),
                              ))
                          .toList(),
                    ),
                ],
              ),
            ),
            actions: [
              if (hasDiscount)
                TextButton(
                  onPressed: () {
                    notifier.clearDiscount();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(ctx.l10n.cartTotalsRemoveDiscount,
                      style: const TextStyle(color: PosTheme.errorRed)),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.l10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed = double.tryParse(amountCtl.text);
                  if (parsed != null && parsed > 0) {
                    notifier.applyDiscount(parsed, type: type);
                  }
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.accentBlue,
                  foregroundColor: Colors.white,
                ),
                child: Text(ctx.l10n.commonApply),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _typeChip(
  String label,
  DiscountType value,
  DiscountType current,
  void Function(DiscountType) onSelected,
) {
  final selected = value == current;
  return Expanded(
    child: GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PosTheme.accentBlue : Colors.white,
          borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
          border: Border.all(
            color: selected ? PosTheme.accentBlue : PosTheme.borderColor,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : PosTheme.textSecondary,
          ),
        ),
      ),
    ),
  );
}

/// Quick-apply discount preset chip shown in the cart totals bar.
Widget _presetChip(String label, VoidCallback onPressed) {
  return SizedBox(
    height: 34,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: PosTheme.accentBlue,
        side: BorderSide(color: PosTheme.accentBlue.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosTheme.radiusPill),
        ),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    ),
  );
}
