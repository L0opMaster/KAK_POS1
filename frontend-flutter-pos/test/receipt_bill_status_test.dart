// Regression coverage for the pre-payment "bill/check" vs. paid "receipt"
// distinction (ReceiptViewModel.isBill): a bill printed from a held ticket
// before any payment exists must never show anything that reads as "Paid"
// (e.g. "Paid: ៛0" — the old, ambiguous behavior every renderer had before
// isBill existed) and must instead show an explicit UNPAID status plus a
// notice to take the bill to the cashier. A normal paid receipt (isBill
// left at its default false) must render exactly as before this feature —
// these tests also guard that regression.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/print_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/escpos_receipt_builder.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  ReceiptViewModel buildReceipt({required bool isBill, required bool isDineIn}) {
    return ReceiptViewModel.fromCart(
      language: AppLanguage.en,
      l10n: l10n,
      total: 29000,
      subtotal: 29000,
      items: const [],
      paidAmount: 0,
      invoiceNumber: '#024',
      tableNumber: 'Table T05',
      // Pinned to a Latin-only currency (matches escpos_receipt_adjustments
      // _test.dart's convention) so this exercises the fast native-text
      // path, not the Khmer bitmap fallback — the default KHR formatting's
      // "៛" Riel glyph isn't Latin-1-encodable and would otherwise crash
      // Generator.row() here regardless of this feature.
      currency: 'USD',
      isBill: isBill,
      isDineIn: isDineIn,
    );
  }

  group('ReceiptViewModel.isBill', () {
    test('defaults to false — every existing call site is unaffected', () {
      final r = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: l10n,
        total: 10,
        items: const [],
        paidAmount: 10,
      );
      expect(r.isBill, isFalse);
      expect(r.isDineIn, isFalse);
    });
  });

  group('EscPosReceiptBuilder — pre-payment bill vs. paid receipt', () {
    late BuildContext capturedContext;

    setUp(() {});

    Future<String> renderText(WidgetTester tester, ReceiptViewModel receipt) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          capturedContext = context;
          return const SizedBox();
        }),
      ));
      // EscPosReceiptBuilder.build loads a real asset (capabilities.json)
      // — that real I/O needs to escape testWidgets' fake-async pump zone
      // via runAsync, or the await never resolves (same reasoning as
      // escpos_receipt_adjustments_test.dart).
      final bytes = await tester.runAsync(() => const EscPosReceiptBuilder()
          .build(capturedContext, receipt, PrinterPaperSize.mm80));
      return latin1.decode(bytes!, allowInvalid: true);
    }

    testWidgets('a bill shows UNPAID and the cashier notice, never "Paid"',
        (tester) async {
      final receipt = buildReceipt(isBill: true, isDineIn: true);
      final text = await renderText(tester, receipt);
      final labels = receipt.labels;

      expect(text.contains(labels.unpaid), isTrue,
          reason: '"UNPAID" must appear on a pre-payment bill');
      expect(text.contains(labels.billCashierNotice), isTrue);
      expect(text.contains(labels.billDisclaimer), isTrue);
      expect(text.contains(labels.paid), isFalse,
          reason:
              'a bill must never print the "Paid" label — even paired with '
              '៛0 that reads as if payment already happened');
      expect(text.contains('TABLE T05'.toUpperCase()), isTrue,
          reason: 'table must be shown in a prominent uppercase block');
      expect(text.contains(labels.dineIn.toUpperCase()), isTrue);
    });

    testWidgets(
        'a paid receipt (isBill: false, the default) is unaffected — no '
        'UNPAID/cashier-notice text, "Paid" still prints', (tester) async {
      final receipt = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: l10n,
        total: 29000,
        subtotal: 29000,
        items: const [],
        paidAmount: 29000,
        invoiceNumber: '#024',
        tableNumber: 'Table T05',
        currency: 'USD',
      );
      final text = await renderText(tester, receipt);
      final labels = receipt.labels;

      expect(text.contains(labels.paid), isTrue,
          reason: 'a normal paid receipt must still show "Paid"');
      expect(text.contains(labels.unpaid), isFalse);
      expect(text.contains(labels.billCashierNotice), isFalse);
      expect(text.contains(labels.billDisclaimer), isFalse);
    });
  });

  group('PrintService.buildReceiptPdf — pre-payment bill', () {
    // PDF content streams are typically compressed, so this doesn't
    // string-search the output the way the ESC/POS test above does (which
    // shares the exact same ReceiptViewModel.isBill/labels branching this
    // PDF path reads from) — it just guards that adding the bill banner/
    // table block/status section didn't break PDF generation outright, for
    // both paper sizes.
    test('renders without throwing, for both paper sizes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final refProvider = Provider<Ref>((ref) => ref);
      final service = PrintService(
          container.read(apiServiceProvider), container.read(refProvider));

      final receipt = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: l10n,
        total: 29000,
        subtotal: 29000,
        items: const [],
        paidAmount: 0,
        invoiceNumber: '#024',
        tableNumber: 'Table T05',
        currency: 'USD',
        isBill: true,
        isDineIn: true,
      );

      for (final paperSize in [PrinterPaperSize.mm58, PrinterPaperSize.mm80]) {
        final bytes = await service.buildReceiptPdf(receipt, paperSize);
        expect(bytes, isNotEmpty);
      }
    });
  });
}
