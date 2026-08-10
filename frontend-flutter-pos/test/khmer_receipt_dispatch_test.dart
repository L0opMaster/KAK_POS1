// Regression coverage for "does the printing pipeline actually pick the
// image path for Khmer content, and only for Khmer content" (Phase 6/9/10
// of the Khmer-safe-printing task) — without depending on
// ReceiptBitmapRenderer's real off-screen widget rendering, which needs a
// live Overlay + frame pump and is covered by its own (narrower) test file.
// Both EscPosReceiptBuilder and PrintService accept an injectable
// ReceiptBitmapRenderer for exactly this reason: substitute a fake that
// returns a trivial image instantly, and assert on WHETHER it was called
// and what bytes/PDF structure resulted — proving the dispatch wiring
// (containsKhmer → bitmap; otherwise → native) without needing to also
// exercise real Khmer text shaping in this test.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/print_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/escpos_receipt_builder.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_bitmap_renderer.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:image/image.dart' as img;

class _FakeBitmapRenderer extends ReceiptBitmapRenderer {
  int renderCalls = 0;
  int renderImageCalls = 0;

  @override
  Future<img.Image> render(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async {
    renderCalls++;
    return img.Image(width: paperSize.dotWidth, height: 24);
  }

  @override
  Future<img.Image> renderImage(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async {
    renderImageCalls++;
    return img.Image(width: paperSize.dotWidth, height: 24);
  }
}

/// Substring search for a contiguous byte sequence — used to look for the
/// ESC/POS "GS v 0" raster-image command header (0x1D 0x76 0x30) in built
/// bytes, proving the bitmap path (not native text) was used.
bool _containsBytes(List<int> haystack, List<int> needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }
  return false;
}

const _gsV0RasterHeader = [0x1D, 0x76, 0x30];

ReceiptViewModel _receipt({required bool khmer}) => ReceiptViewModel(
      language: khmer ? AppLanguage.km : AppLanguage.en,
      businessName: khmer ? 'ហាងកាហ្វេ' : 'KAKNNEA POS',
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

  group('EscPosReceiptBuilder dispatch (Phase 6/9/10)', () {
    testWidgets(
        'English receipt: native text path, bitmap renderer never called',
        (tester) async {
      final ctx = await pumpContext(tester);
      final fake = _FakeBitmapRenderer();
      final builder = EscPosReceiptBuilder(bitmapRenderer: fake);
      final receipt = _receipt(khmer: false);
      expect(receipt.containsKhmer, isFalse);

      final bytes = await tester
          .runAsync(() => builder.build(ctx, receipt, PrinterPaperSize.mm80));

      expect(fake.renderCalls, 0);
      expect(_containsBytes(bytes!, _gsV0RasterHeader), isFalse);
      // The receipt's own footer text ("Thank you") reaches the byte
      // stream directly as ASCII — proof it's native text, not an image.
      expect(latin1.decode(bytes, allowInvalid: true).contains('Thank you'),
          isTrue);
    });

    testWidgets('Khmer receipt: bitmap path, renderer called exactly once',
        (tester) async {
      final ctx = await pumpContext(tester);
      final fake = _FakeBitmapRenderer();
      final builder = EscPosReceiptBuilder(bitmapRenderer: fake);
      final receipt = _receipt(khmer: true);
      expect(receipt.containsKhmer, isTrue);

      final bytes = await tester
          .runAsync(() => builder.build(ctx, receipt, PrinterPaperSize.mm80));

      expect(fake.renderCalls, 1);
      expect(_containsBytes(bytes!, _gsV0RasterHeader), isTrue);
    });

    testWidgets(
        'Mixed English/Khmer receipt (Khmer UI language, English item name): '
        'still routes through the bitmap path', (tester) async {
      final ctx = await pumpContext(tester);
      final fake = _FakeBitmapRenderer();
      final builder = EscPosReceiptBuilder(bitmapRenderer: fake);
      final receipt = ReceiptViewModel(
        language: AppLanguage.km,
        businessName: 'KAKNNEA POS',
        invoiceNumber: 'INV-1',
        date: '2026-08-09',
        time: '10:00:00',
        lines: const [
          ReceiptLineViewModel(
              name: 'Iced Coffee', qty: 1, unitPrice: 1, lineTotal: 1),
        ],
        subtotal: 1,
        total: 1,
        footer: 'Thank you',
      );
      expect(receipt.containsKhmer, isTrue);

      final bytes = await tester
          .runAsync(() => builder.build(ctx, receipt, PrinterPaperSize.mm80));

      expect(fake.renderCalls, 1);
      expect(_containsBytes(bytes!, _gsV0RasterHeader), isTrue);
    });
  });

  group(
      'ThermalPrinterService.printReceipts — mixed batch dispatch '
      '(Phase 10)', () {
    testWidgets(
        'a batch of English/Khmer/English/Khmer receipts calls the bitmap '
        'renderer exactly twice — once per Khmer receipt, in one pass',
        (tester) async {
      final ctx = await pumpContext(tester);
      final fake = _FakeBitmapRenderer();
      final builder = EscPosReceiptBuilder(bitmapRenderer: fake);
      final receipts = [
        _receipt(khmer: false),
        _receipt(khmer: true),
        _receipt(khmer: false),
        _receipt(khmer: true),
      ];

      // Mirrors ThermalPrinterService.printReceipts' own loop (connect,
      // build each receipt in order, write, disconnect) without needing a
      // real PrinterTransport — this test is specifically about per-receipt
      // strategy selection across a batch, which is decided entirely inside
      // EscPosReceiptBuilder.build, called once per receipt either way.
      for (final r in receipts) {
        await tester
            .runAsync(() => builder.build(ctx, r, PrinterPaperSize.mm80));
      }

      expect(fake.renderCalls, 2);
    });
  });

  group('PrintService Khmer PDF embedding (Phase 11)', () {
    late ProviderContainer container;
    late Ref ref;

    setUp(() {
      container = ProviderContainer();
      ref = container.read(_refProvider);
    });
    tearDown(() => container.dispose());

    testWidgets(
        'English receipt PDF: no image XObject — native pw.Text path kept',
        (tester) async {
      final ctx = await pumpContext(tester);
      final fake = _FakeBitmapRenderer();
      final service = PrintService(container.read(apiServiceProvider), ref,
          bitmapRenderer: fake);

      final bytes = await tester.runAsync(() => service.buildReceiptPdf(
          _receipt(khmer: false), PrinterPaperSize.mm80,
          context: ctx));

      expect(fake.renderImageCalls, 0);
      final text = String.fromCharCodes(bytes!);
      expect(text.contains('/Subtype /Image'), isFalse);
      expect(text.contains('/Subtype/Image'), isFalse);
    });

    testWidgets(
        'Khmer receipt PDF with context: embeds an image XObject (Flutter-'
        'rendered bitmap), does not rely on pw.Text Khmer shaping',
        (tester) async {
      final ctx = await pumpContext(tester);
      final fake = _FakeBitmapRenderer();
      final service = PrintService(container.read(apiServiceProvider), ref,
          bitmapRenderer: fake);

      final bytes = await tester.runAsync(() => service.buildReceiptPdf(
          _receipt(khmer: true), PrinterPaperSize.mm80,
          context: ctx));

      expect(fake.renderImageCalls, 1);
      final text = String.fromCharCodes(bytes!);
      expect(
          text.contains('/Subtype /Image') || text.contains('/Subtype/Image'),
          isTrue);
    });

    testWidgets(
        'Khmer receipt PDF WITHOUT a context: falls back to the pw.Text '
        'path (still produces a valid PDF) rather than failing to render',
        (tester) async {
      final fake = _FakeBitmapRenderer();
      final service = PrintService(container.read(apiServiceProvider), ref,
          bitmapRenderer: fake);

      final bytes = await tester.runAsync(() => service.buildReceiptPdf(
          _receipt(khmer: true), PrinterPaperSize.mm80));

      expect(fake.renderImageCalls, 0);
      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
    });

    testWidgets(
        'buildReceiptsPdf: mixed batch renders the bitmap only for the '
        'Khmer receipts in the batch', (tester) async {
      final ctx = await pumpContext(tester);
      final fake = _FakeBitmapRenderer();
      final service = PrintService(container.read(apiServiceProvider), ref,
          bitmapRenderer: fake);

      final bytes = await tester.runAsync(() => service.buildReceiptsPdf([
            _receipt(khmer: false),
            _receipt(khmer: true),
            _receipt(khmer: false)
          ], PrinterPaperSize.mm80, context: ctx));

      expect(fake.renderImageCalls, 1);
      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
    });
  });
}
