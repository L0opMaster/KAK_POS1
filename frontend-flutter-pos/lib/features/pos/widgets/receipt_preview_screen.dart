import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/language_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/cart_models.dart';
import '../services/print_service.dart';
import '../services/printing/printer_profile.dart';
import '../services/printing/receipt_view_model.dart';
import '../services/printing/thermal_printer_service.dart';

/// Minimalist thermal receipt preview inspired by Apple / MUJI design.
/// Black text on white, generous spacing, clean alignment. Optimised for
/// 58 mm and 80 mm thermal receipt printers.
///
/// Renders from a single [ReceiptViewModel] (built in [build] from the raw
/// constructor params below) — the same model the PDF and ESC/POS/bitmap
/// pipelines render from, so this preview never drifts from what actually
/// gets printed.
class ReceiptPreviewScreen extends ConsumerWidget {
  final double total;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double deliveryCharge;
  final double otherCharge;
  final List<SplitRowReceipt> splits;
  final String? invoiceNumber;
  final String cashierName;
  final List<CartItem>? saleItems;
  final String? businessName;
  final String? businessAddress;
  final String? businessPhone;
  final String? currency;
  final String? footer;
  final String? saleDate;
  final String? saleTime;
  final String? tableNumber;

  /// Overrides the splits-derived paid/change amounts with the backend's
  /// authoritative values (`ReceiptResponse.paidAmount`/`.changeAmount`)
  /// once the finalized sale has loaded. Null falls back to computing from
  /// [splits] (amount applied vs. [total]) — used only for the brief window
  /// before the backend receipt is available.
  final double? paidAmountOverride;
  final double? changeAmountOverride;

  /// KHR-per-USD rate frozen onto this sale at the time it was created —
  /// never the live Settings rate, so an old receipt keeps showing the
  /// rate that was actually in effect when it was made. Null if the
  /// backend receipt hasn't loaded yet (skips the riel line entirely).
  final double? exchangeRateKhr;

  const ReceiptPreviewScreen({
    super.key,
    required this.total,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.deliveryCharge = 0,
    this.otherCharge = 0,
    required this.splits,
    this.invoiceNumber,
    this.cashierName = '',
    this.saleItems,
    this.businessName,
    this.businessAddress,
    this.businessPhone,
    this.currency,
    this.footer,
    this.saleDate,
    this.saleTime,
    this.tableNumber,
    this.paidAmountOverride,
    this.changeAmountOverride,
    this.exchangeRateKhr,
  });

  ReceiptViewModel _buildViewModel(
      AppLanguage language, AppLocalizations l10n) {
    final items = saleItems ?? [];
    final splitsPaid = splits.fold(0.0, (sum, s) => sum + s.amount);
    final totalPaid = paidAmountOverride ?? splitsPaid;
    final change =
        changeAmountOverride ?? (splitsPaid > total ? splitsPaid - total : 0.0);
    final now = DateTime.now();
    final dispDate = saleDate ??
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final dispTime = saleTime ??
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    return ReceiptViewModel.fromCart(
      language: language,
      l10n: l10n,
      total: total,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      deliveryCharge: deliveryCharge,
      otherCharge: otherCharge,
      items: items,
      paidAmount: totalPaid,
      changeAmount: change,
      invoiceNumber: invoiceNumber,
      cashierName: cashierName,
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      currency: currency,
      footer: footer,
      saleDate: dispDate,
      saleTime: dispTime,
      tableNumber: tableNumber,
      exchangeRateKhr: exchangeRateKhr,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final receipt = _buildViewModel(language, l10n);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F6),
      appBar: AppBar(
        title: Text(l10n.receiptTitle),
        // backgroundColor: Colors.white,
        // foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.content_copy, size: 20),
            tooltip: l10n.commonClose,
            onPressed: () => _printReceipt(context, ref, receipt),
          ),
          IconButton(
            icon: const Icon(Icons.print, size: 22),
            tooltip: l10n.receiptPrint,
            onPressed: () => _printReceipt(context, ref, receipt),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: _ReceiptPaper(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ═══════════════════════════════════════════
                //  HEADER
                // ═══════════════════════════════════════════
                const _Spacer(20),
                Center(
                    child: _Text(receipt.businessName, 22,
                        bold: true, letterSpacing: 4.0)),
                const _Spacer(6),
                if (receipt.address != null && receipt.address!.isNotEmpty)
                  Center(child: _Text(receipt.address!, 8, color: _grey)),
                if (receipt.phone != null && receipt.phone!.isNotEmpty)
                  Center(
                      child: _Text('Tel: ${receipt.phone}', 8, color: _grey)),
                const _Spacer(6),
                _dashed,
                const _Spacer(10),

                // ═══════════════════════════════════════════
                //  INFO
                // ═══════════════════════════════════════════
                _info(l10n.receiptInvoiceNumber, receipt.invoiceNumber),
                _info(l10n.receiptDate, receipt.date),
                _info(l10n.receiptTime, receipt.time),
                if (receipt.cashierName != null)
                  _info(l10n.receiptCashier, receipt.cashierName!),
                if (receipt.tableNumber != null)
                  _info(l10n.receiptTable, receipt.tableNumber!),
                const _Spacer(10),
                _dashed,
                const _Spacer(10),

                // ═══════════════════════════════════════════
                //  ITEMS HEADER
                // ═══════════════════════════════════════════
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _Text(l10n.receiptItem, 8, bold: true, color: _greyDark),
                    const Spacer(),
                    _Text(l10n.receiptQty, 8,
                        bold: true,
                        color: _greyDark,
                        width: 32,
                        align: TextAlign.right),
                    _Text(l10n.receiptTotal, 8,
                        bold: true,
                        color: _greyDark,
                        width: 60,
                        align: TextAlign.right),
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
                    child: Center(
                        child: _Text(l10n.posEmptyCart, 9, color: _grey)),
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
                _total(l10n.receiptSubtotal, receipt.fmt(receipt.subtotal)),
                for (final adj in receipt.adjustments) ...[
                  const _Spacer(3),
                  _total(_adjustmentLabel(l10n, adj.type),
                      receipt.fmtAdjustment(adj)),
                ],
                const _Spacer(3),
                _total(l10n.receiptTotal, receipt.fmt(receipt.total),
                    bold: true, large: true),
                const _Spacer(14),
                _dashed,
                const _Spacer(10),

                // ═══════════════════════════════════════════
                //  PAYMENT
                // ═══════════════════════════════════════════
                _total(l10n.receiptPaid, receipt.fmt(receipt.paidAmount),
                    bold: true),
                const _Spacer(3),
                // Cash Received/Change only make sense together — showing
                // Change alone next to a Paid amount that already equals
                // the Total (paidAmount is the amount APPLIED to the sale,
                // never more) reads as if change appeared from nowhere.
                // Cash Received (= paidAmount + changeAmount, i.e. what the
                // customer actually handed over) makes the arithmetic
                // legible: Cash Received - Change = Paid.
                if (receipt.changeAmount > 0) ...[
                  _total(l10n.paymentScreenCashReceived,
                      receipt.fmt(receipt.paidAmount + receipt.changeAmount)),
                  const _Spacer(3),
                  _total(l10n.receiptChange, receipt.fmt(receipt.changeAmount),
                      color: _green),
                  const _Spacer(10),
                  _dashed,
                  const _Spacer(10),
                ],

                // ═══════════════════════════════════════════
                //  EXCHANGE RATE
                // ═══════════════════════════════════════════
                if (receipt.showExchangeRate) ...[
                  Center(
                      child: _Text('─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─', 8, color: _grey)),
                  const _Spacer(8),
                  Center(
                      child: _Text(l10n.receiptExchangeRate, 8,
                          bold: true, color: _greyDark)),
                  const _Spacer(4),
                  Center(
                      child: _Text(
                          '1 USD = ${ReceiptViewModel.khrGroup(receipt.exchangeRateKhr!)} KHR',
                          9,
                          bold: true)),
                  const _Spacer(4),
                  Center(
                      child: _Text(
                          '${l10n.receiptTotal} (Riel):  ${ReceiptViewModel.khrGroup(receipt.khrTotal)} ៛',
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
                const _Spacer(4),
                Center(child: _Text('www.kaknnea.com', 8, color: _grey)),
                const _Spacer(2),
                Center(
                    child: _Text('Powered by ${receipt.businessName}', 7,
                        color: _grey)),
                const _Spacer(20),
              ],
            ),
          ),
        ),
      ),
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

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _Text(label, 8, color: _grey),
        _Text(value, 8, bold: true),
      ]),
    );
  }

  String _adjustmentLabel(AppLocalizations l10n, ReceiptAdjustmentType type) {
    switch (type) {
      case ReceiptAdjustmentType.discount:
        return l10n.receiptDiscount;
      case ReceiptAdjustmentType.delivery:
        return l10n.receiptDelivery;
      case ReceiptAdjustmentType.otherCharge:
        return l10n.receiptOtherCharge;
      case ReceiptAdjustmentType.tax:
        return l10n.receiptTax;
    }
  }

  /// Plain-English label for the clipboard fallback text — mirrors
  /// PrintService's own `_adjustmentLabel` (PDF pipeline has no
  /// BuildContext/l10n available either), so the copied text and the
  /// printed receipt never disagree on wording.
  String _adjustmentPlainLabel(ReceiptAdjustmentType type) {
    switch (type) {
      case ReceiptAdjustmentType.discount:
        return 'Discount';
      case ReceiptAdjustmentType.delivery:
        return 'Delivery';
      case ReceiptAdjustmentType.otherCharge:
        return 'Other Charge';
      case ReceiptAdjustmentType.tax:
        return 'Tax';
    }
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

  // ── Print action ─────────────────────────────────
  // Copies plain text to the clipboard as a fallback, then prints via
  // whichever transport is configured in Settings → Printers: PDF (with the
  // Khmer font embedded) for driver-connected printers, or raw ESC/POS
  // (native text, or a Khmer bitmap when needed) for direct thermal
  // Bluetooth/USB/Network printers — same pipeline as PrintService.

  void _printReceipt(
    BuildContext context,
    WidgetRef ref,
    ReceiptViewModel receipt,
  ) {
    HapticFeedback.mediumImpact();
    Clipboard.setData(ClipboardData(text: _plainTextReceipt(receipt)));
    _printPdfOrThermal(context, ref, receipt);
  }

  String _plainTextReceipt(ReceiptViewModel r) {
    final buf = StringBuffer()
      ..writeln()
      ..writeln('       ${r.businessName}')
      ..writeln();
    if (r.address != null) buf.writeln('  ${r.address}');
    if (r.phone != null) buf.writeln('  Tel: ${r.phone}');
    buf.writeln();
    buf.writeln('  ${r.invoiceNumber}');
    buf.writeln('  ${r.date} ${r.time}');
    if (r.cashierName != null) buf.writeln('  ${r.cashierName}');
    if (r.tableNumber != null) buf.writeln('  ${r.tableNumber}');
    buf.writeln();
    for (final line in r.lines) {
      buf.writeln(
          '  ${line.name.padRight(20)} ${line.qty.toStringAsFixed(0)}${r.fmt(line.lineTotal).padLeft(8)}');
      if (line.modifierSummary != null) {
        buf.writeln('    ${line.modifierSummary}');
      }
    }
    buf.writeln();
    buf.writeln('  Subtotal${r.fmt(r.subtotal).padLeft(24)}');
    for (final adj in r.adjustments) {
      final label = _adjustmentPlainLabel(adj.type);
      buf.writeln('  $label${r.fmtAdjustment(adj).padLeft(32 - label.length)}');
    }
    buf.writeln('  TOTAL${r.fmt(r.total).padLeft(28)}');
    buf.writeln();
    buf.writeln('  Paid${r.fmt(r.paidAmount).padLeft(28)}');
    if (r.changeAmount > 0) {
      buf.writeln(
          '  Cash Received${r.fmt(r.paidAmount + r.changeAmount).padLeft(19)}');
      buf.writeln('  Change${r.fmt(r.changeAmount).padLeft(26)}');
    }
    if (r.showExchangeRate) {
      buf.writeln();
      buf.writeln(
          '  Exchange Rate   1 USD = ${ReceiptViewModel.khrGroup(r.exchangeRateKhr!)} KHR');
      buf.writeln(
          '  Total (Riel)${ReceiptViewModel.khrGroup(r.khrTotal).padLeft(20)} ៛');
    }
    buf.writeln();
    buf.writeln('       ${r.footer}');
    return buf.toString();
  }

  Future<void> _printPdfOrThermal(
    BuildContext context,
    WidgetRef ref,
    ReceiptViewModel receipt,
  ) async {
    try {
      final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
      if (!context.mounted) return;

      if (config.transportType == PrinterTransportType.pdfDriver) {
        // Same PrintService.buildReceiptPdf a reprint from receipts_screen.dart
        // uses — one PDF receipt design in the app, not a second "lightweight"
        // one that visually disagrees with what's on screen.
        final pdfBytes = await ref
            .read(printServiceProvider)
            .buildReceiptPdf(receipt, config.paperSize);
        await Printing.layoutPdf(
          onLayout: (format) async => pdfBytes,
          name: 'receipt_${invoiceNumber ?? "preview"}',
        );
      } else {
        await ref
            .read(thermalPrinterServiceProvider)
            .printReceipt(context, receipt, config);
      }
    } catch (e) {
      debugPrint('Print failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.printerPrintFailed)),
        );
      }
    }
  }
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
/// thermal receipt paper.
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

class SplitRowReceipt {
  final String methodLabel;
  final double amount;
  SplitRowReceipt({required this.methodLabel, required this.amount});
}
