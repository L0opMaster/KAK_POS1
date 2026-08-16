import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';
import '../widgets/cart_header.dart';
import '../widgets/cart_items_list.dart';
import '../widgets/cart_totals.dart';

/// The mobile cart destination — this is the answer DAY_06.md section 10
/// flagged as an open question ("no cart sidebar... Day 7 needs to decide
/// how the cart is reached on mobile"). Chosen: a dedicated full-screen
/// push (`Navigator.push`), reached via `CartFab`'s tap target on
/// `MobileShellScreen` — not a bottom sheet, since editing cart lines
/// (qty/note/discount dialogs, modifier bottom sheets) already stacks
/// modals on top of a modal awkwardly; a full screen keeps that nesting
/// one level shallower. No `[OLD/SOURCE]` file maps to this one directly —
/// it's the mobile equivalent of `CartPanel`'s content (the itemized list
/// + totals).
///
/// ADDED: `CartHeader` (order mode / table / customer / waiting-number
/// chips) — the piece this file's own header used to flag as dropped
/// ("Day 9 scope", never built). See `cart_header.dart`'s doc comment.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final notifier = ref.read(cartProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cartSummaryBarViewCart)),
      body: Column(
        children: [
          const CartHeader(),
          Expanded(
            child: CartItemsList(items: cart.items, notifier: notifier),
          ),
          if (cart.items.isNotEmpty)
            CartTotals(cart: cart, notifier: notifier),
        ],
      ),
    );
  }
}
