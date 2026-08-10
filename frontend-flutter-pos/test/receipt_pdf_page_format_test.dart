// Regression coverage for a reported bug: "Khmer receipt PDF becomes wide/
// landscape/A4-like while English stays a correct narrow receipt." This
// file locks in that BOTH paths — English (native pw.Text) and Khmer
// (Flutter-rendered bitmap embedded as pw.Image) — always produce the same
// physical page geometry for a given PrinterPaperSize, using the one
// shared source of truth (`paperSize.pdfPageFormat`,
// printing/printer_pdf_format.dart), and that neither ever produces an A4
// or landscape page — A4 belongs only to A4ReportPdf (core/services/
// printing/a4_report_pdf.dart), never to a receipt.
//
// Uses an injectable fake ReceiptBitmapRenderer (see PrintService's
// `bitmapRenderer` constructor parameter and khmer_receipt_dispatch_test
// .dart) sized to match a real rendered receipt's aspect ratio, so this
// exercises the exact same _khmerImagePageContent width/height/fit math
// production code runs, without needing the real Overlay-based renderer
// (which cannot complete inside `flutter test` — see
// receipt_bitmap_renderer_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/print_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_pdf_format.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_bitmap_renderer.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:image/image.dart' as img;

/// Returns every `/MediaBox [x0 y0 x1 y1]` found in raw PDF bytes — one per
/// physical page — as `[width, height]` pairs (x1-x0, y1-y0).
List<List<double>> pageDimensions(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  final re = RegExp(
      r'/MediaBox\s*\[\s*([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)\s+([\d.\-]+)\s*\]');
  return re.allMatches(text).map((m) {
    final x0 = double.parse(m.group(1)!);
    final y0 = double.parse(m.group(2)!);
    final x1 = double.parse(m.group(3)!);
    final y1 = double.parse(m.group(4)!);
    return [x1 - x0, y1 - y0];
  }).toList();
}

/// A fake renderer sized like a real rendered receipt (narrow, tall — the
/// opposite aspect ratio of A4) instead of mounting a real Overlay.
class _FakeBitmapRenderer extends ReceiptBitmapRenderer {
  @override
  Future<img.Image> renderImage(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async =>
      img.Image(width: paperSize.dotWidth, height: paperSize.dotWidth * 3);
}

ReceiptViewModel _receipt({required bool khmer}) => ReceiptViewModel(
      language: khmer ? AppLanguage.km : AppLanguage.en,
      businessName: khmer ? 'ហាងកាហ្វេ KAKNNEA' : 'KAKNNEA POS',
      invoiceNumber: 'INV-1',
      date: '2026-08-09',
      time: '10:00:00',
      lines: [
        ReceiptLineViewModel(
          name: khmer ? 'ទំនិញ' : 'Iced Coffee',
          qty: 1,
          unitPrice: 1,
          lineTotal: 1,
        ),
      ],
      subtotal: 1,
      total: 1,
      footer: khmer ? 'អរគុណ' : 'Thank you',
    );

const _a4Width = 595.28, _a4Height = 841.89;

void assertNotA4(List<double> dims) {
  final sorted = [...dims]..sort();
  final a4Sorted = [_a4Width, _a4Height]..sort();
  final matchesA4 = (sorted[0] - a4Sorted[0]).abs() < 1 &&
      (sorted[1] - a4Sorted[1]).abs() < 1;
  expect(matchesA4, isFalse,
      reason: 'page dimensions $dims match A4 ($_a4Width x $_a4Height in '
          'either orientation) — a receipt must never be A4');
}

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BuildContext> pumpContext(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ));
    return ctx;
  }

  for (final paperSize in [PrinterPaperSize.mm58, PrinterPaperSize.mm80]) {
    group('${paperSize.name} — English vs Khmer page geometry', () {
      testWidgets(
          'English and Khmer receipts for the same PrinterPaperSize produce '
          'the exact same page width', (tester) async {
        final ctx = await pumpContext(tester);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final service = PrintService(
            container.read(apiServiceProvider), container.read(_refProvider),
            bitmapRenderer: _FakeBitmapRenderer());

        final enBytes =
            await service.buildReceiptPdf(_receipt(khmer: false), paperSize);
        final kmBytes = await service
            .buildReceiptPdf(_receipt(khmer: true), paperSize, context: ctx);

        final enDims = pageDimensions(enBytes).single;
        final kmDims = pageDimensions(kmBytes).single;

        // The shared source of truth both paths must agree with.
        final expectedWidth = paperSize.pdfPageFormat.width;

        expect(enDims[0], closeTo(expectedWidth, 0.5),
            reason:
                'English receipt width must equal paperSize.pdfPageFormat.width');
        expect(kmDims[0], closeTo(expectedWidth, 0.5),
            reason:
                'Khmer receipt width must equal paperSize.pdfPageFormat.width');
        expect(kmDims[0], closeTo(enDims[0], 0.01),
            reason: 'English.pageFormat.width == Khmer.pageFormat.width');

        assertNotA4(enDims);
        assertNotA4(kmDims);

        // A receipt is always taller than it is wide for any reasonable
        // amount of content (portrait) — never the reverse (landscape).
        expect(kmDims[1], greaterThan(kmDims[0]),
            reason: 'Khmer receipt must stay portrait (taller than wide), '
                'not become landscape');
      });

      testWidgets(
          'mixed batch (English, Khmer, English) — every page '
          'shares the same width, none is A4', (tester) async {
        final ctx = await pumpContext(tester);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final service = PrintService(
            container.read(apiServiceProvider), container.read(_refProvider),
            bitmapRenderer: _FakeBitmapRenderer());

        final bytes = await service.buildReceiptsPdf(
          [
            _receipt(khmer: false),
            _receipt(khmer: true),
            _receipt(khmer: false)
          ],
          paperSize,
          context: ctx,
        );

        final pages = pageDimensions(bytes);
        expect(pages, hasLength(3));
        final widths = pages.map((p) => p[0]).toSet();
        expect(widths.length, 1,
            reason: 'every page in a mixed batch must share one page width, '
                'regardless of which receipts are Khmer: $pages');
        expect(widths.single, closeTo(paperSize.pdfPageFormat.width, 0.5));
        for (final p in pages) {
          assertNotA4(p);
        }
      });
    });
  }

  test(
      'sanity check: mm58 and mm80 are themselves genuinely different '
      'widths, and neither is A4', () {
    assertNotA4([PrinterPaperSize.mm58.pdfPageFormat.width, 1000]);
    assertNotA4([PrinterPaperSize.mm80.pdfPageFormat.width, 1000]);
    expect(PrinterPaperSize.mm58.pdfPageFormat.width,
        isNot(closeTo(PrinterPaperSize.mm80.pdfPageFormat.width, 1)));
  });
}
