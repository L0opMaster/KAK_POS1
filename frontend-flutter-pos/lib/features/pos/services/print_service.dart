// Printing service for generating and printing receipts.
//
// Two pipelines, chosen by the printer configured in Settings → Printers
// (see [PrinterConfig]):
//  - [PrinterTransportType.pdfDriver]: renders a PDF (with the bundled
//    Khmer font embedded) and hands it to the OS print dialog via the
//    `printing` package — for driver-connected / large-format printers.
//  - bluetooth/usb/network: builds raw ESC/POS bytes (native text, or a
//    Khmer bitmap when needed) via [ThermalPrinterService] and writes them
//    directly to the transport — for thermal printers with no OS driver.
//
// Both pipelines render from the same [ReceiptViewModel] (see
// `printing/receipt_view_model.dart`), and this PDF pipeline draws its
// sections, typography and spacing from `printing/receipt_layout_spec.dart`
// — the same values receipt_preview_screen.dart's on-screen widgets were
// measured from — so the printed PDF cannot silently drift back into a
// different-looking document than what the cashier saw on screen.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/language_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/receipt_models.dart';
import 'printing/khmer_pdf_font.dart';
import 'printing/printer_pdf_format.dart';
import 'printing/printer_profile.dart';
import 'printing/receipt_layout_spec.dart';
import 'printing/receipt_view_model.dart';
import 'printing/thermal_printer_service.dart';

const _grey = PdfColor.fromInt(0xFF999999);
const _greyDark = PdfColor.fromInt(0xFF666666);
const _green = PdfColor.fromInt(0xFF4CAF50);

class PrintService {
  PrintService(this._api, this._ref);

  final ApiService _api;
  final Ref _ref;

  /// Print a receipt for the given [saleId]. [context] must be mounted —
  /// callers invoking this after an `await` must check `mounted` first,
  /// since it may need to rasterize a Khmer bitmap (see
  /// [ThermalPrinterService.printReceipt]).
  /// Returns true if the print job was submitted successfully.
  Future<bool> printReceipt(BuildContext context, int saleId) async {
    try {
      final receiptJson = await _api
          .get<Map<String, dynamic>>('/api/pos/sales/$saleId/receipt');
      if (!context.mounted) return false;
      final receipt = ReceiptResponse.fromJson(receiptJson);
      final language = _ref.read(appLanguageProvider);
      final l10n = AppLocalizations.of(context);
      final viewModel =
          ReceiptViewModel.fromReceiptResponse(receipt, language, l10n);

      final config =
          await _ref.read(thermalPrinterServiceProvider).loadConfig();
      if (config.transportType == PrinterTransportType.pdfDriver) {
        final pdfBytes = await buildReceiptPdf(viewModel, config.paperSize);
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'receipt_$saleId',
        );
      } else {
        if (!context.mounted) return false;
        await _ref
            .read(thermalPrinterServiceProvider)
            .printReceipt(context, viewModel, config);
      }
      return true;
    } catch (e) {
      debugPrint('Print failed: $e');
      return false;
    }
  }

  /// Generate a PDF receipt from an already-localized [ReceiptViewModel],
  /// sized and margined for [paperSize] (see `printing/printer_pdf_format.dart`)
  /// and typeset from `printing/receipt_layout_spec.dart` — the single
  /// production receipt PDF builder. Used for the immediate post-sale print
  /// (receipt_preview_screen.dart), reprints (receipts_screen.dart), and the
  /// developer print test screen, so there is exactly one PDF receipt design
  /// in the app, matching the on-screen preview section-for-section.
  Future<Uint8List> buildReceiptPdf(
    ReceiptViewModel r,
    PrinterPaperSize paperSize,
  ) async {
    final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());

    doc.addPage(
      pw.Page(
        pageFormat: paperSize.pdfPageFormat,
        build: (context) => _receiptPageContent(r, paperSize),
      ),
    );

    return doc.save();
  }

  /// Builds ONE PDF document containing every receipt in [receipts], each
  /// on its own page (in `package:pdf`, a fresh [pw.Page] is a hard page
  /// boundary — the same boundary a single-receipt job already gets, just
  /// repeated). Used by "Print All" on [ReceiptsScreen] so a PDF/driver
  /// printer gets exactly one print job — and one OS print dialog — no
  /// matter how many receipts are in the batch, instead of one job per
  /// receipt. Each page reuses the identical layout [buildReceiptPdf] draws
  /// for a single receipt (via [_receiptPageContent]), so a batch-printed
  /// receipt is pixel-for-pixel the same as one printed individually.
  ///
  /// Note: nothing in the `pw`/OS-driver pipeline can command a physical
  /// receipt-printer's cutter between logical receipts — the page boundary
  /// only separates *pages*, not "cut here" instructions a driver-attached
  /// printer will act on. For roll printers with an auto-cutter, use the
  /// direct ESC/POS transport (bluetooth/usb/network) instead, where
  /// [ThermalPrinterService.printReceipts] issues a real cut after each
  /// receipt.
  Future<Uint8List> buildReceiptsPdf(
    List<ReceiptViewModel> receipts,
    PrinterPaperSize paperSize,
  ) async {
    final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());

    for (final r in receipts) {
      doc.addPage(
        pw.Page(
          pageFormat: paperSize.pdfPageFormat,
          build: (context) => _receiptPageContent(r, paperSize),
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _receiptPageContent(
      ReceiptViewModel r, PrinterPaperSize paperSize) {
    final t = paperSize.receiptTypography;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        _clipped(
          r.businessName,
          pw.TextStyle(
              fontSize: t.businessTitle, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        if (r.address != null && r.address!.isNotEmpty) ...[
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
              r.address!, pw.TextStyle(fontSize: t.businessInfo, color: _grey),
              textAlign: pw.TextAlign.center),
        ],
        if (r.phone != null && r.phone!.isNotEmpty)
          _clipped('Tel: ${r.phone}',
              pw.TextStyle(fontSize: t.businessInfo, color: _grey),
              textAlign: pw.TextAlign.center),
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Invoice metadata ──
        _metadataRow('Invoice No.', r.invoiceNumber, t),
        _metadataRow('Date', r.date, t),
        _metadataRow('Time', r.time, t),
        if (r.cashierName != null) _metadataRow('Cashier', r.cashierName!, t),
        if (r.tableNumber != null) _metadataRow('Table', r.tableNumber!, t),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Items header ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
                child: _clipped(
                    'Item',
                    pw.TextStyle(
                        fontSize: t.tableHeader,
                        fontWeight: pw.FontWeight.bold,
                        color: _greyDark))),
            pw.SizedBox(
                width: 28,
                child: _clipped(
                    'Qty',
                    pw.TextStyle(
                        fontSize: t.tableHeader,
                        fontWeight: pw.FontWeight.bold,
                        color: _greyDark),
                    textAlign: pw.TextAlign.right)),
            pw.SizedBox(
                width: 50,
                child: _clipped(
                    'Total',
                    pw.TextStyle(
                        fontSize: t.tableHeader,
                        fontWeight: pw.FontWeight.bold,
                        color: _greyDark),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        pw.Divider(color: PdfColors.grey300, thickness: 0.75, height: 1),
        pw.SizedBox(height: ReceiptSpacing.dividerGap),

        // ── Line items ──
        if (r.lines.isEmpty)
          _clipped('—', pw.TextStyle(fontSize: t.itemName, color: _grey),
              textAlign: pw.TextAlign.center)
        else
          ...r.lines.expand((line) sync* {
            yield _itemRow(line, r, t);
            if (line != r.lines.last) {
              yield pw.SizedBox(height: ReceiptSpacing.rowGap);
            }
          }),

        pw.SizedBox(height: ReceiptSpacing.sectionGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Totals ──
        _summaryRow('Subtotal', r.fmt(r.subtotal), t),
        for (final adj in r.adjustments) ...[
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _summaryRow(_adjustmentLabel(adj.type), r.fmtAdjustment(adj), t),
        ],
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        _totalRow('Total', r.fmt(r.total), t),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Payment ──
        _summaryRow('Paid', r.fmt(r.paidAmount), t, bold: true),
        if (r.changeAmount > 0) ...[
          // Cash Received (= paidAmount + changeAmount, what the customer
          // actually handed over) makes Change legible — Paid alone is the
          // amount APPLIED to the sale (never more than the total), so
          // Change would otherwise look like it appeared from nowhere.
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _summaryRow('Cash Received', r.fmt(r.paidAmount + r.changeAmount), t),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _summaryRow('Change', r.fmt(r.changeAmount), t, color: _green),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
          _dashedDivider(),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
        ],

        // ── Exchange rate ──
        if (r.showExchangeRate) ...[
          _dashedDivider(),
          pw.SizedBox(height: ReceiptSpacing.dividerGap),
          _clipped(
              'Exchange rate',
              pw.TextStyle(
                  fontSize: t.metadataLabel,
                  fontWeight: pw.FontWeight.bold,
                  color: _greyDark),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
              '1 USD = ${ReceiptViewModel.khrGroup(r.exchangeRateKhr!)} KHR',
              pw.TextStyle(
                  fontSize: t.summaryValue, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
              'Total (Riel):  ${ReceiptViewModel.khrGroup(r.khrTotal)} ៛',
              pw.TextStyle(
                  fontSize: t.summaryValue, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
          pw.Divider(color: PdfColors.grey300, thickness: 0.75, height: 1),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
        ],

        // ── Footer ──
        pw.SizedBox(height: ReceiptSpacing.footerGap),
        _clipped(r.footer,
            pw.TextStyle(fontSize: t.footer, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        _clipped('www.kaknnea.com',
            pw.TextStyle(fontSize: t.footerSmall, color: _grey),
            textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        _clipped('Powered by ${r.businessName}',
            pw.TextStyle(fontSize: t.footerSmall, color: _grey),
            textAlign: pw.TextAlign.center),
      ],
    );
  }

  pw.Widget _metadataRow(String label, String value, ReceiptTypography t) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: _safeRow(
        _clipped(label, pw.TextStyle(fontSize: t.metadataLabel, color: _grey)),
        _clipped(
            value,
            pw.TextStyle(
                fontSize: t.metadataValue, fontWeight: pw.FontWeight.bold)),
      ),
    );
  }

  pw.Widget _summaryRow(
    String label,
    String value,
    ReceiptTypography t, {
    bool bold = false,
    PdfColor? color,
  }) {
    return _safeRow(
      _clipped(
          label,
          pw.TextStyle(
              fontSize: t.summaryLabel,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      _clipped(
          value,
          pw.TextStyle(
              fontSize: t.summaryValue,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: color)),
    );
  }

  /// Plain-English label for a [ReceiptAdjustment] row — this PDF pipeline
  /// doesn't have a BuildContext/l10n available at every call site (e.g.
  /// reprints, the developer test screen), matching every other label in
  /// this file (Item/Qty/Total/Subtotal/Paid/...).
  String _adjustmentLabel(ReceiptAdjustmentType type) {
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

  pw.Widget _totalRow(String label, String value, ReceiptTypography t) {
    return _safeRow(
      _clipped(label,
          pw.TextStyle(fontSize: t.totalLabel, fontWeight: pw.FontWeight.bold)),
      _clipped(value,
          pw.TextStyle(fontSize: t.totalValue, fontWeight: pw.FontWeight.bold)),
    );
  }

  pw.Widget _itemRow(
      ReceiptLineViewModel line, ReceiptViewModel r, ReceiptTypography t) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
                child: _clipped(line.name, pw.TextStyle(fontSize: t.itemName))),
            pw.SizedBox(
                width: 28,
                child: _clipped(line.qty.toStringAsFixed(0),
                    pw.TextStyle(fontSize: t.itemQty),
                    textAlign: pw.TextAlign.right)),
            pw.SizedBox(
                width: 50,
                child: _clipped(
                    r.fmt(line.lineTotal),
                    pw.TextStyle(
                        fontSize: t.itemPrice, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.right)),
          ],
        ),
        if (line.modifierSummary != null && line.modifierSummary!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1),
            child: _clipped(line.modifierSummary!,
                pw.TextStyle(fontSize: t.itemNote, color: _grey)),
          ),
        if (line.note != null && line.note!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1),
            child: _clipped(
                line.note!, pw.TextStyle(fontSize: t.itemNote, color: _grey)),
          ),
      ],
    );
  }
}

/// A left widget that fills all remaining row width, and a right widget
/// pinned to its natural (intrinsic) width — used instead of a plain
/// `pw.Row(mainAxisAlignment: spaceBetween, ...)` so the row's total width
/// can never exceed the page's content width: an oversized [left] wraps or
/// clips against its `Expanded` bound instead of pushing [right] off the
/// page. See [_clipped] for the matching text-overflow guarantee.
pw.Widget _safeRow(pw.Widget left, pw.Widget right) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: left),
      right,
    ],
  );
}

/// A [pw.Text] with `overflow: clip` instead of the document theme's
/// default `TextOverflow.visible`. `package:pdf` only knows how to wrap on
/// whitespace (`RegExp(r'\s')`); Khmer script is traditionally written
/// without spaces between words, so an unbroken long Khmer name has no
/// internal wrap point at all. Without an explicit `clip`, that name would
/// render past the receipt's content width (see
/// `printing/printer_pdf_format.dart`) instead of staying inside it. Normal
/// text with spaces still wraps across lines exactly as before — this only
/// changes what happens to the (rare) unbreakable token that doesn't fit.
pw.Widget _clipped(
  String text,
  pw.TextStyle style, {
  pw.TextAlign? textAlign,
}) {
  return pw.Text(
    text,
    style: style,
    textAlign: textAlign,
    overflow: pw.TextOverflow.clip,
  );
}

/// Mirrors the on-screen preview's `_dashed` divider (receipt_preview_screen
/// .dart) — a row of short dashes rather than a solid `pw.Divider`, used
/// between major receipt sections. `pw.Divider`'s own `BorderStyle.dashed`
/// draws through `Container`'s border painter, which is the more reliable
/// way to get a dashed line in package:pdf than hand-building one from
/// SizedBoxes (what the Flutter-side widget does, since Flutter's Container
/// has no built-in dashed-border support).
pw.Widget _dashedDivider() => pw.Divider(
      color: PdfColors.grey300,
      thickness: 0.75,
      height: 1,
      borderStyle: pw.BorderStyle.dashed,
    );

final printServiceProvider = Provider<PrintService>((ref) {
  return PrintService(ref.read(apiServiceProvider), ref);
});
