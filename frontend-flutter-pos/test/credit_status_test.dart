import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/features/pos/utils/credit_status.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('creditStatusLabel', () {
    test('maps every known status to a distinct, non-empty label', () {
      const statuses = [
        'OPEN',
        'PARTIALLY_PAID',
        'PAID',
        'OVERDUE',
        'EXPIRED',
        'CANCELLED',
      ];
      final labels = statuses.map((s) => creditStatusLabel(l10n, s)).toSet();
      expect(labels.length, statuses.length,
          reason: 'every status must render as a distinct label');
      for (final label in labels) {
        expect(label, isNotEmpty);
      }
    });

    test('falls back to the raw string for an unrecognized status', () {
      expect(creditStatusLabel(l10n, 'SOMETHING_NEW'), 'SOMETHING_NEW');
    });

    test('returns empty for null', () {
      expect(creditStatusLabel(l10n, null), '');
    });
  });

  group('creditStatusColor', () {
    test('OVERDUE and EXPIRED are red (urgent)', () {
      expect(creditStatusColor('OVERDUE'), PosTheme.errorRed);
      expect(creditStatusColor('EXPIRED'), PosTheme.errorRed);
    });

    test('PAID is green', () {
      expect(creditStatusColor('PAID'), PosTheme.primaryGreen);
    });

    test('OPEN and PARTIALLY_PAID are amber, not red or green', () {
      expect(creditStatusColor('OPEN'), PosTheme.warningAmber);
      expect(creditStatusColor('PARTIALLY_PAID'), PosTheme.warningAmber);
    });
  });
}
