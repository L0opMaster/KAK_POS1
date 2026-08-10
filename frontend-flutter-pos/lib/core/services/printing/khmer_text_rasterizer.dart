// Renders text containing Khmer script to a PDF-embeddable image using
// Flutter's own text engine (TextPainter — real shaping: correct vowel
// reordering, coeng/subscript stacking), instead of package:pdf's own
// pw.Text + font-fallback rendering, which does not shape Khmer correctly
// (see khmer_pdf_font.dart's doc comment for why — pdf's fontFallback loop
// picks a fallback glyph per-rune, it doesn't run a real text shaper).
//
// Unlike ReceiptBitmapRenderer (which rasterizes a WHOLE receipt document by
// mounting a real widget tree in an Overlay), this rasterizes a single run
// of text with no widget tree/BuildContext/Overlay needed at all —
// TextPainter lays out and paints directly onto a canvas. That distinction
// matters here specifically: an A4 report's table borders, colors and row
// striping must stay real PDF vector drawing (only Khmer TEXT becomes a
// bitmap) — rasterizing the whole document, the way receipts do, would
// throw away the table structure and be far too slow for a 100+ row report.
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../utils/khmer_text.dart';
import '../../utils/print_perf.dart';

/// Thrown when [KhmerTextRasterizer] fails to rasterize a piece of text —
/// a distinct type (not a bare exception) so callers can tell this apart
/// from other PDF-generation failures and log/report it specifically,
/// mirroring [ReceiptRenderException]'s role for the receipt bitmap path.
class KhmerTextRenderException implements Exception {
  const KhmerTextRenderException(this.message);
  final String message;
  @override
  String toString() => message;
}

class KhmerTextRasterizer {
  KhmerTextRasterizer._();

  /// Raster scale — TextPainter lays out in logical pixels; rendering at 4x
  /// and embedding the result at its natural (1x) point size yields ~288
  /// effective dots-per-inch (4 × 72pt/inch) — sharp enough for laser/inkjet
  /// print output. A typical 9pt table-header word rasterizes to only a few
  /// KB, so this stays far short of "huge image" territory even summed
  /// across a full report's worth of cells.
  static const double _rasterScale = 4.0;

  static final Map<String, Future<_RasterizedText>> _cache = {};

  /// [text] as a `pw.Text` (English/numeric — the fast, vector path) if it
  /// contains no Khmer, otherwise as a Flutter-shaped `pw.Image` sized to
  /// match the same visual size a native `pw.Text` at [fontSize] would have
  /// had. Callers never need to branch on script themselves — this is the
  /// one place that decides, exactly mirroring `receipt.containsKhmer`'s
  /// role on the receipt side (same [containsKhmerText] detection).
  ///
  /// Repeated calls with the same (text, fontSize, bold, color) reuse a
  /// cached rasterization — a report's column headers/repeated labels are
  /// rasterized once, not once per page/row.
  static Future<pw.Widget> textOrImage(
    String text, {
    required double fontSize,
    bool bold = false,
    PdfColor color = PdfColors.black,
  }) async {
    if (!containsKhmerText(text)) {
      return pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      );
    }

    final key =
        '$text $fontSize $bold ${color.red}-${color.green}-${color.blue}-${color.alpha}';
    final alreadyCached = _cache.containsKey(key);
    final rasterized = await _cache.putIfAbsent(
        key, () => _rasterize(text, fontSize, bold, color));
    if (alreadyCached) timePrintStageSync('khmerTextCacheHit', () {});
    return pw.Image(rasterized.image,
        width: rasterized.widthPt, height: rasterized.heightPt);
  }

  static Future<_RasterizedText> _rasterize(
    String text,
    double fontSize,
    bool bold,
    PdfColor color,
  ) async {
    return timePrintStage('khmerTextRasterizeTotal', () async {
      final painter = timePrintStageSync('khmerTextLayout', () {
        return TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontFamily: 'NotoSans',
              fontFamilyFallback: const ['NotoSansKhmer'],
              fontSize: fontSize * _rasterScale,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: Color.fromARGB(
                (color.alpha * 255).round(),
                (color.red * 255).round(),
                (color.green * 255).round(),
                (color.blue * 255).round(),
              ),
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
      });

      final width = painter.width.ceil().clamp(1, 1 << 16);
      final height = painter.height.ceil().clamp(1, 1 << 16);

      final uiImage = await timePrintStage('khmerTextPaintToImage', () {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, Offset.zero);
        final picture = recorder.endRecording();
        final image = picture.toImage(width, height);
        picture.dispose();
        return image;
      });
      final byteData = await timePrintStage('khmerTextPngEncode',
          () => uiImage.toByteData(format: ui.ImageByteFormat.png));
      uiImage.dispose();
      if (byteData == null) {
        throw const KhmerTextRenderException(
            'Unable to render Khmer text: failed to encode the rendered image.');
      }

      return _RasterizedText(
        image: pw.MemoryImage(byteData.buffer.asUint8List()),
        widthPt: width / _rasterScale,
        heightPt: height / _rasterScale,
      );
    });
  }

  /// Test-only: clears the rasterization cache so tests don't observe
  /// stale entries from a previous test's font/style combination.
  static void debugClearCache() => _cache.clear();
}

class _RasterizedText {
  const _RasterizedText({
    required this.image,
    required this.widthPt,
    required this.heightPt,
  });
  final pw.MemoryImage image;
  final double widthPt;
  final double heightPt;
}
