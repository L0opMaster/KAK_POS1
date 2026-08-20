import '../models/cart_models.dart';

/// Subtotal + tax for [ticket]'s saved cart items — the same formula
/// `held_tickets_dialog.dart`'s bill printing and `_pos_drawer.dart`'s
/// quick-print both read from, so a ticket's on-screen/report total always
/// matches what its printed bill shows. A held ticket has no cart-level
/// discount to prorate (see [HeldOrder], which carries no discount field),
/// so this is `CartState.taxAmount`'s formula with the discount term
/// dropped rather than a separate calculation drifting out of sync with it.
double heldOrderTotal(HeldOrder ticket) {
  final items = ticket.cartItems ?? const <CartItem>[];
  final subtotal = items.fold(0.0, (sum, i) => sum + i.lineTotal);
  final taxAmount = items.fold(
      0.0,
      (sum, i) =>
          sum + (i.lineTotal - (i.discountAmount ?? 0) * i.qty) * i.product.taxRate);
  return subtotal + taxAmount;
}

/// Total item quantity across [ticket]'s saved cart items.
int heldOrderItemCount(HeldOrder ticket) =>
    (ticket.cartItems ?? const <CartItem>[]).fold(0, (sum, i) => sum + i.qty);
