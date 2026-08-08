// Regression coverage for the report-print row-count bug: the report
// screens paginate for on-screen display (20 rows/page), but Print/Export
// must include every row matching the active filters — not just whatever
// page the screen had loaded. `fetchAllPages` (report_service.dart) is the
// fix: it walks every backend page for the same query and concatenates the
// results. These tests exercise it directly against a fake paginated
// backend (mirroring the real `ReportService.paginate` 200-row hard cap),
// and check that A4ReportPdf actually spans multiple physical PDF pages
// once the row count is large enough that one page can't hold it.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_flutter_pos/core/services/printing/a4_report_pdf.dart';
import 'package:frontend_flutter_pos/features/reports/models/report_models.dart';
import 'package:frontend_flutter_pos/features/reports/services/report_service.dart';

/// A fake paginated backend: `total` rows total, served `pageSize` at a
/// time, computing `totalPages` the same way Spring Data's `Page<T>` does.
/// Used to drive [fetchAllPages] without needing a real HTTP round trip.
class _FakeBackend {
  _FakeBackend(this.total, {this.pageSize = 20});
  final int total;
  final int pageSize;
  int callCount = 0;

  Future<(List<int>, PageMeta)> fetchPage(int page) async {
    callCount++;
    final start = page * pageSize;
    if (start >= total && total > 0) {
      return (
        <int>[],
        PageMeta(
          page: page,
          size: pageSize,
          totalElements: total,
          totalPages: (total / pageSize).ceil(),
        ),
      );
    }
    final end = (start + pageSize).clamp(0, total);
    final rows = List<int>.generate(end - start, (i) => start + i);
    return (
      rows,
      PageMeta(
        page: page,
        size: pageSize,
        totalElements: total,
        totalPages: total == 0 ? 0 : (total / pageSize).ceil(),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fetchAllPages — aggregates every backend page, not just the first',
      () {
    for (final total in [0, 1, 20, 50, 64, 120, 245]) {
      test('$total receipts (20/page from a fake backend) -> all $total '
          'rows are fetched, none dropped, none duplicated', () async {
        final backend = _FakeBackend(total, pageSize: 20);
        final rows = await fetchAllPages<int>(fetchPage: backend.fetchPage);

        expect(rows.length, total,
            reason: 'must fetch every matching row, not just the first '
                'page(s)');
        // Every receipt index 0..total-1 must appear exactly once — proves
        // no gaps and no double-counted rows across the page loop.
        expect(rows.toSet(), Set<int>.from(List.generate(total, (i) => i)));
        expect(rows, List<int>.generate(total, (i) => i),
            reason: 'row order must be preserved across pages');
      });
    }

    test('64 receipts served 200/page (the real backend hard cap) still '
        'returns exactly 64 in a single call', () async {
      final backend = _FakeBackend(64, pageSize: 200);
      final rows = await fetchAllPages<int>(fetchPage: backend.fetchPage);
      expect(rows.length, 64);
      expect(backend.callCount, 1,
          reason: 'one page already covers everything when size >= total');
    });

    test('stops calling fetchPage once totalPages is exhausted (bounded '
        'number of requests, not an infinite loop)', () async {
      final backend = _FakeBackend(64, pageSize: 20);
      await fetchAllPages<int>(fetchPage: backend.fetchPage);
      // 64 rows / 20 per page -> pages 0,1,2,3 (ceil(64/20) = 4).
      expect(backend.callCount, 4);
    });

    test('reportPrintPageSize matches the backend hard cap (200) so print '
        'walks the fewest possible pages instead of relying on an '
        'arbitrarily large single request', () {
      expect(reportPrintPageSize, 200);
    });
  });

  group('A4ReportPdf — 64 rows must produce a genuine multi-page PDF, not '
      'a truncated or squeezed single page', () {
    /// Best-effort physical page count straight from the saved PDF bytes:
    /// each page is its own `/Type /Page` object (the parent `/Type
    /// /Pages` tree node doesn't match this pattern, which is why the char
    /// after `/Page` is excluded). Content streams may be compressed, but
    /// object dictionaries are not, so this is reliable regardless of
    /// row/column text content.
    int pdfPageCount(Uint8List bytes) {
      final text = String.fromCharCodes(bytes);
      return RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
    }

    List<List<String>> rowsFor(int n) => List.generate(
        n, (i) => ['Receipt #${i + 1}', '2026-08-08', 'Cashier', '\$10.00']);

    Future<Uint8List> buildPdf(int n) => A4ReportPdf.build(
          title: 'Receipts',
          subtitle: '2026-08-01 — 2026-08-08',
          columns: const ['Receipt #', 'Date', 'Cashier', 'Net'],
          rows: rowsFor(n),
          summary: [MapEntry('Transactions', '$n')],
          generatedAt: DateTime(2026, 8, 8, 12, 0),
          generatedLabel: 'Generated',
          pageLabel: 'Page',
        );

    test('0 rows -> generates (empty table, no crash), exactly 1 page',
        () async {
      final bytes = await buildPdf(0);
      expect(pdfPageCount(bytes), 1);
    });

    test('1 row -> exactly 1 page', () async {
      final bytes = await buildPdf(1);
      expect(pdfPageCount(bytes), 1);
    });

    test('20 rows -> fits on 1 page', () async {
      final bytes = await buildPdf(20);
      expect(pdfPageCount(bytes), 1);
    });

    test('50 rows -> overflows onto more than 1 page', () async {
      final bytes = await buildPdf(50);
      expect(pdfPageCount(bytes), greaterThan(1));
    });

    test('64 rows -> spans multiple pages, and every page renders (no '
        'thrown error) — the exact reported bug scenario', () async {
      final bytes = await buildPdf(64);
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(pdfPageCount(bytes), greaterThan(1),
          reason: '64 rows must not be squeezed onto a single unreadable '
              'page');
    });

    test('120+ rows -> still generates cleanly across even more pages',
        () async {
      final bytes64 = await buildPdf(64);
      final bytes120 = await buildPdf(120);
      expect(pdfPageCount(bytes120), greaterThanOrEqualTo(pdfPageCount(bytes64)),
          reason: 'more rows must never produce fewer pages');
    });

    test('summary block does not reduce the row-driven page count below '
        'what the same rows without a summary would need', () async {
      final withSummary = await buildPdf(64);
      final withoutSummary = await A4ReportPdf.build(
        title: 'Receipts',
        columns: const ['Receipt #', 'Date', 'Cashier', 'Net'],
        rows: rowsFor(64),
        generatedAt: DateTime(2026, 8, 8, 12, 0),
        generatedLabel: 'Generated',
        pageLabel: 'Page',
      );
      expect(pdfPageCount(withSummary),
          greaterThanOrEqualTo(pdfPageCount(withoutSummary)));
    });
  });
}
