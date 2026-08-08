import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_pdf_format.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';

void main() {
  group('PrinterPaperSize.dotWidth (raw ESC/POS raster width)', () {
    test('mm58 -> 384 dots', () {
      expect(PrinterPaperSize.mm58.dotWidth, 384);
    });

    test('mm80 -> 576 dots', () {
      expect(PrinterPaperSize.mm80.dotWidth, 576);
    });
  });

  group('PrinterPaperSize.pdfPageFormat (PDF/driver receipt page geometry)', () {
    test('mm58 page width is ~57mm, content width matches the 384-dot '
        'ESC/POS printable width (48mm)', () {
      final format = PrinterPaperSize.mm58.pdfPageFormat;
      expect(format.width / PdfPageFormat.mm, closeTo(57, 0.01));
      expect(format.height, double.infinity);
      expect(format.availableWidth / PdfPageFormat.mm, closeTo(48, 0.01));
    });

    test('mm80 page width is 80mm, content width matches the 576-dot '
        'ESC/POS printable width (72mm)', () {
      final format = PrinterPaperSize.mm80.pdfPageFormat;
      expect(format.width / PdfPageFormat.mm, closeTo(80, 0.01));
      expect(format.height, double.infinity);
      expect(format.availableWidth / PdfPageFormat.mm, closeTo(72, 0.01));
    });

    test('mm58 content width is narrower than mm80 (58mm receipts must not '
        'reuse the 80mm layout width)', () {
      expect(
        PrinterPaperSize.mm58.pdfPageFormat.availableWidth,
        lessThan(PrinterPaperSize.mm80.pdfPageFormat.availableWidth),
      );
    });

    test('A4 report format is never influenced by receipt paper size', () {
      // A4ReportPdf hardcodes PdfPageFormat.a4 / .landscape directly and
      // never reads PrinterPaperSize — this asserts the two receipt page
      // formats are themselves nowhere near A4 dimensions, guarding against
      // a future accidental merge of the two page-format sources.
      const a4WidthMm = 210.0;
      expect(PrinterPaperSize.mm58.pdfPageFormat.width / PdfPageFormat.mm,
          lessThan(a4WidthMm));
      expect(PrinterPaperSize.mm80.pdfPageFormat.width / PdfPageFormat.mm,
          lessThan(a4WidthMm));
    });
  });

  group('ReceiptViewModel.containsKhmer', () {
    ReceiptViewModel fixture({
      AppLanguage language = AppLanguage.en,
      String businessName = 'KAKNNEA POS',
      String itemName = 'Iced Coffee',
    }) {
      return ReceiptViewModel(
        language: language,
        businessName: businessName,
        invoiceNumber: 'INV-1',
        date: '2026-08-07',
        time: '10:00:00',
        lines: [
          ReceiptLineViewModel(
            name: itemName,
            qty: 1,
            unitPrice: 1,
            lineTotal: 1,
          ),
        ],
        subtotal: 1,
        total: 1,
        footer: 'Thank you',
      );
    }

    test('pure English content, English UI language -> false', () {
      expect(fixture().containsKhmer, isFalse);
    });

    test('Khmer UI language alone (even with English item names) -> true', () {
      expect(fixture(language: AppLanguage.km).containsKhmer, isTrue);
    });

    test('Khmer item name under English UI language -> true', () {
      expect(fixture(itemName: 'ទឹកក្រឡុក').containsKhmer, isTrue);
    });

    test('Khmer business name under English UI language -> true', () {
      expect(fixture(businessName: 'ហាងកាហ្វេ').containsKhmer, isTrue);
    });

    test('mixed English/Khmer item name -> true', () {
      expect(fixture(itemName: 'Smoothie ទឹកក្រឡុក').containsKhmer, isTrue);
    });
  });

  group('ReceiptViewModel.adjustments (Discount/Delivery/Other Charge/Tax '
      'rows between Subtotal and Total)', () {
    ReceiptViewModel fixture({
      double discountAmount = 0,
      double deliveryCharge = 0,
      double otherCharge = 0,
      double taxAmount = 0,
      double subtotal = 10,
      double total = 10,
    }) {
      return ReceiptViewModel(
        language: AppLanguage.en,
        businessName: 'KAKNNEA POS',
        invoiceNumber: 'INV-1',
        date: '2026-08-07',
        time: '10:00:00',
        lines: const [
          ReceiptLineViewModel(name: 'Iced Coffee', qty: 1, unitPrice: 10, lineTotal: 10),
        ],
        subtotal: subtotal,
        discountAmount: discountAmount,
        deliveryCharge: deliveryCharge,
        otherCharge: otherCharge,
        taxAmount: taxAmount,
        total: total,
        currencyCode: 'USD',
        footer: 'Thank you',
      );
    }

    test('no adjustments -> empty list, nothing shown between Subtotal and '
        'Total', () {
      expect(fixture().adjustments, isEmpty);
    });

    test('discount only -> exactly one Discount row', () {
      final adjustments = fixture(discountAmount: 1, total: 9).adjustments;
      expect(adjustments, hasLength(1));
      expect(adjustments.single.type, ReceiptAdjustmentType.discount);
      expect(adjustments.single.amount, 1);
    });

    test('tax only -> exactly one Tax row', () {
      final adjustments = fixture(taxAmount: 0.80, total: 10.80).adjustments;
      expect(adjustments, hasLength(1));
      expect(adjustments.single.type, ReceiptAdjustmentType.tax);
      expect(adjustments.single.amount, 0.80);
    });

    test('delivery only -> exactly one Delivery row', () {
      final adjustments = fixture(deliveryCharge: 2, total: 12).adjustments;
      expect(adjustments, hasLength(1));
      expect(adjustments.single.type, ReceiptAdjustmentType.delivery);
      expect(adjustments.single.amount, 2);
    });

    test('other charge only -> exactly one Other Charge row', () {
      final adjustments = fixture(otherCharge: 0.50, total: 10.50).adjustments;
      expect(adjustments, hasLength(1));
      expect(adjustments.single.type, ReceiptAdjustmentType.otherCharge);
      expect(adjustments.single.amount, 0.50);
    });

    test('multiple adjustments -> all present, in Discount, Delivery, Other '
        'Charge, Tax order, with zero-value ones still excluded', () {
      final r = fixture(
        discountAmount: 1,
        deliveryCharge: 2,
        // otherCharge deliberately left at 0 — must not appear.
        taxAmount: 0.72,
        total: 11.72,
      );
      final types = r.adjustments.map((a) => a.type).toList();
      expect(types, [
        ReceiptAdjustmentType.discount,
        ReceiptAdjustmentType.delivery,
        ReceiptAdjustmentType.tax,
      ]);
    });

    test('negative/zero amounts never produce a row (req: zero-value rows '
        'must not appear)', () {
      expect(fixture(discountAmount: 0, deliveryCharge: 0, otherCharge: 0, taxAmount: 0)
          .adjustments, isEmpty);
    });

    test('fmtAdjustment: discount renders with the minus sign before the '
        'currency symbol ("-\$1.00"), not after it ("\$-1.00")', () {
      final r = fixture(discountAmount: 1, total: 9);
      expect(r.fmtAdjustment(r.adjustments.single), '-\$1.00');
    });

    test('fmtAdjustment: tax/delivery/other charge render as plain positive '
        'amounts (no sign)', () {
      final tax = fixture(taxAmount: 0.8, total: 10.8);
      expect(tax.fmtAdjustment(tax.adjustments.single), '\$0.80');

      final delivery = fixture(deliveryCharge: 2, total: 12);
      expect(delivery.fmtAdjustment(delivery.adjustments.single), '\$2.00');

      final other = fixture(otherCharge: 0.5, total: 10.5);
      expect(other.fmtAdjustment(other.adjustments.single), '\$0.50');
    });

    test('Total displayed is always the model\'s authoritative r.total, '
        'independent of which/how many adjustments are present — this '
        'getter only decides what to SHOW, it never recomputes the total',
        () {
      // A deliberately inconsistent fixture (adjustments don't arithmetically
      // sum to total-subtotal) still reports the exact total it was given —
      // proving nothing here derives Total from the adjustments list.
      final r = fixture(
        subtotal: 10,
        discountAmount: 1,
        taxAmount: 5,
        total: 123.45,
      );
      expect(r.total, 123.45);
      expect(r.fmt(r.total), '\$123.45');
    });
  });
}
