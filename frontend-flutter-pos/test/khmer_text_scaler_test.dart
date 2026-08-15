import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/utils/khmer_text_scaler.dart';

void main() {
  group('khmerAwareTextScaler', () {
    test('English (isKhmer: false) returns the base scaler unchanged', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: false);

      expect(result, same(base));
      expect(result.scale(12), 12);
      expect(result.scale(24), 24);
      expect(result.scale(32), 32);
    });

    test('Khmer bumps small/body text (+2) on top of the base scale', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      expect(result.scale(12), 14);
      expect(result.scale(16), 18);
    });

    test('Khmer bumps title-sized text (+3) on top of the base scale', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      expect(result.scale(20), 23);
      expect(result.scale(27), 30);
    });

    test('Khmer leaves very large display text unchanged (>= 28)', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      expect(result.scale(28), 28);
      expect(result.scale(40), 40);
    });

    test('composes with (does not replace) a non-1.0 platform text scale',
        () {
      const base = TextScaler.linear(1.5);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      // 12 * 1.5 = 18 -> still in the "+2" bracket relative to the scaled value
      expect(result.scale(12), 20);
    });

    test('KhmerTextScaler equality is based on the wrapped base scaler', () {
      const base1 = TextScaler.linear(1.0);
      const base2 = TextScaler.linear(1.0);
      const base3 = TextScaler.linear(1.2);

      expect(KhmerTextScaler(base1), KhmerTextScaler(base2));
      expect(KhmerTextScaler(base1) == KhmerTextScaler(base3), isFalse);
    });
  });
}
