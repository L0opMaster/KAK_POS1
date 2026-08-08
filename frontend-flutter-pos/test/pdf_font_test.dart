// Regression test for the "Unable to find a font to draw ..." bug: the
// bundled NotoSansKhmer-*.ttf files are a Khmer-only subset (verified
// below) with zero Latin coverage, so KhmerPdfFont must never use them as
// the *only* font. This test locks in both halves of the fix:
//  1. cmap-level: NotoSans (primary) actually covers every required
//     ASCII/punctuation character, and NotoSansKhmer (fallback) actually
//     covers every required Khmer character — read directly from the TTF
//     files, not assumed.
//  2. pipeline-level: KhmerPdfFont.loadTheme() produces a PDF containing
//     English, Khmer, mixed and symbol/digit text without throwing —
//     exercising the exact theme every receipt/report PDF path shares.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:frontend_flutter_pos/core/services/printing/a4_report_pdf.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/khmer_pdf_font.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_pdf_format.dart';
import 'package:frontend_flutter_pos/features/pos/services/printing/printer_profile.dart';

/// Runs [body] inside a zone that captures every `print()` call instead of
/// letting it reach stdout, returning the captured lines. `package:pdf`
/// reports a missing glyph via a plain `print()` inside an `assert(() {...
/// return true; }())` block (pdf's widgets/text.dart) — assert closures run
/// under `flutter test` (asserts are enabled by default there), so this
/// reliably catches the exact warning the app's console showed, rather
/// than inferring its absence from cmap coverage or "didn't throw" alone.
Future<List<String>> capturedPrints(Future<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) => lines.add(line),
    ),
  );
  return lines;
}

/// Minimal TrueType `cmap` (format 4) reader — enough to answer "does this
/// font have a glyph for this codepoint", which is all this regression
/// test needs. Mirrors the manual verification used while diagnosing the
/// bug (no fontTools/similar available in this environment).
Set<int> cmapCodepoints(String path) {
  final bytes = File(path).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  int u16(int off) => data.getUint16(off);
  int u32(int off) => data.getUint32(off);

  final numTables = u16(4);
  int? cmapOffset;
  for (var i = 0; i < numTables; i++) {
    final recOff = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(recOff, recOff + 4));
    if (tag == 'cmap') cmapOffset = u32(recOff + 8);
  }
  if (cmapOffset == null) return {};

  final nSubtables = u16(cmapOffset + 2);
  int? best;
  for (var i = 0; i < nSubtables; i++) {
    final recOff = cmapOffset + 4 + i * 8;
    final platformId = u16(recOff);
    final encodingId = u16(recOff + 2);
    final subtableOff = cmapOffset + u32(recOff + 4);
    final fmt = u16(subtableOff);
    if (platformId == 3 && encodingId == 1 && fmt == 4) {
      best = subtableOff;
    }
    best ??= subtableOff;
  }
  if (best == null) return {};

  final off = best;
  if (u16(off) != 4) return {}; // only format 4 needed for this font set

  final segCountX2 = u16(off + 6);
  final segCount = segCountX2 ~/ 2;
  final endCodeOff = off + 14;
  final startCodeOff = endCodeOff + segCountX2 + 2;

  final codepoints = <int>{};
  for (var s = 0; s < segCount; s++) {
    final end = u16(endCodeOff + s * 2);
    final start = u16(startCodeOff + s * 2);
    if (start <= end && end < 0xFFFF) {
      for (var c = start; c <= end; c++) {
        codepoints.add(c);
      }
    }
  }
  return codepoints;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Bundled font cmap coverage', () {
    const requiredAscii = 'AKaz09\$+-';
    const requiredPunct = '.,:/()—';
    const requiredKhmer = 'កខសរុំ៛';

    test('NotoSans (primary) covers ASCII + punctuation, both weights', () {
      for (final path in [
        'assets/fonts/NotoSans-Regular.ttf',
        'assets/fonts/NotoSans-Bold.ttf',
      ]) {
        final cps = cmapCodepoints(path);
        for (final ch in requiredAscii.codeUnits) {
          expect(cps.contains(ch), isTrue,
              reason: '$path missing ASCII U+${ch.toRadixString(16)} '
                  '(${String.fromCharCode(ch)})');
        }
        for (final ch in requiredPunct.runes) {
          expect(cps.contains(ch), isTrue,
              reason: '$path missing punctuation U+${ch.toRadixString(16)} '
                  '(${String.fromCharCode(ch)})');
        }
      }
    });

    test('NotoSansKhmer (fallback) covers required Khmer characters, both '
        'weights', () {
      for (final path in [
        'assets/fonts/NotoSansKhmer-Regular.ttf',
        'assets/fonts/NotoSansKhmer-Bold.ttf',
      ]) {
        final cps = cmapCodepoints(path);
        for (final ch in requiredKhmer.runes) {
          expect(cps.contains(ch), isTrue,
              reason: '$path missing Khmer U+${ch.toRadixString(16)} '
                  '(${String.fromCharCode(ch)})');
        }
      }
    });

    test('NotoSansKhmer (fallback) does NOT cover ASCII letters/digits — '
        'documents why it must never be the primary/only font', () {
      final cps = cmapCodepoints('assets/fonts/NotoSansKhmer-Regular.ttf');
      for (final ch in 'AKaz09\$+'.codeUnits) {
        expect(cps.contains(ch), isFalse,
            reason:
                'If this ever starts passing, NotoSansKhmer gained Latin '
                'coverage and the primary/fallback split in KhmerPdfFont '
                'may be reconsidered — but do not assume, re-verify.');
      }
    });
  });

  group('KhmerPdfFont.loadTheme() end-to-end PDF generation', () {
    Future<Uint8List> buildTestPdf() async {
      final theme = await KhmerPdfFont.loadTheme();
      final doc = pw.Document(theme: theme);
      doc.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('KAKNNEA POS System'), // regular English
              pw.Text('Sales Summary',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), // bold English
              pw.Text('សួស្តី អរគុណ សរុប រៀល'), // Khmer
              pw.Text('Total សរុប: \$6.50 / 26,650 ៛'), // mixed
              pw.Text(r'$ + - . , : / ( ) —'), // symbols
              pw.Text('0123456789'), // digits
              pw.Text('សរុប', // Khmer under bold style — exercises the
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), // known regular-weight-fallback limitation
            ],
          ),
        ),
      );
      return doc.save();
    }

    test('generates without throwing and produces a non-trivial PDF', () async {
      final bytes = await buildTestPdf();
      expect(bytes.length, greaterThan(1000));
      // PDF files start with the "%PDF-" magic header.
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });

    test('emits zero "Unable to find a font" warnings', () async {
      final prints = await capturedPrints(() async {
        await buildTestPdf();
      });
      final warnings =
          prints.where((l) => l.contains('Unable to find a font')).toList();
      expect(warnings, isEmpty,
          reason: 'package:pdf reported missing glyphs: $warnings');
    });

    test('theme is cached across repeated calls (loaded once)', () async {
      final first = await KhmerPdfFont.loadTheme();
      final second = await KhmerPdfFont.loadTheme();
      expect(identical(first.defaultTextStyle.fontNormal,
          second.defaultTextStyle.fontNormal), isTrue);
    });
  });

  group('Receipt PDF page format x content — the 9 required regression '
      'scenarios', () {
    // Builds via the same primitives PrintService.buildReceiptPdf uses
    // (KhmerPdfFont.loadTheme() + PrinterPaperSize.pdfPageFormat) without
    // needing to construct a full PrintService (which takes an ApiService/
    // Ref it doesn't actually use for PDF rendering) — this exercises the
    // identical font-resolution path production code takes.
    Future<Uint8List> buildReceipt(PrinterPaperSize size, String text) async {
      final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
      doc.addPage(pw.Page(
        pageFormat: size.pdfPageFormat,
        build: (context) => pw.Column(children: [
          pw.Text('KAKNNEA POS System',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(text),
        ]),
      ));
      return doc.save();
    }

    const english = 'Iced Coffee  1 x \$2.50  \$2.50  Total \$2.50';
    const khmer = 'ទឹកកក ១ x ២,៥០\$ សរុប ២,៥០\$ ៛';
    const mixed = 'Smoothie ទឹកក្រឡុក \$3.00 Total សរុប ២៦,៦៥០ ៛';

    for (final size in PrinterPaperSize.values) {
      for (final entry in {
        'English': english,
        'Khmer': khmer,
        'Mixed': mixed,
      }.entries) {
        test(
            '${size.name} ${entry.key} generates cleanly '
            '(no throw, no missing-font warnings)', () async {
          Uint8List? bytes;
          final prints = await capturedPrints(() async {
            bytes = await buildReceipt(size, entry.value);
          });
          expect(bytes!.length, greaterThan(500));
          expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
          final warnings = prints
              .where((l) => l.contains('Unable to find a font'))
              .toList();
          expect(warnings, isEmpty,
              reason: '${size.name} ${entry.key}: $warnings');
        });
      }
    }
  });

  group('A4 report x content — the 9 required regression scenarios (cont.)',
      () {
    const columnsEn = ['Product', 'SKU', 'Qty', 'Value'];
    const columnsKm = ['ផលិតផល', 'SKU', 'ចំនួន', 'តម្លៃ'];

    final scenarios = <String, ({List<String> columns, List<List<String>> rows})>{
      'English': (
        columns: columnsEn,
        rows: [
          ['Iced Coffee', 'SKU-1', '2', '\$5.00'],
          ['Sandwich', 'SKU-2', '1', '\$3.50'],
        ],
      ),
      'Khmer': (
        columns: columnsKm,
        rows: [
          ['កាហ្វេទឹកកក', 'SKU-1', '២', '\$5.00'],
          ['នំបុ័ង', 'SKU-2', '១', '\$3.50'],
        ],
      ),
      'Mixed': (
        columns: const ['Product ផលិតផល', 'SKU', 'Qty', 'Value'],
        rows: [
          ['Smoothie ទឹកក្រឡុក', 'SKU-1', '2', '\$6.00'],
          ['Sandwich សាំងវិច', 'SKU-2', '1', '\$3.50'],
        ],
      ),
    };

    for (final entry in scenarios.entries) {
      test(
          'A4 ${entry.key} report generates cleanly '
          '(no throw, no missing-font warnings)', () async {
        Uint8List? bytes;
        final prints = await capturedPrints(() async {
          bytes = await A4ReportPdf.build(
            title: 'Inventory Report',
            columns: entry.value.columns,
            rows: entry.value.rows,
            generatedAt: DateTime(2026, 8, 7, 12, 0),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          );
        });
        expect(bytes!.length, greaterThan(500));
        expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
        final warnings =
            prints.where((l) => l.contains('Unable to find a font')).toList();
        expect(warnings, isEmpty, reason: 'A4 ${entry.key}: $warnings');
      });
    }
  });
}
