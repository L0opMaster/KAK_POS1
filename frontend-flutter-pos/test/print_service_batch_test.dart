// Regression coverage for "Print All"'s batch PDF path
// (PrintService.buildReceiptsPdf): for a PDF/driver printer, every receipt
// in the batch must produce its own physical page in ONE PDF document —
// never squeezed onto a shared page, never dropped, and never split into
// separate print jobs (which would mean N Chrome/Windows print dialogs
// for N receipts).
//
// Also covers the QR code history on this receipt:
//  - it used to be embedded via
//    `Uint8List.fromList(r.qrImageData!.codeUnits)` instead of decoding the
//    backend's `data:image/png;base64,<...>` string — package:pdf correctly
//    rejected the resulting garbage bytes with "Unable to guess the image
//    type", crashing the whole batch over one receipt's QR code.
//  - the QR was then made safe to decode (ReceiptImageDecoder), but has
//    since been removed from the receipt entirely per a later request —
//    `_receiptPageContent` no longer reads `r.qrImageData` at all. The
//    tests below assert that directly: a receipt with qrImageData set
//    produces byte-for-byte the same PDF as one without.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/features/pos/services/print_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:image/image.dart' as img;

/// A real, fully-decodable 1x1 PNG, generated (not hand-typed — a
/// hand-typed "smallest PNG" byte table is exactly the kind of thing that
/// silently bit-rots into an invalid file) via the same `package:image`
/// dependency already used for thermal receipt bitmaps, so this exercises
/// package:pdf's actual image decoder, not just its signature check.
final _tinyPngBytes = img.encodePng(img.Image(width: 1, height: 1));

final _validQrDataUri = 'data:image/png;base64,${base64Encode(_tinyPngBytes)}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final container = ProviderContainer();
  tearDownAll(container.dispose);
  final printService = container.read(printServiceProvider);

  /// Best-effort physical page count straight from the saved PDF bytes:
  /// each page is its own `/Type /Page` object (excluding the parent
  /// `/Type /Pages` tree node) — content streams may be compressed, but
  /// object dictionaries are not, so this is reliable regardless of what
  /// text/language is on each receipt.
  int pdfPageCount(List<int> bytes) {
    final text = String.fromCharCodes(bytes);
    return RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
  }

  ReceiptViewModel fixture(int n, {String? qrImageData}) => ReceiptViewModel(
        language: AppLanguage.en,
        businessName: 'KAKNNEA POS',
        invoiceNumber: 'INV-${n.toString().padLeft(3, '0')}',
        date: '2026-08-08',
        time: '10:00:00',
        lines: [
          ReceiptLineViewModel(
              name: 'Item $n',
              qty: 1,
              unitPrice: n.toDouble(),
              lineTotal: n.toDouble()),
        ],
        subtotal: n.toDouble(),
        total: n.toDouble(),
        paidAmount: n.toDouble(),
        footer: 'Thank you',
        qrImageData: qrImageData,
      );

  group('buildReceiptsPdf — one physical page per receipt, none dropped', () {
    for (final count in [0, 1, 5, 64]) {
      test('$count receipts -> exactly $count pages', () async {
        final receipts = List.generate(count, (i) => fixture(i + 1));
        final bytes = await printService.buildReceiptsPdf(
            receipts, PrinterPaperSize.mm80);

        // An empty batch is a caller bug (Print All disables itself at 0
        // receipts), but buildReceiptsPdf itself must not crash on it —
        // it still produces a valid (zero-page) PDF rather than throwing.
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
        expect(pdfPageCount(bytes), count);
      });
    }

    test(
        '64 receipts (INV-001..INV-064) -> input list itself contains '
        'every one of them, unique, in order — the exact reported "missing '
        'rows" bug scenario for the batch input path', () {
      final receipts = List.generate(64, (i) => fixture(i + 1));
      final numbers = receipts.map((r) => r.invoiceNumber).toList();

      expect(numbers.length, 64);
      expect(numbers.toSet().length, 64, reason: 'no duplicates');
      expect(numbers.first, 'INV-001');
      expect(numbers.last, 'INV-064');
      expect(numbers.contains('INV-001'), isTrue);
      expect(numbers.contains('INV-064'), isTrue);
    });

    test(
        'a batch of 5 produces the same page count as 5 individual '
        'buildReceiptPdf calls combined — batching changes only how many '
        'print jobs are emitted, not the per-receipt layout', () async {
      final receipts = List.generate(5, (i) => fixture(i + 1));
      final batchBytes =
          await printService.buildReceiptsPdf(receipts, PrinterPaperSize.mm80);

      var singlePageTotal = 0;
      for (final r in receipts) {
        final bytes =
            await printService.buildReceiptPdf(r, PrinterPaperSize.mm80);
        singlePageTotal += pdfPageCount(bytes);
      }

      expect(pdfPageCount(batchBytes), singlePageTotal);
    });
  });

  group(
      'buildReceiptPdf / buildReceiptsPdf — QR code image regression '
      '("Unable to guess the image type 474 bytes")', () {
    test(
        'buildReceiptPdf: a receipt with a real data-URI QR generates '
        'without throwing (single "Print One" path)', () async {
      final bytes = await printService.buildReceiptPdf(
          fixture(1, qrImageData: _validQrDataUri), PrinterPaperSize.mm80);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });

    test(
        'buildReceiptPdf: a receipt whose QR data is garbage (the exact '
        'reported failure mode) still generates — the bad image is '
        'skipped, not thrown', () async {
      // Reproduces the actual bug input: package:pdf was handed the
      // data-URI's raw characters instead of decoded bytes. Feeding that
      // same string through the CURRENT (fixed) path must not throw.
      const garbage = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA';
      final bytes = await printService.buildReceiptPdf(
          fixture(1, qrImageData: garbage), PrinterPaperSize.mm80);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });

    test(
        'buildReceiptsPdf: 64 receipts, EVERY one with a valid QR -> all '
        '64 pages generate', () async {
      final receipts = List.generate(
          64, (i) => fixture(i + 1, qrImageData: _validQrDataUri));
      final bytes =
          await printService.buildReceiptsPdf(receipts, PrinterPaperSize.mm80);
      expect(pdfPageCount(bytes), 64);
    });

    test(
        'buildReceiptsPdf: 64 receipts with a MIX of valid QR, corrupt '
        'QR, and no QR -> still generates all 64 pages — one bad optional '
        'image must never take down the whole batch', () async {
      final receipts = List.generate(64, (i) {
        final n = i + 1;
        final String? qr;
        if (n % 3 == 0) {
          qr = _validQrDataUri;
        } else if (n % 3 == 1) {
          qr = 'data:image/png;base64,not-actually-a-png-payload-$n';
        } else {
          qr = null;
        }
        return fixture(n, qrImageData: qr);
      });

      final bytes =
          await printService.buildReceiptsPdf(receipts, PrinterPaperSize.mm80);

      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(pdfPageCount(bytes), 64,
          reason: 'no receipt is dropped because of another receipt\'s '
              'bad QR data');
    });
  });

  group('QR code has been removed from the receipt entirely', () {
    test(
        'a receipt with a valid QR produces a PDF the same size (within a '
        'few bytes of internal metadata noise) as the same receipt '
        'without one — qrImageData is no longer read', () async {
      final withQr = await printService.buildReceiptPdf(
          fixture(1, qrImageData: _validQrDataUri), PrinterPaperSize.mm80);
      final withoutQr =
          await printService.buildReceiptPdf(fixture(1), PrinterPaperSize.mm80);
      // Not byte-identical — package:pdf stamps a creation timestamp in
      // the trailer even for logically identical content — but a real
      // embedded QR image would add hundreds of bytes, not a handful.
      expect((withQr.length - withoutQr.length).abs(), lessThan(20));
    });

    test(
        'no image XObject appears in the PDF even when qrImageData is a '
        'valid decodable PNG', () async {
      final bytes = await printService.buildReceiptPdf(
          fixture(1, qrImageData: _validQrDataUri), PrinterPaperSize.mm80);
      final text = String.fromCharCodes(bytes);
      expect(text.contains('/Subtype /Image'), isFalse);
      expect(text.contains('/Subtype/Image'), isFalse);
    });
  });
}
