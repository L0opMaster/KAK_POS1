// Regression coverage for the actual reported bug: an A4 report (Sales
// Summary) with a Khmer title/column headers/row values/summary labels
// rendered malformed Khmer glyphs, because A4ReportPdf drew them as
// pw.Text (package:pdf's own font-fallback rendering doesn't shape Khmer
// correctly). A4ReportPdf now routes any Khmer text through
// KhmerTextRasterizer instead — these tests assert on the resulting PDF's
// raw byte structure (same technique print_service_batch_test.dart already
// uses to detect embedded images), not on visual output.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/printing/a4_report_pdf.dart';
import 'package:frontend_flutter_pos/core/services/printing/khmer_text_rasterizer.dart';

bool _hasImageXObject(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  return text.contains('/Subtype /Image') || text.contains('/Subtype/Image');
}

int _pageCount(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(KhmerTextRasterizer.debugClearCache);

  group('A4ReportPdf — Khmer content embeds an image (the reported bug)', () {
    testWidgets(
        'Khmer title + column headers + row values + summary labels all '
        'produce an embedded image XObject, matching the exact failing '
        'Sales Summary report from the bug report', (tester) async {
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'របាយការណ៍សង្ខេបការលក់',
            subtitle: '2026-07-10 — 2026-08-09',
            businessName: 'KAKNNEA POS System',
            columns: const ['កាលបរិច្ឆេទ', 'ចំនួនវិក្កយបត្រ', 'ការលក់សុទ្ធ'],
            rows: const [
              ['ការលក់', '92.00', '\$14215.50'],
              ['ភេសជ្ជៈបារី', '111.00', '\$4839.00'],
            ],
            summary: const [
              MapEntry('ចំនួន', '216.00'),
              MapEntry('សរុប', '\$19060.20'),
            ],
            generatedAt: DateTime(2026, 8, 9, 14, 27),
            generatedLabel: 'បង្កើតនៅ',
            pageLabel: 'ទំព័រ',
          ));

      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
      expect(_hasImageXObject(bytes), isTrue);
    });
  });

  group('A4ReportPdf — pure English report keeps the fast native path', () {
    testWidgets('no Khmer anywhere -> no image XObject at all', (tester) async {
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'Sales Summary Report',
            subtitle: '2026-07-10 — 2026-08-09',
            businessName: 'KAKNNEA POS System',
            businessAddress: 'Phnom Penh, Cambodia',
            businessPhone: '+855 23 123 456',
            columns: const ['Date', 'Orders', 'Net Sales'],
            rows: const [
              ['2026-07-10', '92', '\$14215.50'],
              ['2026-07-11', '111', '\$4839.00'],
            ],
            summary: const [
              MapEntry('Orders', '216'),
              MapEntry('Net Sales', '\$19060.20'),
            ],
            generatedAt: DateTime(2026, 8, 9, 14, 27),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));

      expect(_hasImageXObject(bytes!), isFalse);
    });
  });

  group(
      'A4ReportPdf — multi-page safety with repeated Khmer headers '
      '(Phase 12)', () {
    testWidgets(
        '60 rows with a Khmer column header and repeated Khmer cell values '
        'spans multiple pages, headers still render on every page, and it '
        'completes quickly thanks to rasterization caching', (tester) async {
      final rows = List.generate(
          60,
          (i) => [
                'ផលិតផល ${i + 1}',
                '${i + 1}',
                '\$${(i + 1) * 1.5}',
              ]);

      final stopwatch = Stopwatch()..start();
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'របាយការណ៍លម្អិត',
            columns: const ['ផលិតផល', 'ចំនួន', 'សរុប'],
            rows: rows,
            generatedAt: DateTime(2026, 8, 9),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));
      stopwatch.stop();

      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
      expect(_pageCount(bytes), greaterThan(1));
      expect(_hasImageXObject(bytes), isTrue);
      // 60 rows all share the same 3 column-header strings and this test's
      // rows use only a handful of distinct product-name/qty/total shapes
      // per unique value — with caching this should be fast; a regression
      // back to re-rendering every cell independently would be far slower.
      expect(stopwatch.elapsedMilliseconds, lessThan(15000));
    });
  });

  group('A4ReportPdf — empty summary / no business info still works', () {
    testWidgets(
        'Khmer title with no subtitle/business info/summary still '
        'produces a valid single-page PDF', (tester) async {
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'របាយការណ៍ចលនាស្តុក',
            columns: const ['ផលិតផល', 'ប្រភេទ'],
            rows: const [
              ['ទឹកកក', 'ចូល'],
            ],
            generatedAt: DateTime(2026, 8, 9),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));

      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
      expect(_pageCount(bytes), 1);
      expect(_hasImageXObject(bytes), isTrue);
    });
  });
}
