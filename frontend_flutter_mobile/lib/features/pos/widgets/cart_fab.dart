import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_screen.dart';

/// Mobile-only floating cart entry point — replaces `CartSummaryBar`'s
/// persistent bottom bar with a `FloatingActionButton` hosted on
/// `MobileShellScreen`'s Scaffold (shown only while the Register tab is
/// active; `PosRegisterScreen` itself has no Scaffold of its own, so the
/// FAB can't live there directly).
///
/// CHANGED: used to hide entirely when the cart was empty, same convention
/// `CartSummaryBar` used — but that left `CartScreen` (and its empty-cart
/// "Open Held Tickets" button, see `cart_items_list.dart`) completely
/// unreachable with nothing in the cart, so a cashier with a held ticket to
/// resume and nothing yet in the cart had no way to get there. Now shows a
/// smaller icon-only FAB (no item badge/total — there's nothing to total)
/// on empty, still opening `CartScreen`.
class CartFab extends ConsumerWidget {
  const CartFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    if (cart.items.isEmpty) {
      return FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CartScreen()),
        ),
        backgroundColor: PosTheme.backgroundCardOf(context),
        foregroundColor: PosTheme.textSecondaryOf(context),
        child: const Icon(Icons.shopping_cart_outlined),
      );
    }

    final cur = watchCurrency(ref);
    final itemCount = cart.items.fold<int>(0, (sum, i) => sum + i.qty);

    return FloatingActionButton.extended(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const CartScreen()),
      ),
      backgroundColor: PosTheme.primaryGreen,
      foregroundColor: Colors.white,
      icon: Badge(
        label: Text('$itemCount'),
        backgroundColor: Colors.white,
        textColor: PosTheme.primaryGreen,
        child: const Icon(Icons.shopping_cart),
      ),
      label: Text(
        formatAmount(cart.finalTotal, cur),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
