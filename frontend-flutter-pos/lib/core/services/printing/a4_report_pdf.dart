// Shared A4 report/document PDF builder for the Reports and Inventory
// modules. Every screen just supplies a title, optional subtitle (date
// range/filters), column headers, row data and optional summary lines —
// this handles the business header, Khmer+English font embedding (via
// [KhmerPdfFont], the same one the receipt PDFs use) and page layout, so
// every printed report looks consistent instead of each screen rolling
// its own pw.Document.
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../features/pos/services/printing/khmer_pdf_font.dart';

class A4ReportPdf {
  A4ReportPdf._();

  /// Builds an A4 PDF: business header, report title/subtitle, a table of
  /// [columns]/[rows], and an optional right-aligned block of
  /// label/value [summary] lines (e.g. grand totals) beneath it.
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
    required DateTime generatedAt,
    required String generatedLabel,
    required String pageLabel,
    bool landscape = false,
  }) async {
    final theme = await KhmerPdfFont.loadTheme();
    final doc = pw.Document(theme: theme);

    doc.addPage(
      pw.MultiPage(
        pageFormat:
            landscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (businessName != null && businessName.isNotEmpty)
              pw.Text(
                businessName,
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            if (businessAddress != null && businessAddress.isNotEmpty)
              pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10)),
            if (businessPhone != null && businessPhone.isNotEmpty)
              pw.Text('Tel: $businessPhone',
                  style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 14),
            pw.Text(
              title,
              style:
                  pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2),
                child: pw.Text(subtitle,
                    style:
                        const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ),
            pw.SizedBox(height: 10),
            pw.Divider(thickness: 0.75),
          ],
        ),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$generatedLabel ${_fmtDateTime(generatedAt)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              '$pageLabel ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: columns,
            data: rows,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9.5,
                color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF2E7D32)),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: columnAlignments,
            headerAlignments: columnAlignments,
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF5F5F5)),
          ),
          if (summary.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: summary
                    .map((e) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Row(
                            mainAxisSize: pw.MainAxisSize.min,
                            children: [
                              pw.Text('${e.key}: ',
                                  style: const pw.TextStyle(fontSize: 11)),
                              pw.Text(
                                e.value,
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static String _fmtDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }
}
