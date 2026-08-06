import 'package:flutter/material.dart';

import '../models/display_message.dart';

/// Live mirror of the cart being rung up on the POS, item-by-item with a
/// totals footer — the core "customer sees what's being charged" view.
class CartView extends StatelessWidget {
  const CartView({super.key, required this.cart});

  final CartSnapshot cart;

  String _money(double amount) =>
      '${cart.currencySymbol}${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF7F7F8),
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: cart.items.length,
              separatorBuilder: (context, index) => const Divider(height: 24),
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
                        style: const TextStyle(fontWeight: FontWeight.w700),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                _totalsRow(
                  'Total',
                  _money(cart.total),
                  emphasize: true,
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
