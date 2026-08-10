import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/widgets.dart';

import '../../../../core/utils/print_perf.dart';
import 'printer_profile.dart';
import 'receipt_bitmap_renderer.dart';
import 'receipt_view_model.dart';

/// Builds the raw ESC/POS byte stream for a [ReceiptViewModel], ready to
/// hand to any [PrinterTransport].
///
/// Reliability strategy (req. 12): thermal printer firmware support for
/// Khmer is inconsistent, so mixing native ESC/POS text commands with
/// per-line font switches is fragile. Instead: pure-Latin receipts print as
/// fast native ESC/POS text; any receipt containing Khmer prints as a single
/// rasterized bitmap of the whole receipt (rendered by
/// [ReceiptBitmapRenderer], which reuses Flutter's own text shaping) — one
/// simple, reliable rule instead of a hybrid per-glyph fallback.
class EscPosReceiptBuilder {
  const EscPosReceiptBuilder({
    this.bitmapRenderer = const ReceiptBitmapRenderer(),
  });

  final ReceiptBitmapRenderer bitmapRenderer;

  /// Builds the full print job. [context] is only used when the receipt
  /// needs bitmap rendering (see [ReceiptBitmapRenderer.render]).
  Future<List<int>> build(
    BuildContext context,
    ReceiptViewModel receipt,
    PrinterPaperSize paperSize,
  ) async {
    return timePrintStage('escposBuildTotal', () async {
      final profile = await timePrintStage(
          'escposCapabilityLoad', () => CapabilityProfile.load());
      final generator = Generator(paperSize.escPosPaperSize, profile);
      var bytes = <int>[];
      bytes += generator.reset();

      if (receipt.containsKhmer) {
        final image = await timePrintStage('escposBitmapRender',
            () => bitmapRenderer.render(context, receipt, paperSize));
        bytes += timePrintStageSync('escposImageRasterEncode',
            () => generator.imageRaster(image, align: PosAlign.center));
      } else {
        bytes += timePrintStageSync(
            'escposLatinText', () => _buildLatinText(generator, receipt));
      }

      bytes += generator.feed(2);
      bytes += generator.cut();
      return bytes;
    });
  }

  List<int> _buildLatinText(Generator generator, ReceiptViewModel receipt) {
    var bytes = <int>[];
    void line(String text,
        {PosAlign align = PosAlign.left,
        bool bold = false,
        PosTextSize size = PosTextSize.size1}) {
      bytes += generator.text(
        text,
        styles: PosStyles(align: align, bold: bold, height: size, width: size),
      );
    }

    void row(String left, String right, {bool bold = false}) {
      bytes += generator.row([
        PosColumn(
            text: left,
            width: 8,
            styles: PosStyles(bold: bold, align: PosAlign.left)),
        PosColumn(
            text: right,
            width: 4,
            styles: PosStyles(bold: bold, align: PosAlign.right)),
      ]);
    }

    final labels = receipt.labels;

    line(receipt.businessName, align: PosAlign.center, bold: true);
    if (receipt.address != null && receipt.address!.isNotEmpty) {
      line(receipt.address!, align: PosAlign.center);
    }
    if (receipt.phone != null && receipt.phone!.isNotEmpty) {
      line(labels.telFormat(receipt.phone!), align: PosAlign.center);
    }
    bytes += generator.hr();
    row(receipt.invoiceNumber, receipt.date);
    if (receipt.time.isNotEmpty) line(receipt.time);
    if (receipt.cashierName != null) line(receipt.cashierName!);
    if (receipt.customerName != null) line(receipt.customerName!);
    if (receipt.tableNumber != null) line(receipt.tableNumber!);
    bytes += generator.hr();

    for (final l in receipt.lines) {
      line(l.name);
      row('  ${l.qty.toStringAsFixed(0)} x ${receipt.fmt(l.unitPrice)}',
          receipt.fmt(l.lineTotal));
      if (l.modifierSummary != null) line('  ${l.modifierSummary}');
      if (l.note != null) line('  ${l.note}');
    }
    bytes += generator.hr(ch: '-');

    row(labels.subtotal, receipt.fmt(receipt.subtotal));
    // Iterate the shared adjustments list (discount/delivery/other/tax) —
    // previously this only ever checked discountAmount/taxAmount directly,
    // so a receipt with a delivery or other/service charge silently never
    // showed that line on thermal output, unlike the PDF/on-screen preview.
    for (final adj in receipt.adjustments) {
      row(adj.type.labelFrom(labels), receipt.fmtAdjustment(adj));
    }
    bytes += generator.hr();
    row(labels.total.toUpperCase(), receipt.fmt(receipt.total), bold: true);

    if (receipt.showExchangeRate) {
      row(
          labels.exchangeRate,
          labels.exchangeRateValueFormat(
              ReceiptViewModel.khrGroup(receipt.exchangeRateKhr!)));
      row(labels.totalRiel, '${ReceiptViewModel.khrGroup(receipt.khrTotal)} ៛',
          bold: true);
    }
    if (receipt.paidAmount > 0)
      row(labels.paid, receipt.fmt(receipt.paidAmount));
    if (receipt.changeAmount > 0) {
      // Cash Received (= paidAmount + changeAmount) makes Change legible —
      // Paid alone is the amount APPLIED to the sale (never more than the
      // total), so Change would otherwise look like it appeared from
      // nowhere.
      row(labels.cashReceived,
          receipt.fmt(receipt.paidAmount + receipt.changeAmount));
      row(labels.change, receipt.fmt(receipt.changeAmount));
    }
    if (receipt.paymentMethodLabel != null) {
      row(labels.paymentMethod, receipt.paymentMethodLabel!);
    }
    bytes += generator.hr();
    line(receipt.footer, align: PosAlign.center, bold: true);
    return bytes;
  }
}
