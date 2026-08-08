// Regression coverage for the "Paid $6.50 / Change $0.52 with no visible
// tendered amount" confusion: `_chargeCash()` always capped the split's
// `amount` at the sale total before it ever reached the backend, so
// SaleService.pay's own appliedAmount/changeAmount math (which correctly
// handles "customer tendered more than owed") never saw a tender greater
// than the total — change was silently recorded as zero server-side no
// matter what was actually handed over. paymentRequestEntry is the fix:
// for a cash split, it sends what was tendered (not what was applied) when
// that's larger.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/features/pos/screens/payment_screen.dart';

void main() {
  group('paymentRequestEntry — cash, tendered exceeds the applied amount',
      () {
    test('Step 7.F: total 7.15, tendered 10.00 -> sends 10.00, not 7.15',
        () {
      final split = SplitRow(id: 0, method: PaymentMethod.cash, amount: 7.15)
        ..status = SplitStatus.authorized;

      final entry = paymentRequestEntry(split, 10.00);

      expect(entry['amount'], 10.00,
          reason: 'the backend needs the real tendered amount to compute '
              'appliedAmount/changeAmount itself — sending the pre-capped '
              '7.15 is exactly what made change always compute to zero');
      expect(entry['method'], 'CASH');
    });
  });

  group('paymentRequestEntry — cash, exact or under tender', () {
    test('tendered equals applied -> sends the applied amount', () {
      final split = SplitRow(id: 0, method: PaymentMethod.cash, amount: 6.50)
        ..status = SplitStatus.authorized;
      final entry = paymentRequestEntry(split, 6.50);
      expect(entry['amount'], 6.50);
    });

    test('cashReceived is null (e.g. "pay full amount" shortcut, no cash '
        'entry) -> sends the applied amount, no crash', () {
      final split = SplitRow(id: 0, method: PaymentMethod.cash, amount: 6.50)
        ..status = SplitStatus.authorized;
      final entry = paymentRequestEntry(split, null);
      expect(entry['amount'], 6.50);
    });

    test('tendered is somehow less than applied (should not normally '
        'happen) -> still sends the applied amount, never less', () {
      final split = SplitRow(id: 0, method: PaymentMethod.cash, amount: 6.50)
        ..status = SplitStatus.authorized;
      final entry = paymentRequestEntry(split, 5.00);
      expect(entry['amount'], 6.50);
    });
  });

  group('paymentRequestEntry — non-cash methods ignore cashReceived', () {
    test('card payment -> always sends the applied amount, even if '
        'cashReceived happens to be set from an earlier cash split', () {
      final split = SplitRow(id: 0, method: PaymentMethod.card, amount: 20.00)
        ..status = SplitStatus.authorized;
      final entry = paymentRequestEntry(split, 999.00);
      expect(entry['amount'], 20.00,
          reason: 'overpayment/change is a cash-only concept');
      expect(entry['method'], 'CARD');
    });
  });
}
