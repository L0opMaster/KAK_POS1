// Regression coverage for: receipt date/time was wrong compared to actual
// local (Cambodia/Phnom_Penh, UTC+07:00) cashier time.
//
// Root cause: Sale.createdAt is java.time.Instant on the backend, sent to
// Flutter via Instant.toString() — always UTC with a trailing 'Z' (e.g.
// "2026-08-11T03:21:00Z"). ReceiptViewModel.fromReceiptResponse used to
// slice that raw string's characters directly (substring(0,10) /
// substring(11,19)) with no timezone conversion at all, displaying the raw
// UTC calendar date and clock time mislabeled as local time — and
// payment_screen.dart's immediate post-payment print button parsed the
// same string with DateTime.parse() but never called .toLocal(), which
// left it flagged UTC and, again, displayed the UTC field values directly.
//
// Fix: core/utils/receipt_date_format.dart's parseBackendTimestamp() is now
// the one place this conversion happens (DateTime.parse(...).toLocal()),
// reused by both call sites, formatted with the existing shared
// formatReceiptDate/formatReceiptTime helpers so preview and reprint can
// never drift into different formats either.
//
// These tests don't hardcode a literal Phnom Penh answer — that would only
// pass on a machine actually configured to Asia/Phnom_Penh (true for this
// sandbox, not guaranteed for every future CI/dev machine). Instead they
// derive the expected local value from the CURRENT runtime's own
// DateTime.now().timeZoneOffset, which proves the UTC -> local conversion
// itself is correct regardless of which zone the test happens to run in —
// the actual business-correctness of "is this device set to Cambodia time"
// is a deployment/OS concern outside what a unit test can assert (see the
// "Model A: device-local timezone" explanation in the accompanying report).
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/core/utils/receipt_date_format.dart';
import 'package:frontend_flutter_pos/features/pos/models/receipt_models.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations_en.dart';

void main() {
  final en = AppLocalizationsEn();

  group('parseBackendTimestamp', () {
    test('converts a UTC Instant.toString() value to local time, not raw UTC',
        () {
      const utcIso = '2026-08-11T03:21:00Z';
      final utcInstant = DateTime.parse(utcIso);
      final offset = DateTime.now().timeZoneOffset;
      final expectedLocal = utcInstant.toUtc().add(offset);

      final result = parseBackendTimestamp(utcIso)!;

      expect(result.year, expectedLocal.year);
      expect(result.month, expectedLocal.month);
      expect(result.day, expectedLocal.day);
      expect(result.hour, expectedLocal.hour);
      expect(result.minute, expectedLocal.minute);
      expect(result.second, expectedLocal.second);
      // The bug this fixes: the raw UTC hour must NOT be what's shown,
      // whenever the local offset actually shifts the clock (true on this
      // sandbox, which is UTC+07:00 — same as the target business zone).
      if (offset != Duration.zero) {
        expect(result.hour, isNot(utcInstant.hour));
      }
    });

    test('a UTC evening timestamp that crosses local midnight shifts the DATE too, not just the time',
        () {
      // Exactly the example from the bug report: 2026-08-10T18:30:00Z is
      // 2026-08-11 01:30:00 in Phnom Penh (UTC+07:00) — a different
      // calendar day, which a naive time-only fix would miss.
      const utcIso = '2026-08-10T18:30:00Z';
      final utcInstant = DateTime.parse(utcIso);
      final offset = DateTime.now().timeZoneOffset;
      final expectedLocal = utcInstant.toUtc().add(offset);

      final result = parseBackendTimestamp(utcIso)!;

      expect(result.day, expectedLocal.day);
      expect(result.hour, expectedLocal.hour);
      expect(result.minute, expectedLocal.minute);
    });

    test('this sandbox is configured to Asia/Phnom_Penh (UTC+07:00) — '
        'demonstrates the exact numbers from the bug report literally',
        () {
      final offset = DateTime.now().timeZoneOffset;
      if (offset != const Duration(hours: 7)) {
        // Don't fail elsewhere; this one test is an illustration, not a
        // portability requirement — the two tests above are the real proof.
        return;
      }
      expect(parseBackendTimestamp('2026-08-11T03:21:00Z'),
          DateTime(2026, 8, 11, 10, 21, 0));
      expect(parseBackendTimestamp('2026-08-10T18:30:00Z'),
          DateTime(2026, 8, 11, 1, 30, 0));
    });

    test('returns null for missing/empty/unparsable input instead of throwing',
        () {
      expect(parseBackendTimestamp(null), isNull);
      expect(parseBackendTimestamp(''), isNull);
      expect(parseBackendTimestamp('not a date'), isNull);
    });
  });

  group('ReceiptViewModel.fromReceiptResponse date/time', () {
    test('uses the local-converted date/time, formatted dd/MM/yyyy and HH:mm:ss — '
        'not the raw UTC ISO substring', () {
      final response = ReceiptResponse(
        saleId: 1,
        createdAt: '2026-08-11T03:21:00Z',
      );
      final vm =
          ReceiptViewModel.fromReceiptResponse(response, AppLanguage.en, en);

      final expected = parseBackendTimestamp(response.createdAt)!;
      expect(vm.date, formatReceiptDate(expected));
      expect(vm.time, formatReceiptTime(expected));

      // Must NOT be the old raw-substring format (ISO "yyyy-MM-dd") — this
      // also regression-tests the preview/reprint format-consistency bug.
      expect(vm.date, isNot('2026-08-11'));
      expect(vm.date, contains('/'));
    });

    test('a reprint (fromReceiptResponse) shows the SAME date/time a fresh '
        'checkout preview would for the identical backend timestamp — no '
        'DateTime.now() drift between the two paths', () {
      const createdAt = '2026-08-11T03:21:00Z';
      final response = ReceiptResponse(saleId: 2, createdAt: createdAt);
      final vm =
          ReceiptViewModel.fromReceiptResponse(response, AppLanguage.en, en);

      // What payment_screen.dart's print button computes for the exact
      // same backend timestamp (see its own parseBackendTimestamp call).
      final dt = parseBackendTimestamp(createdAt)!;
      final previewDate = formatReceiptDate(dt);
      final previewTime = formatReceiptTime(dt);

      expect(vm.date, previewDate);
      expect(vm.time, previewTime);
    });

    test('missing createdAt does not crash and leaves date/time blank-safe',
        () {
      final response = ReceiptResponse(saleId: 3, createdAt: null);
      final vm =
          ReceiptViewModel.fromReceiptResponse(response, AppLanguage.en, en);

      expect(vm.date, '');
      expect(vm.time, '');
    });
  });
}
