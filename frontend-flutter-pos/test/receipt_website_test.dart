// Regression coverage for making the receipt footer's website/link
// configurable (Settings -> Company Profile -> Website) instead of the
// previously hardcoded "www.kaknnea.com" in receipt_paper_view.dart
// (ReceiptContent, shared by the on-screen preview and the Khmer raster
// path) and print_service.dart (_receiptPageContent, the English PDF
// path). Verifies: the configured value reaches every renderer, the OLD
// literal hardcoded string never appears again, and the website line is
// omitted entirely (not a blank/placeholder line) when unset.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/providers/language_provider.dart';
import 'package:frontend_flutter_pos/core/services/api_service.dart';
import 'package:frontend_flutter_pos/features/pos/models/receipt_models.dart';
import 'package:frontend_flutter_pos/features/pos/services/print_service.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/escpos_receipt_builder.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_profile.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_bitmap_renderer.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/receipt_view_model.dart';
import 'package:frontend_flutter_pos/features/pos/widgets/receipt_paper_view.dart';
import 'package:frontend_flutter_pos/l10n/generated/app_localizations_en.dart';
import 'package:image/image.dart' as img;

import 'test_l10n_helper.dart';

/// Decodes the actual rendered text out of a `PrintService`-built PDF.
///
/// Two obstacles stand between "the string is somewhere in `pdfBytes`" and
/// a plain `.contains()` check: (1) page content streams are
/// deflate-compressed by default (`pw.Document`'s `compress: true`), and
/// (2) `KhmerPdfFont.loadTheme()` embeds custom TTF fonts, which
/// `package:pdf` draws using Identity-H double-byte GLYPH INDICES, not
/// literal character bytes — `pw.Text('abc')` does not produce the bytes
/// 'a', 'b', 'c' anywhere in the file. This: (1) decompresses every
/// `stream ... endstream` block it can (skipping ones that aren't zlib,
/// e.g. an embedded raster image), then (2) builds a glyph-index ->
/// Unicode-character map from every embedded font's ToUnicode CMap
/// (`beginbfchar ... endbfchar` — the same mapping PDF-text-extraction
/// tools like `pdftotext` rely on) and uses it to decode every `<hex...>`
/// glyph run in a `Tj`/`TJ` text-showing operator back into real text.
String _decodedPdfText(List<int> pdfBytes) {
  final raw = latin1.decode(pdfBytes, allowInvalid: true);
  final streamsText = StringBuffer();
  final streamStartPattern = RegExp(r'stream\r?\n');
  var searchStart = 0;
  while (true) {
    final match = streamStartPattern.firstMatch(raw.substring(searchStart));
    if (match == null) break;
    final streamStart = searchStart + match.end;
    final streamEnd = raw.indexOf('endstream', streamStart);
    if (streamEnd == -1) break;
    try {
      final decompressed =
          ZLibDecoder().convert(pdfBytes.sublist(streamStart, streamEnd));
      streamsText
        ..write(latin1.decode(decompressed, allowInvalid: true))
        ..write('\n');
    } catch (_) {
      // Not a zlib stream (e.g. an embedded raster image) — skip it.
    }
    searchStart = streamEnd + 'endstream'.length;
  }
  final combined = streamsText.toString();

  final glyphMap = <int, String>{};
  final bfcharBlock = RegExp(r'beginbfchar(.*?)endbfchar', dotAll: true);
  final bfcharEntry = RegExp(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>');
  for (final block in bfcharBlock.allMatches(combined)) {
    for (final entry in bfcharEntry.allMatches(block.group(1)!)) {
      final unicodeHex = entry.group(2)!;
      if (unicodeHex.length == 4) {
        glyphMap[int.parse(entry.group(1)!, radix: 16)] =
            String.fromCharCode(int.parse(unicodeHex, radix: 16));
      }
    }
  }

  final decodedText = StringBuffer();
  final hexRun = RegExp(r'<([0-9A-Fa-f]+)>');
  for (final m in hexRun.allMatches(combined)) {
    final hex = m.group(1)!;
    if (hex.length % 4 != 0) continue; // not an Identity-H glyph-index run
    for (var i = 0; i + 4 <= hex.length; i += 4) {
      final ch = glyphMap[int.parse(hex.substring(i, i + 4), radix: 16)];
      if (ch != null) decodedText.write(ch);
    }
  }
  return decodedText.toString();
}

class _FakeBitmapRenderer extends ReceiptBitmapRenderer {
  @override
  Future<img.Image> renderImage(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async =>
      img.Image(width: paperSize.dotWidth, height: 24);
}

ReceiptViewModel _englishReceipt({String? website}) => ReceiptViewModel(
      language: AppLanguage.en,
      businessName: 'KAKNNEA POS',
      invoiceNumber: 'INV-1',
      date: '2026-08-11',
      time: '10:00:00',
      website: website,
      lines: const [
        ReceiptLineViewModel(
            name: 'Iced Coffee', qty: 1, unitPrice: 1, lineTotal: 1),
      ],
      subtotal: 1,
      total: 1,
      footer: 'Thank you',
    );

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final en = AppLocalizationsEn();

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

  group('ReceiptViewModel — website threading', () {
    test('fromReceiptResponse carries ReceiptResponse.website through', () {
      final response = ReceiptResponse(
        saleId: 1,
        businessName: 'KAKNNEA POS',
        website: 'pos.example.com',
      );
      final vm =
          ReceiptViewModel.fromReceiptResponse(response, AppLanguage.en, en);
      expect(vm.website, 'pos.example.com');
    });

    test('fromReceiptResponse leaves website null when the backend omits it',
        () {
      final response = ReceiptResponse(saleId: 1, businessName: 'KAKNNEA POS');
      final vm =
          ReceiptViewModel.fromReceiptResponse(response, AppLanguage.en, en);
      expect(vm.website, isNull);
    });

    test('fromCart carries the website param through (immediate post-'
        'payment preview path)', () {
      final vm = ReceiptViewModel.fromCart(
        language: AppLanguage.en,
        l10n: en,
        total: 1,
        items: const [],
        paidAmount: 1,
        website: 'pos.example.com',
      );
      expect(vm.website, 'pos.example.com');
    });
  });

  group('ReceiptContent (shared by on-screen preview and Khmer raster)', () {
    testWidgets('renders the configured website', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Material(
          child: ReceiptContent(
              receipt: _englishReceipt(website: 'pos.example.com')),
        ),
      ));
      expect(find.text('pos.example.com'), findsOneWidget);
    });

    testWidgets('renders no website line at all when unset — not blank, '
        'not a placeholder', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Material(
          child: ReceiptContent(receipt: _englishReceipt(website: null)),
        ),
      ));
      expect(find.text(''), findsNothing);
      expect(find.text('www.kaknnea.com'), findsNothing);
    });

    testWidgets('an empty (whitespace-trimmed-empty) website also renders no '
        'line', (tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: testLocalizationsDelegates,
        supportedLocales: testSupportedLocales,
        home: Material(
          child: ReceiptContent(receipt: _englishReceipt(website: '')),
        ),
      ));
      expect(find.text('www.kaknnea.com'), findsNothing);
    });
  });

  group('PrintService — English PDF footer', () {
    late ProviderContainer container;
    late Ref ref;
    setUp(() {
      container = ProviderContainer();
      ref = container.read(_refProvider);
    });
    tearDown(() => container.dispose());

    testWidgets('the configured website appears in the generated PDF',
        (tester) async {
      final ctx = await pumpContext(tester);
      final service = PrintService(container.read(apiServiceProvider), ref,
          bitmapRenderer: _FakeBitmapRenderer());

      final bytes = await tester.runAsync(() => service.buildReceiptPdf(
          _englishReceipt(website: 'pos.example.com'), PrinterPaperSize.mm80,
          context: ctx));

      expect(_decodedPdfText(bytes!).contains('pos.example.com'), isTrue);
    });

    testWidgets(
        'no hardcoded www.kaknnea.com remains, with or without a configured website',
        (tester) async {
      final ctx = await pumpContext(tester);
      final service = PrintService(container.read(apiServiceProvider), ref,
          bitmapRenderer: _FakeBitmapRenderer());

      final withWebsite = await tester.runAsync(() => service.buildReceiptPdf(
          _englishReceipt(website: 'pos.example.com'), PrinterPaperSize.mm80,
          context: ctx));
      final withoutWebsite = await tester.runAsync(() => service
          .buildReceiptPdf(_englishReceipt(website: null), PrinterPaperSize.mm80,
              context: ctx));

      expect(_decodedPdfText(withWebsite!).contains('kaknnea.com'), isFalse);
      expect(
          _decodedPdfText(withoutWebsite!).contains('kaknnea.com'), isFalse);
    });
  });

  group('EscPosReceiptBuilder — native (English) text path', () {
    testWidgets('the configured website reaches the printed bytes as text',
        (tester) async {
      final ctx = await pumpContext(tester);
      final builder = EscPosReceiptBuilder(bitmapRenderer: _FakeBitmapRenderer());

      final bytes = await tester.runAsync(() => builder.build(
          ctx, _englishReceipt(website: 'pos.example.com'), PrinterPaperSize.mm80));

      expect(
          latin1.decode(bytes!, allowInvalid: true).contains('pos.example.com'),
          isTrue);
    });

    testWidgets('no website line (and no hardcoded fallback) when unset',
        (tester) async {
      final ctx = await pumpContext(tester);
      final builder = EscPosReceiptBuilder(bitmapRenderer: _FakeBitmapRenderer());

      final bytes = await tester.runAsync(
          () => builder.build(ctx, _englishReceipt(website: null), PrinterPaperSize.mm80));

      final text = latin1.decode(bytes!, allowInvalid: true);
      expect(text.contains('kaknnea.com'), isFalse);
      // The footer itself must still be there — only the website line is
      // conditional, nothing else about the footer was touched.
      expect(text.contains('Thank you'), isTrue);
    });
  });
}
