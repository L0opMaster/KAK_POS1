import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';

/// NEW — no `[OLD/SOURCE]` equivalent. Persistent bottom bar shown on
/// `PosRegisterScreen` whenever the cart has items, replacing source's
/// fixed 380px cart sidebar for phone-sized screens (see DAY_06.md section
/// 10). Tapping it pushes the full `CartScreen`. Hidden entirely when the
/// cart is empty, matching common mobile POS/e-commerce "View Cart" bar
/// conventions.
class CartSummaryBar extends ConsumerWidget {
  const CartSummaryBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.items.isEmpty) return const SizedBox.shrink();

    final cur = watchCurrency(ref);
    final itemCount = cart.items.fold<int>(0, (sum, i) => sum + i.qty);
    final l10n = context.l10n;

    return Material(
      color: PosTheme.primaryGreen,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CartScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: PosTheme.spacingLg, vertical: PosTheme.spacingMd),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.white,
                child: Text('$itemCount',
                    style: TextStyle(
                        color: PosTheme.primaryGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
              const SizedBox(width: PosTheme.spacingSm),
              Expanded(
                child: Text(l10n.cartSummaryBarViewCart,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
              Text(formatAmount(cart.finalTotal, cur),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
              const SizedBox(width: PosTheme.spacingXs),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
