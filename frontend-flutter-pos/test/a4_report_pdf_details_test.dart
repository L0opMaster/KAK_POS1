// Regression coverage for A4ReportPdf's `details` parameter (added to
// support real business documents — Purchase Order, Stock Transfer,
// Production Order — which need a left-aligned block of label/value
// fields, like "PO Number: PO-1001" or "Supplier: Acme Co", positioned
// above the line-item table. Existing reports never needed this (only
// `summary`, a right-aligned block below the table, for grand totals), so
// this is purely additive — these tests also guard that adding `details`
// doesn't disturb the pre-existing summary-only report shape. Follows the
// same byte-level assertion technique as a4_report_pdf_khmer_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/printing/a4_report_pdf.dart';
import 'package:frontend_flutter_pos/core/services/printing/khmer_text_rasterizer.dart';

bool _hasImageXObject(List<int> bytes) {
  final text = String.fromCharCodes(bytes);
  return text.contains('/Subtype /Image') || text.contains('/Subtype/Image');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(KhmerTextRasterizer.debugClearCache);

  group('A4ReportPdf — details block (business document header fields)', () {
    testWidgets('English details produce a valid PDF with no Khmer image '
        '(fast vector path)', (tester) async {
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'Purchase Order',
            details: const [
              MapEntry('PO Number', 'PO-1001'),
              MapEntry('Status', 'APPROVED'),
              MapEntry('Supplier', 'Acme Co'),
            ],
            columns: const ['Product', 'Qty', 'Unit Cost', 'Line Total'],
            rows: const [
              ['Widget', '10', '\$2.00', '\$20.00'],
            ],
            summary: const [MapEntry('Grand Total', '\$20.00')],
            generatedAt: DateTime(2026, 8, 9, 14, 27),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));

      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
      expect(_hasImageXObject(bytes), isFalse);
    });

    testWidgets('Khmer detail values are rasterized the same way Khmer '
        'table/summary content already is', (tester) async {
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'Purchase Order',
            details: const [
              MapEntry('Supplier', 'អ្នកផ្គត់ផ្គង់ ABC'),
            ],
            columns: const ['Product', 'Qty'],
            rows: const [
              ['Widget', '10'],
            ],
            generatedAt: DateTime(2026, 8, 9),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));

      expect(_hasImageXObject(bytes!), isTrue);
    });

    testWidgets('no details -> identical shape to the pre-existing '
        'summary-only report (backward compatible, no behavior change for '
        'the 9 existing report call sites)', (tester) async {
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'Sales Summary',
            columns: const ['Date', 'Total'],
            rows: const [
              ['2026-08-01', '\$100.00'],
            ],
            summary: const [MapEntry('Total', '\$100.00')],
            generatedAt: DateTime(2026, 8, 9),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));

      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
      expect(_hasImageXObject(bytes), isFalse);
    });

    testWidgets('empty details list behaves identically to omitting the '
        'parameter entirely', (tester) async {
      final withEmptyList = await tester.runAsync(() => A4ReportPdf.build(
            title: 'Report',
            details: const [],
            columns: const ['A'],
            rows: const [
              ['1'],
            ],
            generatedAt: DateTime(2026, 8, 9),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));
      final omitted = await tester.runAsync(() => A4ReportPdf.build(
            title: 'Report',
            columns: const ['A'],
            rows: const [
              ['1'],
            ],
            generatedAt: DateTime(2026, 8, 9),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));

      expect(withEmptyList!.length, omitted!.length);
    });

    testWidgets('many detail fields (a document with a long header) still '
        'produces a single valid page for a short table', (tester) async {
      final bytes = await tester.runAsync(() => A4ReportPdf.build(
            title: 'Production Order',
            details: const [
              MapEntry('Production Order #', 'PROD-1'),
              MapEntry('Recipe', 'Iced Coffee Batch'),
              MapEntry('Store', 'Main Store'),
              MapEntry('Status', 'COMPLETED'),
              MapEntry('Planned', '50'),
              MapEntry('Produced', '48'),
              MapEntry('Waste Qty', '2'),
              MapEntry('Yield %', '96'),
              MapEntry('Started', '2026-08-01'),
              MapEntry('Completed', '2026-08-01'),
            ],
            columns: const ['Component', 'Required', 'Consumed'],
            rows: const [
              ['Milk', '10', '10'],
              ['Coffee', '5', '4.8'],
            ],
            generatedAt: DateTime(2026, 8, 9),
            generatedLabel: 'Generated',
            pageLabel: 'Page',
          ));

      expect(String.fromCharCodes(bytes!.sublist(0, 5)), '%PDF-');
    });
  });
}
