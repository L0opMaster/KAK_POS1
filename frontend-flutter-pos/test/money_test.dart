import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/utils/money.dart';

void main() {
  group('Money', () {
    test('round-trips major <-> minor', () {
      expect(Money.toMinor(12.34), 1234);
      expect(Money.toMajor(1234), 12.34);
    });

    test('line total is exact for repeated cents', () {
      // 0.10 x 3 in float is 0.30000000000000004; minor units keep it exact.
      expect(Money.lineTotalMinor(0.10, 3), 30);
      expect(Money.toMajor(Money.lineTotalMinor(0.10, 3)), 0.30);
    });

    test('percent is rounded to the nearest minor unit', () {
      expect(Money.percentOfMinor(1000, 10), 100); // 10% of $10.00
      expect(Money.percentOfMinor(999, 10), 100); // 99.9c -> 100c
    });

    test('no accumulation error across many small lines', () {
      var minor = 0;
      for (var i = 0; i < 10; i++) {
        minor += Money.lineTotalMinor(0.10, 1);
      }
      expect(Money.toMajor(minor), 1.00);
    });
  });
}
