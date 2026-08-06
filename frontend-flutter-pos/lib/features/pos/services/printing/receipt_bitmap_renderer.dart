import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import 'printer_profile.dart';
import 'receipt_view_model.dart';

/// Renders a [ReceiptViewModel] to a monochrome raster image, for thermal
/// printers that can't render Khmer glyphs natively.
///
/// The trick: build the receipt as an ordinary Flutter widget tree (using
/// the bundled NotoSansKhmer font), mount it off-screen via a real
/// [OverlayEntry] positioned far outside the viewport, and rasterize it with
/// `RenderRepaintBoundary.toImage`. Because it's a real, attached widget
/// subtree, Flutter's own text shaping engine does the hard part (Khmer
/// glyph selection, reordering, stacking) — this never has to reimplement
/// font rendering. The result is then dithered to 1-bit and handed to
/// `esc_pos_utils_plus`'s raster image command.
class ReceiptBitmapRenderer {
  const ReceiptBitmapRenderer();

  /// Renders [receipt] at the given paper width and returns a decoded
  /// [img.Image] ready for `Generator.imageRaster()`. Requires a
  /// [BuildContext] with an [Overlay] ancestor (any screen context works —
  /// the app always has a root `Navigator`/`Overlay`).
  Future<img.Image> render(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async {
    final widthPx = paperSize.dotWidth.toDouble();
    final boundaryKey = GlobalKey();
    final overlay = Overlay.of(context, rootOverlay: true);

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
              child: _ReceiptDocument(receipt: receipt, widthPx: widthPx),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    try {
      // Two frames: first mounts+lays out the subtree (and starts decoding
      // any embedded QR image), second ensures that decode has resolved
      // and repainted before we capture.
      await WidgetsBinding.instance.endOfFrame;
      await WidgetsBinding.instance.endOfFrame;

      final renderObject = boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('Receipt bitmap boundary failed to mount');
      }
      final uiImage = await renderObject.toImage(pixelRatio: 1.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (byteData == null) {
        throw StateError('Failed to encode rendered receipt to PNG');
      }
      final decoded = img.decodePng(byteData.buffer.asUint8List());
      if (decoded == null) {
        throw StateError('Failed to decode rendered receipt bitmap');
      }
      // Thermal raster printing is strictly black/white — Floyd-Steinberg
      // dithering keeps logos/QR codes legible instead of just thresholding.
      return img.ditherImage(decoded, kernel: img.DitherKernel.floydSteinberg);
    } finally {
      entry.remove();
    }
  }
}

/// The visual receipt layout used for bitmap rendering — mirrors the
/// on-screen `ReceiptPreviewScreen` styling closely enough to look like the
/// same receipt, but is self-contained (no scaffold/app bar) since this is
/// rasterized offscreen, never actually shown on a device screen.
class _ReceiptDocument extends StatelessWidget {
  const _ReceiptDocument({required this.receipt, required this.widthPx});

  final ReceiptViewModel receipt;
  final double widthPx;

  static const _khmerFallback = ['NotoSansKhmer'];

  TextStyle _style(double size, {bool bold = false, Color? color}) =>
      TextStyle(
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? Colors.black,
        fontFamilyFallback: _khmerFallback,
      );

  @override
  Widget build(BuildContext context) {
    // Thermal dot-width in, logical pixels out — 1 dot ≈ 1 logical px at
    // pixelRatio 1.0 in the offscreen renderer, so this keeps the bitmap at
    // exactly the printer's native raster width.
    final pad = widthPx * 0.04;
    return Container(
      width: widthPx,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(receipt.businessName,
                textAlign: TextAlign.center, style: _style(20, bold: true)),
          ),
          if (receipt.address != null && receipt.address!.isNotEmpty)
            Center(
                child: Text(receipt.address!,
                    textAlign: TextAlign.center, style: _style(12))),
          if (receipt.phone != null && receipt.phone!.isNotEmpty)
            Center(
                child: Text('Tel: ${receipt.phone}',
                    textAlign: TextAlign.center, style: _style(12))),
          const SizedBox(height: 6),
          const _Divider(),
          const SizedBox(height: 6),
          _infoRow(receipt.invoiceNumber, receipt.date),
          if (receipt.time.isNotEmpty) Text(receipt.time, style: _style(11)),
          if (receipt.cashierName != null)
            Text(receipt.cashierName!, style: _style(11)),
          if (receipt.customerName != null)
            Text(receipt.customerName!, style: _style(11)),
          if (receipt.tableNumber != null)
            Text(receipt.tableNumber!, style: _style(11)),
          const SizedBox(height: 6),
          const _Divider(),
          const SizedBox(height: 6),
          for (final line in receipt.lines) _lineRow(line),
          const SizedBox(height: 4),
          const _Divider(),
          const SizedBox(height: 4),
          _amountRow('Subtotal', receipt.fmt(receipt.subtotal)),
          if (receipt.discountAmount > 0)
            _amountRow('Discount', '-${receipt.fmt(receipt.discountAmount)}'),
          if (receipt.taxAmount > 0)
            _amountRow('Tax', receipt.fmt(receipt.taxAmount)),
          const SizedBox(height: 4),
          const _Divider(),
          _amountRow('TOTAL', receipt.fmt(receipt.total),
              bold: true, big: true),
          if (receipt.showExchangeRate) ...[
            _amountRow('Rate',
                '1 = ${ReceiptViewModel.khrGroup(receipt.exchangeRateKhr!)} KHR'),
            _amountRow('Total (KHR)',
                '${ReceiptViewModel.khrGroup(receipt.khrTotal)} ៛',
                bold: true),
          ],
          if (receipt.paidAmount > 0)
            _amountRow('Paid', receipt.fmt(receipt.paidAmount)),
          if (receipt.changeAmount > 0)
            _amountRow('Change', receipt.fmt(receipt.changeAmount)),
          if (receipt.paymentMethodLabel != null)
            _amountRow('Payment', receipt.paymentMethodLabel!),
          const SizedBox(height: 8),
          const _Divider(),
          const SizedBox(height: 8),
          Center(
            child: Text(receipt.footer,
                textAlign: TextAlign.center, style: _style(13, bold: true)),
          ),
          if (receipt.qrImageData != null && receipt.qrImageData!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Image.memory(
                  base64Decode(receipt.qrImageData!),
                  width: widthPx * 0.4,
                  height: widthPx * 0.4,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _infoRow(String left, String right) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(left, style: _style(12))),
            Flexible(child: Text(right, style: _style(12))),
          ],
        ),
      );

  Widget _lineRow(ReceiptLineViewModel line) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(line.name, style: _style(13))),
                Text(
                    '${line.qty.toStringAsFixed(0)} x ${receipt.fmt(line.unitPrice)}',
                    style: _style(11)),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Text(receipt.fmt(line.lineTotal),
                  style: _style(13, bold: true)),
            ),
            if (line.modifierSummary != null)
              Text(line.modifierSummary!, style: _style(10)),
            if (line.note != null) Text(line.note!, style: _style(10)),
          ],
        ),
      );

  Widget _amountRow(String label, String value,
          {bool bold = false, bool big = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: _style(big ? 15 : 12, bold: bold)),
            Text(value, style: _style(big ? 15 : 12, bold: bold)),
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: Colors.black26);
}
