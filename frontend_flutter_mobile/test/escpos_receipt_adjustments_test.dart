// Ported from frontend-flutter-pos/test/escpos_receipt_adjustments_test.dart
// — COPY/ADAPT NEARLY EXACTLY.
//
// Regression coverage: EscPosReceiptBuilder._buildLatinText must iterate
// the shared `receipt.adjustments` list (the same list the on-screen
// preview and PDF already use) rather than checking discountAmount/
// taxAmount directly — otherwise a receipt with a delivery charge or an
// "other" service charge would silently never print that row on thermal
// output, even though the same receipt shows it correctly on screen and in
// the PDF. Asserts every non-zero adjustment type actually reaches the
// printed byte stream, in the discount/delivery/other/tax order
// ReceiptViewModel.adjustments defines.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_mobile/core/providers/language_provider.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/escpos_receipt_builder.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_mobile/features/pos/services/printing/receipt_view_model.dart';
import 'package:frontend_flutter_mobile/l10n/generated/app_localizations_en.dart';

void main() {
  testWidgets(
    'a pure-Latin receipt with all 4 adjustment types prints every one '
    'of them on thermal (ESC/POS) output, not just discount/tax',
    (tester) async {
      final l10n = AppLocalizationsEn();
      final receipt = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: l10n,
        total: 24.35,
        subtotal: 20.00,
        discountAmount: 2.00,
        deliveryCharge: 3.00,
        otherCharge: 1.50,
        taxAmount: 1.85,
        items: const [],
        paidAmount: 24.35,
        invoiceNumber: 'TEST-0001',
      );
      expect(
        receipt.containsKhmer,
        isFalse,
        reason: 'this must exercise the fast native-text path, not the '
            'Khmer bitmap fallback',
      );

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox();
            },
          ),
        ),
      );

      // EscPosReceiptBuilder.build loads a real asset (capabilities.json,
      // via CapabilityProfile.load) — that real I/O needs to escape
      // testWidgets' fake-async pump zone via runAsync, or the await never
      // resolves.
      final bytes = await tester.runAsync(
        () => const EscPosReceiptBuilder().build(
          capturedContext,
          receipt,
          PrinterPaperSize.mm80,
        ),
      );
      final text = latin1.decode(bytes!, allowInvalid: true);

      final labels = receipt.labels;
      for (final label in [
        labels.discount,
        labels.delivery,
        labels.otherCharge,
        labels.tax,
      ]) {
        expect(
          text.contains(label),
          isTrue,
          reason: '"$label" row missing from ESC/POS output',
        );
      }

      // Order matters too — discount, delivery, other charge, then tax,
      // matching ReceiptViewModel.adjustments.
      final order = [
        text.indexOf(labels.discount),
        text.indexOf(labels.delivery),
        text.indexOf(labels.otherCharge),
        text.indexOf(labels.tax),
      ];
      expect(
        order,
        equals(order.toList()..sort()),
        reason: 'adjustment rows must print in discount/delivery/other/tax '
            'order',
      );
    },
  );
}
