import 'package:flutter/material.dart';

import '../models/display_message.dart';

/// Shown once the cashier opens the payment screen: a big "amount due"
/// figure, plus a running split-payment breakdown if the sale is being
/// paid across multiple methods.
class PaymentPendingView extends StatelessWidget {
  const PaymentPendingView({
    super.key,
    required this.pending,
    this.splitUpdate,
  });

  final PaymentPendingSnapshot pending;
  final PaymentSplitUpdateSnapshot? splitUpdate;

  String _money(String symbol, double amount) =>
      '$symbol${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final PaymentSplitUpdateSnapshot? splits = splitUpdate;

    return Container(
      color: const Color(0xFF102A1F),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Amount Due',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _money(pending.currencySymbol, pending.amountDue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (splits != null && splits.splits.isNotEmpty) ...[
              const SizedBox(height: 32),
              ...splits.splits.map(
                (split) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${split.method}: ${_money(splits.currencySymbol, split.amount)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                ),
              ),
              if (splits.remaining > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Remaining: ${_money(splits.currencySymbol, splits.remaining)}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
