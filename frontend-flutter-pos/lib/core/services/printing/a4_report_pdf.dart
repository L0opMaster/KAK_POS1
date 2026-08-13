// Shared A4 report/document PDF builder for the Reports and Inventory
// modules. Every screen just supplies a title, optional subtitle (date
// range/filters), column headers, row data and optional summary lines —
// this handles the business header, Khmer+English font embedding (via
// [KhmerPdfFont], the same one the receipt PDFs use) and page layout, so
// every printed report looks consistent instead of each screen rolling
// its own pw.Document.
//
// Khmer text (title, table headers/rows, summary labels, footer labels) is
// routed through [KhmerTextRasterizer] instead of drawn as `pw.Text` —
// package:pdf's own font-fallback rendering doesn't shape Khmer correctly
// (see khmer_pdf_font.dart's doc comment). English/numeric text is
// unaffected — it stays plain vector `pw.Text`, exactly as before.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../features/pos/services/printing/khmer_pdf_font.dart';
import '../../utils/print_perf.dart';
import 'khmer_text_rasterizer.dart';

class A4ReportPdf {
  A4ReportPdf._();

  /// Builds an A4 PDF: business header, report title/subtitle, an optional
  /// left-aligned block of label/value [details] lines (e.g. a purchase
  /// order's supplier/status/dates — the fields a business document needs
  /// that a plain report never has) above the table of [columns]/[rows],
  /// and an optional right-aligned block of label/value [summary] lines
  /// (e.g. grand totals) beneath it.
  ///
  /// This builder never hardcodes report wording itself — [title],
  /// [columns] and [summary] are supplied by the caller (typically via
  /// `context.l10n`, so English app language produces an English report and
  /// Khmer app language produces a Khmer one). [generatedLabel]/[pageLabel]
  /// are the one exception: they're intrinsic to every A4 report's footer
  /// regardless of content, so they're required params here rather than
  /// being repeated at every call site — callers still supply the localized
  /// text (e.g. `l10n.reportPdfGeneratedLabel`), this class just owns where
  /// in the footer they're placed.
  static Future<Uint8List> build({
    required String title,
    String? subtitle,
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    required List<String> columns,
    required List<List<String>> rows,
    Map<int, pw.Alignment> columnAlignments = const {},
    List<MapEntry<String, String>> summary = const [],
    List<MapEntry<String, String>> details = const [],
    required DateTime generatedAt,
    required String generatedLabel,
    required String pageLabel,
    bool landscape = false,
  }) async {
    final theme =
        await timePrintStage('a4FontLoad', () => KhmerPdfFont.loadTheme());
    final doc = pw.Document(theme: theme);

    // Every piece of text that might be Khmer is rasterized up front —
    // pw.MultiPage's header/footer/build callbacks are synchronous (called
    // during layout/pagination), so this can't happen inside them.
    final rasterized = await timePrintStage('a4RasterizationTotal', () async {
      final businessNameWidget =
          (businessName != null && businessName.isNotEmpty)
              ? await KhmerTextRasterizer.textOrImage(businessName,
                  fontSize: 18, bold: true)
              : null;
      final businessAddressWidget = (businessAddress != null &&
              businessAddress.isNotEmpty)
          ? await KhmerTextRasterizer.textOrImage(businessAddress, fontSize: 10)
          : null;
      final businessPhoneWidget =
          (businessPhone != null && businessPhone.isNotEmpty)
              ? await KhmerTextRasterizer.textOrImage('Tel: $businessPhone',
                  fontSize: 10)
              : null;
      final titleWidget = await KhmerTextRasterizer.textOrImage(title,
          fontSize: 15, bold: true);
      final subtitleWidget = (subtitle != null && subtitle.isNotEmpty)
          ? await KhmerTextRasterizer.textOrImage(subtitle,
              fontSize: 10, color: PdfColors.grey700)
          : null;
      final generatedWidget = await KhmerTextRasterizer.textOrImage(
          '$generatedLabel ${_fmtDateTime(generatedAt)}',
          fontSize: 8,
          color: PdfColors.grey600);
      // pageLabel itself is static (same on every page), but the trailing
      // "N / M" is only known once pw.MultiPage paginates — so only the
      // label word is pre-rasterized; the page-number suffix stays a fresh
      // native pw.Text built inside the footer callback below (always
      // numeric/Latin, never Khmer, so it never needs rasterizing).
      final pageLabelWidget = await KhmerTextRasterizer.textOrImage(pageLabel,
          fontSize: 8, color: PdfColors.grey600);

      final headerCells = await Future.wait(columns.map((c) =>
          KhmerTextRasterizer.textOrImage(c,
              fontSize: 9.5, bold: true, color: PdfColors.white)));
      final rowCells = await Future.wait(rows.map((row) => Future.wait(
          row.map((c) => KhmerTextRasterizer.textOrImage(c, fontSize: 9)))));
      final summaryWidgets = await Future.wait(summary.map((e) async {
        final key =
            await KhmerTextRasterizer.textOrImage('${e.key}: ', fontSize: 11);
        final value = await KhmerTextRasterizer.textOrImage(e.value,
            fontSize: 11, bold: true);
        return MapEntry(key, value);
      }));
      final detailWidgets = await Future.wait(details.map((e) async {
        final key =
            await KhmerTextRasterizer.textOrImage('${e.key}: ', fontSize: 10);
        final value = await KhmerTextRasterizer.textOrImage(e.value,
            fontSize: 10, bold: true);
        return MapEntry(key, value);
      }));

      return (
        businessNameWidget: businessNameWidget,
        businessAddressWidget: businessAddressWidget,
        businessPhoneWidget: businessPhoneWidget,
        titleWidget: titleWidget,
        subtitleWidget: subtitleWidget,
        generatedWidget: generatedWidget,
        pageLabelWidget: pageLabelWidget,
        headerCells: headerCells,
        rowCells: rowCells,
        summaryWidgets: summaryWidgets,
        detailWidgets: detailWidgets,
      );
    });
    final businessNameWidget = rasterized.businessNameWidget;
    final businessAddressWidget = rasterized.businessAddressWidget;
    final businessPhoneWidget = rasterized.businessPhoneWidget;
    final titleWidget = rasterized.titleWidget;
    final subtitleWidget = rasterized.subtitleWidget;
    final generatedWidget = rasterized.generatedWidget;
    final pageLabelWidget = rasterized.pageLabelWidget;
    final headerCells = rasterized.headerCells;
    final rowCells = rasterized.rowCells;
    final summaryWidgets = rasterized.summaryWidgets;
    final detailWidgets = rasterized.detailWidgets;

    doc.addPage(
      pw.MultiPage(
        pageFormat: landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (businessNameWidget != null) businessNameWidget,
            if (businessAddressWidget != null) businessAddressWidget,
            if (businessPhoneWidget != null) businessPhoneWidget,
            pw.SizedBox(height: 14),
            titleWidget,
            if (subtitleWidget != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: subtitleWidget,
              ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.75),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            generatedWidget,
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pageLabelWidget,
                pw.Text(
                  ' ${context.pageNumber} / ${context.pagesCount}',
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          ],
        ),
        build: (context) => [
          if (detailWidgets.isNotEmpty) ...[
            pw.Wrap(
              spacing: 28,
              runSpacing: 6,
              children: detailWidgets
                  .map((e) => pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [e.key, e.value],
                      ))
                  .toList(),
            ),
            pw.SizedBox(height: 14),
          ],
          pw.TableHelper.fromTextArray(
            headers: headerCells,
            data: rowCells,
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
            cellAlignments: columnAlignments,
            headerAlignments: columnAlignments,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          ),
          if (summaryWidgets.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: summaryWidgets
                    .map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [e.key, e.value],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );

    return timePrintStage('a4DocSave', () => doc.save());
  }

  static String _fmtDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
