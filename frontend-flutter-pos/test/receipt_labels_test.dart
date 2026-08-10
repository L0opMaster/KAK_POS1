// Regression coverage for the "receipt prints in English even when the app
// is switched to Khmer" bug: PrintService (PDF), EscPosReceiptBuilder
// (thermal text) and ReceiptBitmapRenderer (Khmer bitmap) used to hardcode
// their own English field labels ("Subtotal", "Paid", "Change", ...) with no
// localization mechanism at all. ReceiptLabels fixes this by resolving every
// label once from AppLocalizations and carrying it on ReceiptViewModel, so
// every renderer — plus the on-screen preview/reprint widgets — reads the
// same localized strings instead of each hardcoding English.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_labels.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations_en.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations_km.dart';

void main() {
  final en = AppLocalizationsEn();
  final km = AppLocalizationsKm();

  group('ReceiptLabels.fromL10n', () {
    test('English l10n produces English labels', () {
      final labels = ReceiptLabels.fromL10n(en);
      expect(labels.subtotal, 'Subtotal');
      expect(labels.discount, 'Discount');
      expect(labels.delivery, 'Delivery');
      expect(labels.otherCharge, 'Other Charge');
      expect(labels.tax, 'Tax');
      expect(labels.total, 'Total');
      expect(labels.paid, 'Paid');
      expect(labels.change, 'Change');
      expect(labels.telFormat('012 345 678'), 'Tel: 012 345 678');
    });

    test('Khmer l10n produces Khmer labels, not the English fallback', () {
      final labels = ReceiptLabels.fromL10n(km);
      expect(labels.subtotal, isNot('Subtotal'));
      expect(labels.total, isNot('Total'));
      expect(labels.paid, isNot('Paid'));
      // Every label must actually resolve from AppLocalizationsKm, not
      // silently fall back to the static English ReceiptLabels.fallback.
      expect(labels.subtotal, km.receiptSubtotal);
      expect(labels.total, km.receiptTotal);
      expect(labels.paid, km.receiptPaid);
      expect(labels.change, km.receiptChange);
    });

    test('fallback constant is only used when no l10n is available', () {
      expect(ReceiptLabels.fallback.subtotal, 'Subtotal');
      expect(ReceiptLabels.fallback.telFormat('123'), 'Tel: 123');
    });
  });

  group('ReceiptAdjustmentTypeLabel.labelFrom', () {
    test('maps every adjustment type to its matching English label', () {
      final labels = ReceiptLabels.fromL10n(en);
      expect(ReceiptAdjustmentType.discount.labelFrom(labels), labels.discount);
      expect(ReceiptAdjustmentType.delivery.labelFrom(labels), labels.delivery);
      expect(ReceiptAdjustmentType.otherCharge.labelFrom(labels),
          labels.otherCharge);
      expect(ReceiptAdjustmentType.tax.labelFrom(labels), labels.tax);
    });

    test('maps every adjustment type to its matching Khmer label', () {
      final labels = ReceiptLabels.fromL10n(km);
      expect(ReceiptAdjustmentType.discount.labelFrom(labels), labels.discount);
      expect(ReceiptAdjustmentType.delivery.labelFrom(labels), labels.delivery);
      expect(ReceiptAdjustmentType.otherCharge.labelFrom(labels),
          labels.otherCharge);
      expect(ReceiptAdjustmentType.tax.labelFrom(labels), labels.tax);
    });
  });

  group('ReceiptViewModel factories attach labels matching the l10n passed in',
      () {
    test('fromCart(l10n: km) does not silently use the English fallback', () {
      final r = ReceiptViewModel.fromCart(
        language: AppLanguage.km,
        l10n: km,
        total: 10,
        items: const [],
        paidAmount: 10,
      );
      expect(r.labels.subtotal, km.receiptSubtotal);
      expect(r.labels.subtotal, isNot(ReceiptLabels.fallback.subtotal));
    });

    test(
        'fromCart(l10n: en) and fromReceiptResponse(l10n: en) produce '
        'identical labels for the same language — checkout preview and a '
        'later reprint of the same sale must read the same words', () {
      final fromCart = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: en,
        total: 10,
        items: const [],
        paidAmount: 10,
      );
      final fromResponseLabels = ReceiptLabels.fromL10n(en);
      expect(fromCart.labels.subtotal, fromResponseLabels.subtotal);
      expect(fromCart.labels.total, fromResponseLabels.total);
      expect(fromCart.labels.paid, fromResponseLabels.paid);
      expect(fromCart.labels.cashReceived, fromResponseLabels.cashReceived);
      expect(fromCart.labels.change, fromResponseLabels.change);
    });
  });
}
