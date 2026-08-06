import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';

/// Displays the running totals, discount/loyalty adjustments and
/// optional clear buttons for the cart.
class CartFooter extends ConsumerWidget {
  const CartFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final total = cartState.total;
    final discount = cartState.discount;
    final loyalty = cartState.loyalty;
    final finalTotal = cartState.finalTotal;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.l10n
              .cartFooterTotalAmount('\$${total.toStringAsFixed(2)}')),
          if (discount != 0)
            Text(context.l10n.cartFooterDiscountAmount(
                '\$${discount.toStringAsFixed(2)}')),
          if (loyalty != 0)
            Text(context.l10n
                .cartFooterLoyaltyAmount('\$${loyalty.toStringAsFixed(2)}')),
          Text(context.l10n
              .cartFooterFinalAmount('\$${finalTotal.toStringAsFixed(2)}')),
          if (discount != 0)
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).clearDiscount();
              },
              child: Text(context.l10n.cartFooterClearDiscount),
            ),
          if (loyalty != 0)
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).clearLoyalty();
              },
              child: Text(context.l10n.cartFooterClearLoyalty),
            ),
        ],
      ),
    );
  }
}
