import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/config/currency_utils.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';
import '../screens/payment_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// cart_totals.dart` — ADAPTED, substantially reduced. Kept: subtotal,
/// tax, item-level discount summary, cart-level discount summary, grand
/// total, the discount-entry dialog (fixed/percent + 5 hardcoded quick
/// presets), a Hold button (added Day 9, once `held_ticket_provider.dart`
/// existed to back it), a Clear Cart button, and — added Day 11, now that
/// `payment_screen.dart`/`sale_service.dart` exist — the Charge button and
/// its `saleLines` construction, COPY/ADAPT NEARLY EXACTLY from source.
/// Still DROPPED:
///   - discount presets fetched from `settingsService.getDiscountPresets()`
///     -> Day 19 (Settings); this port always uses the same 5 hardcoded
///     presets source falls back to when that fetch fails, so the feature
///     still works, just without the backend-configurable part
///
/// Day 7's "Clear" note is now resolved with the full picture — CORRECTED
/// from this file's own earlier claim. Source's `cart_panel.dart`
/// `_handleClearPressed` does NOT call `cancelResume()` (that method puts a
/// resumed ticket back to "open" — "I'll come back to this later"). It
/// branches: no held ticket -> `cartProvider.notifier.clear()` directly, no
/// confirmation; held ticket -> a confirmation dialog, and on confirm,
/// `heldTicketProvider.notifier.cancelCurrentTicket()` — which VOIDS the
/// order on the backend instead of re-holding it. `cancelResume()` is a
/// genuinely different action (used elsewhere, e.g. abandoning an
/// in-progress resume without an explicit cancel choice), not a synonym for
/// "Clear". This port's Clear button now reproduces the real branch and
/// calls `cancelCurrentTicket()`, matching source exactly.
class CartTotals extends ConsumerWidget {
  const CartTotals({required this.cart, required this.notifier, super.key});

  final CartState cart;
  final CartNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = watchCurrency(ref);
    final subtotal = cart.total;
    final hasItemDiscounts = cart.items.any((i) => (i.discountAmount ?? 0) > 0);
    final tax = cart.taxAmount;
    final discount = cart.discount;
    final finalTotal = cart.finalTotal;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        border: Border(
          top: BorderSide(color: PosTheme.dividerColorOf(context)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        PosTheme.spacingLg,
        PosTheme.spacingMd,
        PosTheme.spacingLg,
        PosTheme.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(l10n.cartSubtotal, formatAmount(subtotal, cur)),
          const SizedBox(height: 4),
          _row(
            '${l10n.cartTax} (${(cart.taxRate * 100).toStringAsFixed(0)}%)',
            formatAmount(tax, cur),
          ),
          if (hasItemDiscounts) ...[
            const SizedBox(height: 4),
            _row(
              l10n.cartTotalsItemDiscounts,
              '-${formatAmount(cart.total - cart.items.fold<double>(0, (s, i) => s + i.lineTotal), cur)}',
              color: PosTheme.warningAmber,
            ),
          ],
          if (discount > 0) ...[
            const SizedBox(height: 4),
            _row(
              l10n.cartDiscount,
              '-${cart.discountType == DiscountType.fixed ? formatAmount(discount, cur) : '${discount.toStringAsFixed(0)}%'}',
              color: PosTheme.accentBlue,
            ),
          ],
          const SizedBox(height: PosTheme.spacingSm),
          Divider(height: 1, color: PosTheme.dividerColorOf(context)),
          const SizedBox(height: PosTheme.spacingSm),
          Row(
            children: [
              Text(
                l10n.cartTotal,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: PosTheme.textSecondaryOf(context),
                ),
              ),
              const Spacer(),
              Text(
                formatAmount(finalTotal, cur),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.spacingMd),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(
                    discount > 0 ? Icons.discount : Icons.discount_outlined,
                    size: 16,
                  ),
                  label: Text(
                    discount > 0
                        ? '${l10n.cartDiscount} ${cart.discountType == DiscountType.fixed ? formatAmount(discount, cur) : '${discount.toStringAsFixed(0)}%'}'
                        : l10n.cartTotalsAddDiscount,
                  ),
                  onPressed: () => _showDiscountDialog(context, notifier, cart),
                ),
              ),
              const SizedBox(width: PosTheme.spacingSm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.pause, size: 16),
                  label: Text(l10n.cartTotalsHold),
                  onPressed: cart.items.isNotEmpty
                      ? () => _hold(context, ref, notifier, cart)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.spacingSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.delete_sweep, size: 16),
              label: Text(l10n.cartClear),
              onPressed: cart.items.isNotEmpty
                  ? () => _handleClear(context, ref, cart)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: PosTheme.errorRed,
                side: BorderSide(
                  color: PosTheme.errorRed.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          const SizedBox(height: PosTheme.spacingSm),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: finalTotal > 0
                  ? () => _charge(context, cart, finalTotal, cur)
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
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// REUSE EXISTING FUNCTION shape from `[OLD/SOURCE]` `CartTotals`'s Hold
  /// button `onPressed` — `ensureWaitingNumber()` then
  /// `heldTicketProvider.notifier.holdCurrentCart()`. Source additionally
  /// calls `waitingNumberServiceProvider...saveWaitingTicket()` (the
  /// queue-board feature this port doesn't build, see
  /// waiting_number_service.dart) and its OWN extra
  /// `notifier.clear(releaseWaitingNumber: false)` afterward —
  /// `holdCurrentCart()` already calls `cartProvider.notifier.clear()`
  /// internally, so that second clear in source is redundant by the time
  /// it runs (the waiting number is already gone); this port simply
  /// doesn't repeat it.
  Future<void> _hold(
    BuildContext context,
    WidgetRef ref,
    CartNotifier notifier,
    CartState cart,
  ) async {
    final l10n = context.l10n;
    final itemsSnapshot = List<CartItem>.from(cart.items);
    try {
      final waitingNumber = await notifier.ensureWaitingNumber();
      final heldTicketId = await ref
          .read(heldTicketProvider.notifier)
          .holdCurrentCart(itemsSnapshot, ticketId: cart.heldTicketId);
      if (heldTicketId == null) {
        throw Exception(
          ref.read(heldTicketProvider).error ?? 'Failed to hold ticket',
        );
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.cartTotalsTicketHeld(waitingNumber.toString().padLeft(3, '0')),
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cartTotalsHoldFailed(error.toString()))),
      );
    }
  }

  /// Ported from source's Charge button `onPressed` — COPY/ADAPT NEARLY
  /// EXACTLY, including `saleLines`'s exact shape (this is the request
  /// payload the shared backend's `SaleCreateRequest.lines` expects).
  Future<void> _charge(
    BuildContext context,
    CartState cart,
    double finalTotal,
    String cur,
  ) async {
    final int waitingNumber = await notifier.ensureWaitingNumber();
    final saleLines = cart.items.map((item) {
      return <String, dynamic>{
        'productId': item.product.id,
        'quantity': item.qty,
        if (item.note != null) 'note': item.note,
        if (item.discountAmount != null && item.discountAmount! > 0)
          'lineDiscount': item.discountAmount! * item.qty,
        if (item.selectedModifiers.isNotEmpty) ...{
          'modifierSummary': item.modifierSummaryText,
          'modifierData': item.modifierDataJson,
        },
      };
    }).toList();
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentScreen(
          total: finalTotal,
          saleLines: saleLines,
          customerId: cart.customerId,
          tableId: cart.tableId,
          waitingNumber: waitingNumber,
          heldTicketId: cart.heldTicketId,
        ),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: color ?? PosTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? PosTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Matches source's `_handleClearPressed` branch exactly (see this file's
  /// header): a cart that was never resumed from a held ticket just clears,
  /// no confirmation needed. A cart resumed from a ticket asks for
  /// confirmation first, since clearing here permanently voids that order
  /// rather than merely emptying the working cart.
  Future<void> _handleClear(
    BuildContext context,
    WidgetRef ref,
    CartState cart,
  ) async {
    if (cart.heldTicketId == null) {
      await notifier.clear();
      return;
    }

    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cartActionsClearCart),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.cartClear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(heldTicketProvider.notifier).cancelCurrentTicket();
  }
}

/// Fixed 5 quick-discount presets — same fallback values `[OLD/SOURCE]`
/// uses when its backend `getDiscountPresets()` call fails.
void _showDiscountDialog(
  BuildContext context,
  CartNotifier notifier,
  CartState cart,
) {
  final amountCtl = TextEditingController(
    text: cart.discount > 0 ? cart.discount.toStringAsFixed(2) : '',
  );
  DiscountType type = cart.discountType;
  final hasDiscount = cart.discount > 0;
  final l10n = context.l10n;

  showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(l10n.cartDiscount),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Text(l10n.cartTotalsFixedAmount),
                        selected: type == DiscountType.fixed,
                        onSelected: (_) =>
                            setDialogState(() => type = DiscountType.fixed),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: Text(l10n.cartTotalsPercentAmount),
                        selected: type == DiscountType.percent,
                        onSelected: (_) =>
                            setDialogState(() => type = DiscountType.percent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: amountCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: type == DiscountType.fixed
                        ? l10n.cartTotalsAmountLabel
                        : l10n.cartTotalsPercentLabel,
                  ),
                ),
                const SizedBox(height: PosTheme.spacingSm),
                Wrap(
                  spacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('10%'),
                      onPressed: () => setDialogState(() {
                        type = DiscountType.percent;
                        amountCtl.text = '10';
                      }),
                    ),
                    ActionChip(
                      label: const Text('15%'),
                      onPressed: () => setDialogState(() {
                        type = DiscountType.percent;
                        amountCtl.text = '15';
                      }),
                    ),
                    ActionChip(
                      label: const Text('20%'),
                      onPressed: () => setDialogState(() {
                        type = DiscountType.percent;
                        amountCtl.text = '20';
                      }),
                    ),
                    ActionChip(
                      label: const Text(r'$1'),
                      onPressed: () => setDialogState(() {
                        type = DiscountType.fixed;
                        amountCtl.text = '1';
                      }),
                    ),
                    ActionChip(
                      label: const Text(r'$5'),
                      onPressed: () => setDialogState(() {
                        type = DiscountType.fixed;
                        amountCtl.text = '5';
                      }),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (hasDiscount)
                TextButton(
                  onPressed: () {
                    notifier.clearDiscount();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    l10n.cartTotalsRemoveDiscount,
                    style: TextStyle(color: PosTheme.errorRed),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.commonCancel),
              ),
              ElevatedButton(
                onPressed: () {
                  final parsed = double.tryParse(amountCtl.text);
                  if (parsed != null && parsed > 0) {
                    notifier.applyDiscount(parsed, type: type);
                  }
                  Navigator.of(ctx).pop();
                },
                child: Text(l10n.commonApply),
              ),
            ],
          );
        },
      );
    },
  );
}
