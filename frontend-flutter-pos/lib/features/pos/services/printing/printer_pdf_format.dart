// Single source of truth for "what PDF page geometry does a receipt use".
// Every PDF-driver receipt path (the full itemized receipt in
// print_service.dart, the lightweight post-sale preview in
// receipt_preview_screen.dart) must read [PrinterPaperSize.pdfPageFormat]
// instead of hardcoding a page format, so the on-screen preview and the
// actual print job can never drift out of sync, and so a store's configured
// paper size (Settings → Printers) is honored by the PDF path exactly like
// it already is by the raw ESC/POS path (see [PrinterPaperSize.dotWidth]).
//
// A4 report printing (see core/services/printing/a4_report_pdf.dart) does
// NOT import this file and has no reference to [PrinterPaperSize] — A4 page
// geometry is fixed and must never be influenced by the receipt printer's
// configured paper size.
import 'package:pdf/pdf.dart';

import 'printer_profile.dart';

/// Receipt PDF page format, deliberately NOT `package:pdf`'s built-in
/// `PdfPageFormat.roll57`/`roll80` — those default to a flat 5mm margin on
/// every side, which doesn't match this app's other receipt pipeline (raw
/// ESC/POS via [PrinterPaperSize.dotWidth]: 384 dots for "58mm" stock, 576
/// for "80mm", both at the standard 8 dots/mm thermal head resolution).
/// Deriving the PDF margins from those same dot widths means a receipt
/// printed via the PDF/driver transport and one printed via direct thermal
/// use the *same* usable content width, not two different ones:
///
///  - "58mm" stock: nominal roll width is commonly ~57mm (not a literal
///    58.0mm — this matches `pdf`'s own `roll57` constant), printable width
///    384 dots ÷ 8 dots/mm = 48mm → 4.5mm margin each side.
///  - "80mm" stock: roll width is genuinely 80mm, printable width
///    576 dots ÷ 8 dots/mm = 72mm → 4mm margin each side.
///
/// Top/bottom margin (5mm) is unconstrained by dot width (paper feed, not
/// head width) and matches `pdf`'s own roll defaults.
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
  /// The PDF page format to pass as `pw.Page`/`pw.MultiPage`'s
  /// `pageFormat:` for this paper size. Do not pass an explicit `margin:`
  /// alongside it — `package:pdf` uses an explicit `margin` to *replace*
  /// (not add to) the page format's own margins, so passing both would
  /// silently discard the printable-width tuning here.
  PdfPageFormat get pdfPageFormat =>
      this == PrinterPaperSize.mm58 ? _mm58Format : _mm80Format;
}
