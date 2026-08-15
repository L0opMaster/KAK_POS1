import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// Ported from `frontend-flutter-pos/lib/features/pos/services/printing/
/// khmer_pdf_font.dart` — COPY/ADAPT NEARLY EXACTLY, full file. The ONE
/// place every `pw.Document`'s theme comes from — no other file should
/// construct its own `pw.ThemeData`/`pw.Font.ttf`.
///
/// Two fonts, not one: NotoSans-Regular/Bold.ttf is PRIMARY (`base`/`bold`
/// — full Latin/digit/punctuation coverage in both weights).
/// NotoSansKhmer-Regular/Bold.ttf is FALLBACK ONLY (`fontFallback`), never
/// primary — this bundled file is a Khmer-script-only subset with *zero*
/// Latin letters, digits, or `$` in either weight; using it as primary (or
/// only) font breaks every plain-English receipt with "Unable to find a
/// font to draw ..." for ordinary ASCII.
///
/// `package:pdf` resolves `TextStyle.fontFallback` per-glyph — for each
/// rune the primary font can't draw, it tries each fallback font in list
/// order. Setting `fontFallback` once here, on the document's `ThemeData`,
/// covers every `pw.Text` in the document via `TextStyle.merge()`.
///
/// Known limitation, not fixable at this layer: the fallback list is NOT
/// weight-aware — bold Latin text that hits a Khmer rune renders that rune
/// in Khmer's regular weight (`_khmerRegular` is listed first), since the
/// fallback loop picks the first fallback font with the glyph, not
/// necessarily a bold variant. Cosmetic mismatch, not a missing-glyph
/// error — both weights are still embedded.
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
      // calls under Future.wait in this exact loading pattern; sequential
      // loads are unaffected, and this only runs once per app session.
      _latinRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
      );
      _latinBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
      );
      _khmerRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKhmer-Regular.ttf'),
      );
      _khmerBold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansKhmer-Bold.ttf'),
      );
    }
    return pw.ThemeData.withFont(
      base: _latinRegular!,
      bold: _latinBold!,
      fontFallback: [_khmerRegular!, _khmerBold!],
    );
  }
}
