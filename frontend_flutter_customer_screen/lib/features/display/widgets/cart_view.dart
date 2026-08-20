import 'package:flutter/material.dart';

import '../models/display_message.dart';

/// Warning/pending amber — matches frontend-flutter-pos's pre-payment
/// "Print Bill" design (`receipt_paper_view.dart`'s `_amber`), so a
/// customer sees the same "not paid yet" color language on this live
/// display as staff do on the printed bill.
const _amber = Color(0xFFB86A00);

/// Live mirror of the cart being rung up on the POS, item-by-item with a
/// totals footer — the core "customer sees what's being charged" view.
/// This is the pre-payment moment (before the cashier even opens Payment,
/// see `payment_pending_view.dart` for that next step), so it's framed the
/// same way frontend-flutter-pos's held-ticket "Print Bill" preview is: a
/// clear "not yet paid" banner top and bottom, never anything that could
/// read as a completed sale.
class CartView extends StatelessWidget {
  const CartView({super.key, required this.cart});

  final CartSnapshot cart;

  String _money(double amount) =>
      '${cart.currencySymbol}${amount.toStringAsFixed(2)}';

  String _orderModeLabel(String raw) {
    switch (raw) {
      case 'dineIn':
        return 'Dine In';
      case 'takeaway':
        return 'Takeaway';
      case 'delivery':
        return 'Delivery';
      default:
        return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F8),
      child: Column(
        children: [
          // ── Bill preview banner ──
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'YOUR ORDER',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                        color: _amber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _orderModeLabel(cart.orderMode).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _amber,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Not yet paid — please wait while your order is prepared.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Text(
                      'Waiting for items…',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(24),
                    itemCount: cart.items.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 24),
                    itemBuilder: (context, index) {
                      final CartItemSnapshot item = cart.items[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.qty}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nameEn,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.modifiers != null &&
                                    item.modifiers!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      item.modifiers!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            _money(item.lineTotal),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                _totalsRow('Subtotal', _money(cart.subtotal)),
                if (cart.discountAmount > 0)
                  _totalsRow('Discount', '-${_money(cart.discountAmount)}'),
                _totalsRow('Tax', _money(cart.taxAmount)),
                const Divider(height: 24),
                _totalsRow('Total', _money(cart.total), emphasize: true),
                const SizedBox(height: 16),
                // ── UNPAID status — mirrors the printed pre-payment
                // bill's "PAYMENT STATUS: UNPAID" callout exactly, so
                // this screen never reads as a completed sale.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _amber.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _amber.withValues(alpha: 0.35)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        'UNPAID',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: _amber,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsRow(String label, String value, {bool emphasize = false}) {
    final TextStyle style = TextStyle(
      fontSize: emphasize ? 26 : 16,
      fontWeight: emphasize ? FontWeight.w800 : FontWeight.w500,
      color: emphasize ? Colors.black : Colors.grey.shade700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
