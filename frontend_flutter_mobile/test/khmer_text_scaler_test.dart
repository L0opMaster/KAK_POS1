import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend_flutter_mobile/core/utils/khmer_text_scaler.dart';

void main() {
  group('khmerAwareTextScaler', () {
    test('English (isKhmer: false) returns the base scaler unchanged', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: false);

      expect(identical(result, base), isTrue);
      expect(result.scale(15), 15);
      expect(result.scale(28), 28);
    });

    test('Khmer (isKhmer: true) adds +2px for small text (<20)', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      expect(result.scale(15), 17); // < 20 -> +2
      expect(result.scale(11), 13);
    });

    test('Khmer adds +3px for medium text (20 <= size < 28)', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      expect(result.scale(20), 23);
      expect(result.scale(22), 25);
    });

    test('Khmer leaves large display text (>=28) unchanged', () {
      const base = TextScaler.linear(1.0);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      expect(result.scale(28), 28);
      expect(result.scale(40), 40);
    });

    test('Khmer offset stacks on top of the platform text-scale setting, '
        'not instead of it', () {
      // Simulates a user with a larger system font-size accessibility
      // setting (1.3x) — the Khmer offset must still apply on top.
      const base = TextScaler.linear(1.3);
      final result = khmerAwareTextScaler(base, isKhmer: true);

      final baseScaled = base.scale(15); // 19.5
      expect(result.scale(15), baseScaled + 2);
    });
  });
}
