import 'package:flutter/material.dart';

import '../models/display_message.dart';

/// Shown right after a sale completes. Reverts to idle automatically after
/// a few seconds — timer lives in `DisplayNotifier`, not here.
class ThankYouView extends StatelessWidget {
  const ThankYouView({super.key, required this.receipt});

  final PaymentCompletedSnapshot receipt;

  String _money(double amount) =>
      '${receipt.currencySymbol}${amount.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0B3D1E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 88),
            const SizedBox(height: 16),
            const Text(
              'Thank You!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Total: ${_money(receipt.total)}',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            if (receipt.change > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Change: ${_money(receipt.change)}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (receipt.receiptNumber.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Receipt ${receipt.receiptNumber}',
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
