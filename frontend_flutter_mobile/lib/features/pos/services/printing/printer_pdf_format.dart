import 'package:pdf/pdf.dart';

import 'printer_profile.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// printer_pdf_format.dart` — COPY/ADAPT NEARLY EXACTLY, full file. Not
/// `package:pdf`'s built-in `PdfPageFormat.roll57`/`roll80` (flat 5mm
/// margin every side) — these margins are derived from the same dot
/// widths the raw ESC/POS path uses (`PrinterPaperSize.dotWidth`: 384
/// dots for "58mm" stock, 576 for "80mm", both at 8 dots/mm), so a
/// receipt printed via this PDF path and one printed via a future direct
/// thermal transport (Day 15/16) use the same usable content width.
const PdfPageFormat _mm58Format = PdfPageFormat(
  57 * PdfPageFormat.mm,
  double.infinity,
  marginLeft: 4.5 * PdfPageFormat.mm,
  marginRight: 4.5 * PdfPageFormat.mm,
  marginTop: 5 * PdfPageFormat.mm,
  marginBottom: 5 * PdfPageFormat.mm,
);

const PdfPageFormat _mm80Format = PdfPageFormat(
  80 * PdfPageFormat.mm,
  double.infinity,
  marginLeft: 4 * PdfPageFormat.mm,
  marginRight: 4 * PdfPageFormat.mm,
  marginTop: 5 * PdfPageFormat.mm,
  marginBottom: 5 * PdfPageFormat.mm,
);

extension PrinterPaperSizePdfFormat on PrinterPaperSize {
  /// The PDF page format to pass as `pw.Page`'s `pageFormat:`. Do not pass
  /// an explicit `margin:` alongside it — `package:pdf` uses an explicit
  /// `margin` to *replace* (not add to) the page format's own margins.
  PdfPageFormat get pdfPageFormat =>
      this == PrinterPaperSize.mm58 ? _mm58Format : _mm80Format;
}
