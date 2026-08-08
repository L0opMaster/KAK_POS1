// Shared PDF font stack — the ONE place every pw.Document's theme comes
// from: the full itemized receipt (print_service.dart), the lightweight
// post-sale preview (receipt_preview_screen.dart), A4 reports
// (a4_report_pdf.dart) and the developer print test screen. No other file
// should construct its own pw.ThemeData/pw.Font.ttf — route it through
// here so every PDF path shares one verified font stack.
//
// Two fonts, not one — verified by direct cmap-table inspection, not
// assumed:
//
//  - NotoSans-Regular/Bold.ttf — PRIMARY (`base`/`bold`). 2840 codepoints;
//    full coverage of Latin/ASCII, digits, and common punctuation
//    (including the em dash) in both weights.
//  - NotoSansKhmer-Regular/Bold.ttf — FALLBACK ONLY (`fontFallback`), never
//    primary. This specific bundled file is a Khmer-script-only subset:
//    175 codepoints total — the Khmer Unicode block plus a handful of
//    punctuation — and *zero* Latin letters, digits, or `$`, in both
//    weights. Using it as the primary/only font (as this file did
//    previously) breaks every plain-English receipt/report with "Unable to
//    find a font to draw ..." for ordinary ASCII, since ASCII has nowhere
//    to render from in a Khmer-only font. It is correct, and necessary,
//    *only* as a fallback for the runs of text NotoSans itself can't draw.
//
// How the fallback applies document-wide: package:pdf resolves
// TextStyle.fontFallback per-glyph — for each rune the resolved primary
// font can't draw, it tries each font in fontFallback, in list order,
// and uses the first one that has the glyph (pdf's widgets/text.dart,
// `_preProcessSpans`). Setting fontFallback once here, on the document's
// ThemeData, is enough to cover every pw.Text in the document — including
// ones that construct their own explicial `pw.TextStyle(fontSize: ...,
// fontWeight: ...)` without repeating fontFallback themselves — because
// TextStyle.merge() concatenates the ambient theme style's fontFallback
// onto a span's own list (pdf's widgets/text_style.dart, `merge()`).
//
// Known limitation, not fixable at this layer: pdf's fontFallback list is
// NOT weight-aware — when bold Latin text hits a Khmer rune, the fallback
// loop just picks the first fallback font with that glyph, not necessarily
// a bold variant. [_khmerRegular] is listed first (Khmer body text is
// rarely bold in this app — item names, address, footer), so the
// occasional bold+Khmer string (e.g. a Khmer business name) renders in
// Khmer's regular weight rather than true bold. This is a cosmetic
// mismatch, not a missing-glyph error — both weights are still embedded,
// so no character is ever undrawable.
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

class KhmerPdfFont {
  KhmerPdfFont._();

  static pw.Font? _latinRegular;
  static pw.Font? _latinBold;
  static pw.Font? _khmerRegular;
  static pw.Font? _khmerBold;

  static Future<pw.ThemeData> loadTheme() async {
    if (_latinRegular == null ||
        _latinBold == null ||
        _khmerRegular == null ||
        _khmerBold == null) {
      // Sequential, not Future.wait — deliberately. flutter_test's mocked
      // asset bundle does not reliably resolve concurrent rootBundle.load
      // calls (observed returning an empty result list under Future.wait
      // in this exact loading pattern); sequential loads are unaffected
      // and this only runs once per app session anyway (cached above).
      _latinRegular =
          pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
      _latinBold =
          pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));
      _khmerRegular = pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansKhmer-Regular.ttf'));
      _khmerBold = pw.Font.ttf(
          await rootBundle.load('assets/fonts/NotoSansKhmer-Bold.ttf'));
    }
    return pw.ThemeData.withFont(
      base: _latinRegular!,
      bold: _latinBold!,
      fontFallback: [_khmerRegular!, _khmerBold!],
    );
  }
}
