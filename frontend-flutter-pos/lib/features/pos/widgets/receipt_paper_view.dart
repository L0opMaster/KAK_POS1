import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/printing/receipt_labels.dart';
import '../services/printing/receipt_view_model.dart';

/// The logical width [ReceiptContent] is designed and measured at in the
/// primary on-screen preview ([ReceiptPreviewScreen], via [ReceiptPaperView]
/// below) — the exact surface [ReceiptBitmapRenderer] mounts [ReceiptContent]
/// at too (see receipt_bitmap_renderer.dart), so the Khmer raster/PDF path
/// lays out from the *same* logical width as what the cashier already saw
/// on screen instead of an independently-chosen one (previously
/// `paperSize.dotWidth`, i.e. 384/576 logical px — nearly double this,
/// which is why the Khmer PDF used to look "much wider" than the preview).
/// `ReceiptsScreen`'s reprint pane deliberately renders the same
/// [ReceiptContent] at its own wider `380` — that's a second, independent
/// on-screen surface with more room, not something the printed output needs
/// to match; only the value used for *rasterization* needs a single source
/// of truth, which is this constant.
const double kReceiptContentWidth = 300;

/// The single on-screen rendering of a [ReceiptViewModel] — used by both the
/// post-payment [ReceiptPreviewScreen] and [ReceiptsScreen]'s reprint detail
/// pane, so a receipt looks identical no matter where it's opened from.
/// Screen-specific chrome (app bar, action buttons, refund menu, ...) stays
/// in the caller; this widget only renders the receipt paper itself, reading
/// every label from `receipt.labels` — no BuildContext/l10n needed here.
class ReceiptPaperView extends StatelessWidget {
  final ReceiptViewModel receipt;
  final double width;
  const ReceiptPaperView(
      {super.key, required this.receipt, this.width = kReceiptContentWidth});

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      // This on-screen preview is deliberately paper-size-agnostic (always
      // renders at `width`, regardless of the store's configured 58mm/80mm
      // printer) — logged here as a reference point for the raster/PDF
      // path's matching `[ReceiptLayout] mode=raster ...` log in
      // receipt_bitmap_renderer.dart, so the two can be compared directly.
      debugPrint('[ReceiptLayout] mode=preview logicalWidth=$width');
    }
    return _ReceiptPaper(width: width, child: ReceiptContent(receipt: receipt));
  }
}

/// The receipt body itself — header, metadata, items, totals, payment,
/// exchange rate, footer — with no surrounding "paper card" chrome (shadow,
/// rounded corners, page background). This is the actual visual source of
/// truth for what a receipt looks like: [ReceiptPaperView] wraps it in a
/// card for on-screen preview, and [ReceiptBitmapRenderer] wraps it in a
/// plain opaque background for rasterization (a thermal/PDF receipt has no
/// "card" — it's the whole printed page). Both renderers mount this exact
/// widget so the printed Khmer receipt can't structurally drift from what
/// the cashier previewed on screen — see receipt_bitmap_renderer.dart's
/// doc comment for the history of why that drift happened before.
class ReceiptContent extends StatelessWidget {
  final ReceiptViewModel receipt;
  const ReceiptContent({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    final labels = receipt.labels;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ═══════════════════════════════════════════
        //  BILL BANNER (pre-payment bill only)
        // ═══════════════════════════════════════════
        if (receipt.isBill) ...[
          const _Spacer(16),
          Center(
              child: _Text(labels.billHeaderTitle, 13,
                  bold: true, color: _amber, letterSpacing: 2.0)),
          const _Spacer(10),
        ],

        // ═══════════════════════════════════════════
        //  HEADER
        // ═══════════════════════════════════════════
        if (!receipt.isBill) const _Spacer(20),
        Center(
            child: _Text(receipt.businessName, 22,
                bold: true, letterSpacing: 4.0)),
        const _Spacer(6),
        if (receipt.address != null && receipt.address!.isNotEmpty)
          Center(child: _Text(receipt.address!, 8, color: _grey)),
        if (receipt.phone != null && receipt.phone!.isNotEmpty)
          Center(child: _Text(labels.telFormat(receipt.phone!), 8, color: _grey)),
        const _Spacer(6),
        _dashed,
        const _Spacer(10),

        // ═══════════════════════════════════════════
        //  TABLE / ORDER TYPE (pre-payment bill only) — prominent, so the
        //  cashier can identify the order at a glance, separate from the
        //  smaller plain metadata row every receipt already has.
        // ═══════════════════════════════════════════
        if (receipt.isBill && receipt.tableNumber != null) ...[
          _billTableBanner(receipt, labels),
          const _Spacer(10),
        ],

        // ═══════════════════════════════════════════
        //  INFO
        // ═══════════════════════════════════════════
        _info(receipt.isBill ? labels.ticket : labels.invoiceNumber,
            receipt.invoiceNumber),
        _info(labels.date, receipt.date),
        _info(labels.time, receipt.time),
        if (receipt.cashierName != null)
          _info(labels.cashier, receipt.cashierName!),
        if (receipt.customerName != null)
          _info(labels.customer, receipt.customerName!),
        if (receipt.tableNumber != null)
          _info(labels.table, receipt.tableNumber!),
        const _Spacer(10),
        _dashed,
        const _Spacer(10),

        // ═══════════════════════════════════════════
        //  ITEMS HEADER
        // ═══════════════════════════════════════════
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Text(labels.item, 8, bold: true, color: _greyDark),
            const Spacer(),
            _Text(labels.qty, 8,
                bold: true, color: _greyDark, width: 32, align: TextAlign.right),
            _Text(labels.total, 8,
                bold: true, color: _greyDark, width: 60, align: TextAlign.right),
          ],
        ),
        const _Spacer(4),
        _solid,
        const _Spacer(8),

        // ═══════════════════════════════════════════
        //  ITEMS
        // ═══════════════════════════════════════════
        if (receipt.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: _Text(labels.emptyCart, 9, color: _grey)),
          )
        else
          ...List.generate(receipt.lines.length, (i) {
            final isLast = i == receipt.lines.length - 1;
            return Column(
              children: [
                _buildRow(receipt.lines[i], receipt),
                if (!isLast) const _Spacer(6),
              ],
            );
          }),

        const _Spacer(10),
        _dashed,
        const _Spacer(10),

        // ═══════════════════════════════════════════
        //  TOTALS
        // ═══════════════════════════════════════════
        _total(labels.subtotal, receipt.fmt(receipt.subtotal)),
        for (final adj in receipt.adjustments) ...[
          const _Spacer(3),
          _total(adj.type.labelFrom(labels), receipt.fmtAdjustment(adj)),
        ],
        const _Spacer(3),
        _total(labels.total, receipt.fmt(receipt.total), bold: true, large: true),
        const _Spacer(14),
        _dashed,
        const _Spacer(10),

        // ═══════════════════════════════════════════
        //  PAYMENT  (or UNPAID status, for a pre-payment bill)
        // ═══════════════════════════════════════════
        if (receipt.isBill) ...[
          Center(
              child: _Text(labels.paymentStatus, 9,
                  bold: true, color: _greyDark)),
          const _Spacer(4),
          Center(
              child: _Text(labels.unpaid, 15, bold: true, color: _amber)),
          const _Spacer(8),
          Center(child: _Text(labels.billDisclaimer, 8, color: _grey)),
          const _Spacer(4),
          Center(
              child: _Text(labels.billCashierNotice, 9,
                  bold: true, color: _amber)),
          const _Spacer(10),
          _dashed,
          const _Spacer(10),
        ] else ...[
          _total(labels.paid, receipt.fmt(receipt.paidAmount), bold: true),
          const _Spacer(3),
          // Cash Received/Change only make sense together — showing Change
          // alone next to a Paid amount that already equals the Total
          // (paidAmount is the amount APPLIED to the sale, never more) reads
          // as if change appeared from nowhere. Cash Received (= paidAmount
          // + changeAmount, i.e. what the customer actually handed over)
          // makes the arithmetic legible: Cash Received - Change = Paid.
          if (receipt.changeAmount > 0) ...[
            _total(labels.cashReceived,
                receipt.fmt(receipt.paidAmount + receipt.changeAmount)),
            const _Spacer(3),
            _total(labels.change, receipt.fmt(receipt.changeAmount),
                color: _green),
            const _Spacer(10),
            _dashed,
            const _Spacer(10),
          ],
        ],

        // ═══════════════════════════════════════════
        //  EXCHANGE RATE
        // ═══════════════════════════════════════════
        if (receipt.showExchangeRate) ...[
          Center(child: _Text('─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─', 8, color: _grey)),
          const _Spacer(8),
          Center(child: _Text(labels.exchangeRate, 8, bold: true, color: _greyDark)),
          const _Spacer(4),
          Center(
              child: _Text(
                  labels.exchangeRateValueFormat(
                      ReceiptViewModel.khrGroup(receipt.exchangeRateKhr!)),
                  9,
                  bold: true)),
          const _Spacer(4),
          Center(
              child: _Text(
                  '${labels.totalRiel}:  ${ReceiptViewModel.khrGroup(receipt.khrTotal)} ៛',
                  9,
                  bold: true)),
          const _Spacer(10),
          _solid,
          const _Spacer(10),
        ],

        // ═══════════════════════════════════════════
        //  FOOTER
        // ═══════════════════════════════════════════
        const _Spacer(12),
        Center(child: _Text(receipt.footer, 12, bold: true)),
        // Settings → Company Profile's "Website" field — never a hardcoded
        // placeholder, and never rendered at all when unset (see
        // ReceiptViewModel.website's doc comment).
        if (receipt.website != null && receipt.website!.isNotEmpty) ...[
          const _Spacer(4),
          Center(child: _Text(receipt.website!, 8, color: _grey)),
        ],
        const _Spacer(2),
        Center(child: _Text(labels.poweredBy, 7, color: _grey)),
        const _Spacer(20),
      ],
    );
  }

  // ── Build helpers ────────────────────────────────

  Widget _buildRow(ReceiptLineViewModel line, ReceiptViewModel receipt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _Text(line.name, 9)),
            _Text(line.qty.toStringAsFixed(0), 9,
                width: 32, align: TextAlign.right),
            _Text(receipt.fmt(line.lineTotal), 9,
                width: 60, align: TextAlign.right, bold: true),
          ],
        ),
        if (line.modifierAmount != 0)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _Text(
                'Base: ${receipt.fmt(line.basePrice)} + Modifiers: ${receipt.fmt(line.modifierAmount)}',
                7,
                color: _grey),
          ),
        if (line.modifierSummary != null && line.modifierSummary!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _Text(line.modifierSummary!, 7, color: _grey),
          ),
        if (line.note != null && line.note!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _Text(line.note!, 7, color: _grey),
          ),
      ],
    );
  }

  /// Bordered "TABLE T05 / DINE IN" block for a pre-payment bill — bigger
  /// and more prominent than the plain [_info] row every receipt already
  /// has for the table, so the cashier can spot which table an order
  /// belongs to at a glance (see [ReceiptViewModel.isBill] doc comment).
  Widget _billTableBanner(ReceiptViewModel receipt, ReceiptLabels labels) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          _Text(receipt.tableNumber!.toUpperCase(), 14,
              bold: true, align: TextAlign.center, letterSpacing: 1.0),
          if (receipt.isDineIn) ...[
            const _Spacer(2),
            _Text(labels.dineIn.toUpperCase(), 8,
                color: _greyDark, align: TextAlign.center, letterSpacing: 1.0),
          ],
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _Text(label, 8, color: _grey),
        _Text(value, 8, bold: true),
      ]),
    );
  }

  Widget _total(String label, String value,
      {bool bold = false, bool large = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _Text(label, bold ? 10 : 9, bold: bold),
        _Text(value, large ? 16 : 10, bold: bold, color: color),
      ]),
    );
  }

  // ── Divider helpers ─────────────────────────────

  Widget get _dashed => LayoutBuilder(
        builder: (_, c) => Wrap(
          spacing: 0,
          runSpacing: 0,
          children: List.generate(
            (c.maxWidth / 8).ceil(),
            (i) => SizedBox(
                width: 4, height: 1, child: Container(color: Colors.grey[300])),
          ),
        ),
      );

  Widget get _solid => Container(height: 1, color: Colors.grey[300]);
}

// ── Reusable styled text widget ───────────────────

const _grey = Color(0xFF999999);
const _greyDark = Color(0xFF666666);
const _green = Color(0xFF4CAF50);

/// Warning/pending color for a pre-payment bill's "UNPAID" status — never
/// used on a paid receipt, whose payment section stays exactly as before.
const _amber = Color(0xFFE08900);

class _Text extends StatelessWidget {
  final String data;
  final double size;
  final bool bold;
  final Color? color;
  final double? width;
  final TextAlign align;
  final double letterSpacing;
  const _Text(this.data, this.size,
      {this.bold = false,
      this.color,
      this.width,
      this.align = TextAlign.left,
      this.letterSpacing = 0.0});

  @override
  Widget build(BuildContext context) {
    final widget = Text(
      data,
      textAlign: align,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const ['NotoSansKhmer'],
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: color ?? Colors.black,
        letterSpacing: letterSpacing,
        height: 1.3,
      ),
    );
    if (width == null) return widget;
    return SizedBox(width: width, child: widget);
  }
}

class _Spacer extends StatelessWidget {
  final double height;
  const _Spacer(this.height);
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

/// Wraps the receipt content in a white card with subtle shadow, simulating
/// thermal receipt paper — on-screen preview chrome only. Deliberately NOT
/// reused by [ReceiptBitmapRenderer]: a rasterized/printed receipt has no
/// "card" sitting on a page background to cast a shadow, so baking this
/// shadow into the raster would show up as a faint, unwanted gradient at the
/// image edges in the final PDF/thermal output.
class _ReceiptPaper extends StatelessWidget {
  final double width;
  final Widget child;
  const _ReceiptPaper({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
}
