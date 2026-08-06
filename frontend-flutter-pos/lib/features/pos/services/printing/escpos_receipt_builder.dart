import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/widgets.dart';

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
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize.escPosPaperSize, profile);
    var bytes = <int>[];
    bytes += generator.reset();

    if (receipt.containsKhmer) {
      final image = await bitmapRenderer.render(context, receipt, paperSize);
      bytes += generator.imageRaster(image, align: PosAlign.center);
    } else {
      bytes += _buildLatinText(generator, receipt);
    }

    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
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

    line(receipt.businessName, align: PosAlign.center, bold: true);
    if (receipt.address != null && receipt.address!.isNotEmpty) {
      line(receipt.address!, align: PosAlign.center);
    }
    if (receipt.phone != null && receipt.phone!.isNotEmpty) {
      line('Tel: ${receipt.phone}', align: PosAlign.center);
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

    row('Subtotal', receipt.fmt(receipt.subtotal));
    if (receipt.discountAmount > 0) {
      row('Discount', '-${receipt.fmt(receipt.discountAmount)}');
    }
    if (receipt.taxAmount > 0) row('Tax', receipt.fmt(receipt.taxAmount));
    bytes += generator.hr();
    row('TOTAL', receipt.fmt(receipt.total), bold: true);

    if (receipt.showExchangeRate) {
      row('Rate',
          '1 = ${ReceiptViewModel.khrGroup(receipt.exchangeRateKhr!)} KHR');
      row('Total (KHR)', '${ReceiptViewModel.khrGroup(receipt.khrTotal)} ៛',
          bold: true);
    }
    if (receipt.paidAmount > 0) row('Paid', receipt.fmt(receipt.paidAmount));
    if (receipt.changeAmount > 0) {
      row('Change', receipt.fmt(receipt.changeAmount));
    }
    if (receipt.paymentMethodLabel != null) {
      row('Payment', receipt.paymentMethodLabel!);
    }
    bytes += generator.hr();
    line(receipt.footer, align: PosAlign.center, bold: true);
    return bytes;
  }
}
