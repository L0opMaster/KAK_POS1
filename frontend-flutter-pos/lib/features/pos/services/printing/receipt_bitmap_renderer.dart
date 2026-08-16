import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../../../core/utils/print_perf.dart';
import '../../widgets/receipt_paper_view.dart';
import 'printer_profile.dart';
import 'receipt_view_model.dart';

/// Thrown when [ReceiptBitmapRenderer] fails to rasterize a receipt.
///
/// Deliberately a distinct type (not a bare [StateError]) so callers can
/// tell "the Khmer bitmap render itself failed" apart from other print
/// failures (printer not connected, network error, ...) and surface a
/// specific message instead of a generic "print failed" — and, just as
/// importantly, so there is no path that catches this generically and
/// silently falls back to sending raw Khmer text to printer firmware.
class ReceiptRenderException implements Exception {
  const ReceiptRenderException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Renders a [ReceiptViewModel] to a raster image, for thermal printers that
/// can't render Khmer glyphs natively (and, via [render], for embedding into
/// a Khmer PDF/driver receipt — see `print_service.dart`).
///
/// The trick: build the receipt as an ordinary Flutter widget tree (using
/// the bundled NotoSansKhmer font), mount it off-screen via a real
/// [OverlayEntry] positioned far outside the viewport, and rasterize it with
/// `RenderRepaintBoundary.toImage`. Because it's a real, attached widget
/// subtree, Flutter's own text shaping engine does the hard part (Khmer
/// glyph selection, reordering, stacking) — this never has to reimplement
/// font rendering.
class ReceiptBitmapRenderer {
  const ReceiptBitmapRenderer();

  /// Renders [receipt] at the given paper width and returns a decoded,
  /// full-quality (undithered) [img.Image] — the raw rasterization, with no
  /// assumption made yet about what it's for. [render] dithers this for
  /// thermal use; `print_service.dart`'s Khmer PDF embedding uses this
  /// directly, since a PDF viewer/driver renders grayscale/antialiased text
  /// natively and doesn't need (or want — dithering looks noisy on screen)
  /// the 1-bit conversion thermal raster printing requires.
  ///
  /// Requires a [BuildContext] with an [Overlay] ancestor (any screen
  /// context works — the app always has a root `Navigator`/`Overlay`).
  Future<img.Image> renderImage(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) {
    return renderWidgetImage(context, ReceiptContent(receipt: receipt), paperSize);
  }

  /// [renderImage], generalized to an arbitrary [child] widget instead of a
  /// [ReceiptViewModel] — same off-screen-mount-and-rasterize machinery,
  /// just not hard-coded to [ReceiptContent]. Added for the lightweight,
  /// non-receipt tickets (queue-number ticket, credit payment stub — see
  /// `print_service.dart`) that need a single Khmer field rendered as a
  /// bitmap but have no [ReceiptViewModel] behind them to build one from.
  ///
  /// Requires a [BuildContext] with an [Overlay] ancestor (any screen
  /// context works — the app always has a root `Navigator`/`Overlay`).
  Future<img.Image> renderWidgetImage(
    BuildContext context,
    Widget child,
    PrinterPaperSize paperSize,
  ) async {
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);

    // Mount at the exact same logical width the on-screen preview renders
    // [ReceiptContent] at (see receipt_paper_view.dart) — an *explicit*
    // width, not anything inherited from the Overlay/screen, so this can
    // never accidentally pick up desktop/full-screen/A4 width. Previously
    // this mounted a completely different, hand-duplicated widget
    // (`_ReceiptDocument`) at `paperSize.dotWidth` logical px (384/576 —
    // roughly double the preview's 300), which is why the Khmer PDF used to
    // look structurally different and much wider than the preview. The
    // printer's dot width is a *pixel* target, not a layout width — it's
    // reached below via `pixelRatio`, not by stretching the widget itself.
    const logicalWidth = kReceiptContentWidth;
    final pixelRatio = paperSize.dotWidth / logicalWidth;
    double? measuredMaxWidth;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: -100000,
        top: 0,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            color: Colors.white,
            child: RepaintBoundary(
              key: boundaryKey,
              child: Container(
                width: logicalWidth,
                color: Colors.white,
                // Same content padding as the on-screen `_ReceiptPaper` card
                // (receipt_paper_view.dart) — no shadow/rounded corners here,
                // since a printed receipt has no "card" to cast one.
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Confirms the child actually received the explicit
                    // width above, not a loose/full-screen constraint from
                    // the Overlay — see [ReceiptBitmapRenderer] doc comment.
                    measuredMaxWidth = constraints.maxWidth;
                    return child;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // Two frames: first mounts+lays out the subtree, second ensures it
      // has fully repainted before we capture.
      await timePrintStage('receiptWidgetMount', () async {
        await WidgetsBinding.instance.endOfFrame;
        await WidgetsBinding.instance.endOfFrame;
      });

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw const ReceiptRenderException(
            'Unable to render Khmer receipt: bitmap boundary failed to mount.');
      }
      if (kDebugMode) {
        debugPrint('[ReceiptLayout] mode=raster paper=${paperSize.name} '
            'logicalWidth=$logicalWidth maxWidth=$measuredMaxWidth '
            'pixelRatio=${pixelRatio.toStringAsFixed(3)}');
      }
      final uiImage = await timePrintStage(
          'receiptToImage', () => renderObject.toImage(pixelRatio: pixelRatio));
      // Raw RGBA, not PNG: this used to encode to PNG here and immediately
      // img.decodePng it below — a full zlib compress+decompress round trip
      // for bytes that were about to be thrown away anyway. Raw RGBA is an
      // uncompressed memory copy on both sides, and img.Image.fromBytes
      // accepts it directly — same pixels, no compression work.
      final byteData = await timePrintStage('receiptToRawBytes',
          () => uiImage.toByteData(format: ui.ImageByteFormat.rawRgba));
      final width = uiImage.width;
      final height = uiImage.height;
      uiImage.dispose();
      if (byteData == null) {
        throw const ReceiptRenderException(
            'Unable to render Khmer receipt: failed to encode the rendered image.');
      }
      final decoded = timePrintStageSync(
          'receiptBytesToImage',
          () => img.Image.fromBytes(
                width: width,
                height: height,
                bytes: byteData.buffer,
                numChannels: 4,
                order: img.ChannelOrder.rgba,
              ));
      if (kDebugMode) {
        debugPrint(
            '[ReceiptLayout] mode=raster paper=${paperSize.name} outputPixels=${width}x$height');
      }
      return decoded;
    } finally {
      entry.remove();
    }
  }

  /// [renderImage], dithered to 1-bit for `Generator.imageRaster()` — direct
  /// thermal (ESC/POS) printing is strictly black/white, and Floyd-Steinberg
  /// dithering keeps Khmer glyph strokes legible instead of just
  /// thresholding.
  Future<img.Image> render(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async {
    final decoded = await renderImage(context, receipt, paperSize);
    return timePrintStageSync(
        'receiptDither',
        () =>
            img.ditherImage(decoded, kernel: img.DitherKernel.floydSteinberg));
  }

  /// [renderWidgetImage], dithered to 1-bit for `Generator.imageRaster()` —
  /// same reasoning as [render], generalized to an arbitrary [child] widget.
  Future<img.Image> renderWidget(
    BuildContext context,
    Widget child,
    PrinterPaperSize paperSize,
  ) async {
    final decoded = await renderWidgetImage(context, child, paperSize);
    return timePrintStageSync(
        'receiptDither',
        () =>
            img.ditherImage(decoded, kernel: img.DitherKernel.floydSteinberg));
  }
}

