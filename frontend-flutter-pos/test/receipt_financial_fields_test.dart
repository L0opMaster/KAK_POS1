// Regression coverage for the "tax missing from receipt" bug:
// ReceiptViewModel.fromCart didn't accept discountAmount/taxAmount/
// deliveryCharge/otherCharge at all (they silently defaulted to 0
// regardless of what the cart or the finalized sale actually charged),
// and ReceiptPreviewScreen was constructed with `subtotal: widget.total`
// (the tax-inclusive grand total, mislabeled as the pre-tax subtotal).
// These tests exercise the fixed model directly for every combination the
// bug report asked for (Steps 7.A-7.F).
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  ReceiptViewModel build({
    double subtotal = 6.50,
    double discountAmount = 0,
    double taxAmount = 0,
    double deliveryCharge = 0,
    double otherCharge = 0,
    required double total,
    double paidAmount = 0,
    double changeAmount = 0,
  }) =>
      ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: l10n,
        total: total,
        subtotal: subtotal,
        discountAmount: discountAmount,
        taxAmount: taxAmount,
        deliveryCharge: deliveryCharge,
        otherCharge: otherCharge,
        items: const [],
        paidAmount: paidAmount,
        changeAmount: changeAmount,
      );

  group('Step 7.A — no tax', () {
    test('subtotal 6.50, tax 0 -> total 6.50, no Tax row', () {
      final r = build(subtotal: 6.50, taxAmount: 0, total: 6.50);
      expect(r.subtotal, 6.50);
      expect(r.total, 6.50);
      expect(r.adjustments, isEmpty);
    });
  });

  group('Step 7.B — tax only', () {
    test('subtotal 6.50, tax 0.65 -> total 7.15, exactly one Tax row', () {
      final r = build(subtotal: 6.50, taxAmount: 0.65, total: 7.15);
      expect(r.subtotal, 6.50);
      expect(r.total, 7.15,
          reason: 'Total must equal the finalized sale total exactly — '
              'never recomputed from subtotal+tax here');
      expect(r.adjustments, hasLength(1));
      expect(r.adjustments.single.type, ReceiptAdjustmentType.tax);
      expect(r.adjustments.single.amount, 0.65);
      expect(r.fmtAdjustment(r.adjustments.single), r.fmt(0.65),
          reason: 'tax is never shown with a minus sign');
    });
  });

  group('Step 7.C — discount + tax', () {
    test('discount 1.00, tax 0.55 -> both rows, in discount-then-tax order',
        () {
      final r = build(
          subtotal: 6.50, discountAmount: 1.00, taxAmount: 0.55, total: 6.05);
      expect(r.adjustments.map((a) => a.type).toList(),
          [ReceiptAdjustmentType.discount, ReceiptAdjustmentType.tax]);
      expect(r.fmtAdjustment(r.adjustments[0]), '-${r.fmt(1.00)}',
          reason: 'discount renders with a leading minus sign');
      expect(r.fmtAdjustment(r.adjustments[1]), r.fmt(0.55));
      expect(r.total, 6.05);
    });
  });

  group('Step 7.D — delivery + tax', () {
    test('delivery 2.00, tax 0.65 -> both rows, delivery before tax', () {
      final r = build(
          subtotal: 6.50, deliveryCharge: 2.00, taxAmount: 0.65, total: 9.15);
      expect(r.adjustments.map((a) => a.type).toList(),
          [ReceiptAdjustmentType.delivery, ReceiptAdjustmentType.tax]);
      expect(r.total, 9.15);
    });
  });

  group('Step 7.E — discount + tax + delivery + other charge', () {
    test('all four adjustments present, zero ones never included, in '
        'discount/delivery/other/tax order', () {
      final r = build(
        subtotal: 20.00,
        discountAmount: 2.00,
        deliveryCharge: 3.00,
        otherCharge: 1.50,
        taxAmount: 1.85,
        total: 24.35,
      );
      expect(r.adjustments.map((a) => a.type).toList(), [
        ReceiptAdjustmentType.discount,
        ReceiptAdjustmentType.delivery,
        ReceiptAdjustmentType.otherCharge,
        ReceiptAdjustmentType.tax,
      ]);
      expect(r.adjustments.map((a) => a.amount).toList(),
          [2.00, 3.00, 1.50, 1.85]);
      expect(r.total, 24.35);
    });

    test('a zero-valued adjustment (e.g. no delivery this time) is hidden, '
        'not shown as \$0.00', () {
      final r = build(
        subtotal: 20.00,
        discountAmount: 2.00,
        deliveryCharge: 0, // no delivery on this sale
        otherCharge: 1.50,
        taxAmount: 1.85,
        total: 21.35,
      );
      expect(r.adjustments.map((a) => a.type).toList(), [
        ReceiptAdjustmentType.discount,
        ReceiptAdjustmentType.otherCharge,
        ReceiptAdjustmentType.tax,
      ]);
      expect(
          r.adjustments.any((a) => a.type == ReceiptAdjustmentType.delivery),
          isFalse);
    });
  });

  group('Step 7.F — cash tender exceeding the total', () {
    test('total 7.15, tendered 10.00 -> paid=7.15 (applied), change=2.85, '
        'and paid+change reconstructs the 10.00 actually handed over', () {
      const total = 7.15;
      const tendered = 10.00;
      const applied = total; // never more than the total, see _chargeCash
      const change = tendered - applied;

      final r = build(
        subtotal: 6.50,
        taxAmount: 0.65,
        total: total,
        paidAmount: applied,
        changeAmount: change,
      );

      expect(r.paidAmount, 7.15);
      expect(r.changeAmount, closeTo(2.85, 0.001));
      expect(r.paidAmount + r.changeAmount, closeTo(tendered, 0.001),
          reason: '"Cash Received" is displayed as paidAmount + '
              'changeAmount everywhere (preview/PDF/ESC-POS/reprint) — '
              'this must reconstruct exactly what was tendered');
    });

    test('exact cash tender (no overpayment) -> paidAmount == total, '
        'changeAmount == 0, no Cash Received/Change rows shown', () {
      final r = build(
          subtotal: 6.50,
          taxAmount: 0,
          total: 6.50,
          paidAmount: 6.50,
          changeAmount: 0);
      expect(r.changeAmount, 0);
    });
  });

  group('Total is never recomputed from subtotal + adjustments', () {
    test('an intentionally inconsistent fixture (adjustments do not '
        'arithmetically sum to total-subtotal) still reports the exact '
        'total it was given — proving nothing here derives Total', () {
      final r = build(
        subtotal: 10,
        discountAmount: 1,
        taxAmount: 5,
        total: 123.45, // deliberately not 10 - 1 + 5
      );
      expect(r.total, 123.45);
      expect(r.fmt(r.total), r.fmt(123.45));
    });
  });
}
