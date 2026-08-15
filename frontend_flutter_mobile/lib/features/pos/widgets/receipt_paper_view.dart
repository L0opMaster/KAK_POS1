import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/printing/receipt_view_model.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// receipt_paper_view.dart` — COPY/ADAPT NEARLY EXACTLY, full file,
/// byte-for-byte on every font-size constant. This is a fixed print spec,
/// not app UI typography — Day 3's Khmer UI text-scaling
/// (`khmer_text_scaler.dart`) must NEVER be applied here, in either
/// direction, regardless of which language is selected in the app. `_Text`
/// below reads no `Theme`/`MediaQuery.textScaler` at all, by design.
///
/// [kReceiptContentWidth] is the logical width [ReceiptContent] is
/// designed/measured at — Day 14/15's Khmer bitmap/PDF rasterizer (not
/// built yet) will need to mount [ReceiptContent] at this exact same width
/// once it exists, so the printed Khmer raster never structurally drifts
/// from what this screen already previewed. `ReceiptsScreen`'s detail pane
/// deliberately renders at its own wider `380` — a second, independent
/// on-screen surface; only the *rasterization* width needs this single
/// source of truth.
const double kReceiptContentWidth = 300;

/// The single on-screen rendering of a [ReceiptViewModel] — used by both
/// `ReceiptPreviewScreen` and `ReceiptsScreen`'s detail pane, so a receipt
/// looks identical no matter where it's opened from. Screen-specific chrome
/// (app bar, action buttons, refund menu, ...) stays in the caller; this
/// widget only renders the receipt paper itself.
class ReceiptPaperView extends StatelessWidget {
  final ReceiptViewModel receipt;
  final double width;
  const ReceiptPaperView({
    super.key,
    required this.receipt,
    this.width = kReceiptContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('[ReceiptLayout] mode=preview logicalWidth=$width');
    }
    return _ReceiptPaper(
      width: width,
      child: ReceiptContent(receipt: receipt),
    );
  }
}

/// The receipt body itself — header, metadata, items, totals, payment,
/// exchange rate, footer — with no surrounding "paper card" chrome. This is
/// the actual visual source of truth for what a receipt looks like; Day
/// 14/15's rasterizer will mount this exact widget too, once it exists, so
/// the printed Khmer receipt can't structurally drift from what the
/// cashier previewed on screen.
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
        //  HEADER
        // ═══════════════════════════════════════════
        const _Spacer(20),
        Center(
          child: _Text(
            receipt.businessName,
            22,
            bold: true,
            letterSpacing: 4.0,
          ),
        ),
        const _Spacer(6),
        if (receipt.address != null && receipt.address!.isNotEmpty)
          Center(child: _Text(receipt.address!, 8, color: _grey)),
        if (receipt.phone != null && receipt.phone!.isNotEmpty)
          Center(
            child: _Text(labels.telFormat(receipt.phone!), 8, color: _grey),
          ),
        const _Spacer(6),
        _dashed,
        const _Spacer(10),

        // ═══════════════════════════════════════════
        //  INFO
        // ═══════════════════════════════════════════
        _info(labels.invoiceNumber, receipt.invoiceNumber),
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
            _Text(
              labels.qty,
              8,
              bold: true,
              color: _greyDark,
              width: 32,
              align: TextAlign.right,
            ),
            _Text(
              labels.total,
              8,
              bold: true,
              color: _greyDark,
              width: 60,
              align: TextAlign.right,
            ),
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
        _total(
          labels.total,
          receipt.fmt(receipt.total),
          bold: true,
          large: true,
        ),
        const _Spacer(14),
        _dashed,
        const _Spacer(10),

        // ═══════════════════════════════════════════
        //  PAYMENT
        // ═══════════════════════════════════════════
        _total(labels.paid, receipt.fmt(receipt.paidAmount), bold: true),
        const _Spacer(3),
        // Cash Received/Change only make sense together — showing Change
        // alone next to a Paid amount that already equals the Total reads
        // as if change appeared from nowhere. Cash Received (= paidAmount
        // + changeAmount) makes the arithmetic legible: Cash Received -
        // Change = Paid.
        if (receipt.changeAmount > 0) ...[
          _total(
            labels.cashReceived,
            receipt.fmt(receipt.paidAmount + receipt.changeAmount),
          ),
          const _Spacer(3),
          _total(
            labels.change,
            receipt.fmt(receipt.changeAmount),
            color: _green,
          ),
          const _Spacer(10),
          _dashed,
          const _Spacer(10),
        ],

        // ═══════════════════════════════════════════
        //  EXCHANGE RATE
        // ═══════════════════════════════════════════
        if (receipt.showExchangeRate) ...[
          Center(child: _Text('─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─', 8, color: _grey)),
          const _Spacer(8),
          Center(
            child: _Text(labels.exchangeRate, 8, bold: true, color: _greyDark),
          ),
          const _Spacer(4),
          Center(
            child: _Text(
              labels.exchangeRateValueFormat(
                ReceiptViewModel.khrGroup(receipt.exchangeRateKhr!),
              ),
              9,
              bold: true,
            ),
          ),
          const _Spacer(4),
          Center(
            child: _Text(
              '${labels.totalRiel}:  ${ReceiptViewModel.khrGroup(receipt.khrTotal)} ៛',
              9,
              bold: true,
            ),
          ),
          const _Spacer(10),
          _solid,
          const _Spacer(10),
        ],

        // ═══════════════════════════════════════════
        //  FOOTER
        // ═══════════════════════════════════════════
        const _Spacer(12),
        Center(child: _Text(receipt.footer, 12, bold: true)),
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
            _Text(
              line.qty.toStringAsFixed(0),
              9,
              width: 32,
              align: TextAlign.right,
            ),
            _Text(
              receipt.fmt(line.lineTotal),
              9,
              width: 60,
              align: TextAlign.right,
              bold: true,
            ),
          ],
        ),
        if (line.modifierAmount != 0)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: _Text(
              'Base: ${receipt.fmt(line.basePrice)} + Modifiers: ${receipt.fmt(line.modifierAmount)}',
              7,
              color: _grey,
            ),
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

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Text(label, 8, color: _grey),
          _Text(value, 8, bold: true),
        ],
      ),
    );
  }

  Widget _total(
    String label,
    String value, {
    bool bold = false,
    bool large = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Text(label, bold ? 10 : 9, bold: bold),
          _Text(value, large ? 16 : 10, bold: bold, color: color),
        ],
      ),
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
          width: 4,
          height: 1,
          child: Container(color: Colors.grey[300]),
        ),
      ),
    ),
  );

  Widget get _solid => Container(height: 1, color: Colors.grey[300]);
}

// ── Reusable styled text widget ───────────────────

const _grey = Color(0xFF999999);
const _greyDark = Color(0xFF666666);
const _green = Color(0xFF4CAF50);

class _Text extends StatelessWidget {
  final String data;
  final double size;
  final bool bold;
  final Color? color;
  final double? width;
  final TextAlign align;
  final double letterSpacing;
  const _Text(
    this.data,
    this.size, {
    this.bold = false,
    this.color,
    this.width,
    this.align = TextAlign.left,
    this.letterSpacing = 0.0,
  });

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
/// reused by Day 14/15's rasterizer once it exists: a printed receipt has
/// no "card" sitting on a page background to cast a shadow.
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
