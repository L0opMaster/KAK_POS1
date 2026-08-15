import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/language_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/print_perf.dart';
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

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// print_service.dart` — PARTIAL PORT. `printReceipt`/`buildReceiptPdf`/
/// `_pageContent`/`_receiptPageContent` and all its private row-building
/// helpers are COPY/ADAPT NEARLY EXACTLY for the `pdfDriver` transport —
/// confirmed (like source) zero platform-conditional code needed.
///
/// Two things dropped, both genuinely unreachable in this port today:
///  - `buildReceiptsPdf` (one combined PDF for "Print All") — no caller;
///    `receipts_screen.dart` (Day 12) never built that action. Add it back
///    when/if that day happens, not speculatively.
///  - The Khmer bitmap-image branch of `_pageContent` (source's
///    `_khmerImagePageContent`, via `ReceiptBitmapRenderer`) — that's Day
///    14 scope. `_pageContent` here always takes source's OWN documented
///    fallback path for this exact case ("without a context, a Khmer
///    receipt still renders — via the older `pw.Text` path — rather than
///    failing to produce a PDF at all"): Khmer text renders through
///    `KhmerPdfFont`'s fallback font, imperfectly shaped but functional,
///    never a crash or a missing PDF. `context` stays a parameter so the
///    call sites (and this method's signature) don't need to change again
///    when Day 14 adds the bitmap branch here.
///
/// `printReceipt`'s non-`pdfDriver` branch (bluetooth/usb/network) can
/// only be reached once Settings (Day 19) lets a cashier actually pick
/// one of those — until then `ThermalPrinterService.loadConfig()` always
/// returns `PrinterConfig.defaultConfig` (`pdfDriver`), so it's a
/// currently-unreachable defensive branch, not dead code to delete —
/// deleting it would silently break the day a real Day 15/16/19 transport
/// gets configured.
class PrintService {
  PrintService(this._api, this._ref);

  final ApiService _api;
  final Ref _ref;

  /// Print a receipt for the given [saleId]. Returns true if the print job
  /// was submitted successfully.
  Future<bool> printReceipt(BuildContext context, int saleId) async {
    try {
      final receiptJson = await _api.get<Map<String, dynamic>>(
        '/api/pos/sales/$saleId/receipt',
      );
      if (!context.mounted) return false;
      final receipt = ReceiptResponse.fromJson(receiptJson);
      final language = _ref.read(appLanguageProvider);
      final l10n = AppLocalizations.of(context);
      final viewModel = ReceiptViewModel.fromReceiptResponse(
        receipt,
        language,
        l10n,
      );

      final config = await _ref
          .read(thermalPrinterServiceProvider)
          .loadConfig();
      if (config.transportType == PrinterTransportType.pdfDriver) {
        final pdfBytes = await buildReceiptPdf(
          viewModel,
          config.paperSize,
          context: context,
        );
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'receipt_$saleId',
        );
        return true;
      }
      // Non-PDF transports need Day 15/16's real ESC/POS dispatch — see
      // this class's doc comment for why this branch can't be reached yet.
      debugPrint(
        'Print failed: ${config.transportType.name} transport not '
        'supported yet (Day 15/16).',
      );
      return false;
    } catch (e) {
      debugPrint('Print failed: $e');
      return false;
    }
  }

  /// Generate a PDF receipt from an already-localized [ReceiptViewModel],
  /// sized and margined for [paperSize]. Used for the immediate post-sale
  /// print (`receipt_preview_screen.dart`) and reprints
  /// (`receipts_screen.dart`), so there is exactly one PDF receipt design
  /// in the app, matching the on-screen preview section-for-section.
  Future<Uint8List> buildReceiptPdf(
    ReceiptViewModel r,
    PrinterPaperSize paperSize, {
    BuildContext? context,
  }) async {
    final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
    final content = _pageContent(context, r, paperSize);

    doc.addPage(
      pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content),
    );

    return timePrintStage('receiptPdfDocSave', () => doc.save());
  }

  /// See this class's doc comment for why the Khmer-bitmap branch isn't
  /// here yet — always takes the `pw.Text` path for now.
  pw.Widget _pageContent(
    BuildContext? context,
    ReceiptViewModel r,
    PrinterPaperSize paperSize,
  ) {
    return _receiptPageContent(r, paperSize);
  }

  pw.Widget _receiptPageContent(
    ReceiptViewModel r,
    PrinterPaperSize paperSize,
  ) {
    final t = paperSize.receiptTypography;
    final labels = r.labels;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Header ──
        _clipped(
          r.businessName,
          pw.TextStyle(
            fontSize: t.businessTitle,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.center,
        ),
        if (r.address != null && r.address!.isNotEmpty) ...[
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
            r.address!,
            pw.TextStyle(fontSize: t.businessInfo, color: _grey),
            textAlign: pw.TextAlign.center,
          ),
        ],
        if (r.phone != null && r.phone!.isNotEmpty)
          _clipped(
            labels.telFormat(r.phone!),
            pw.TextStyle(fontSize: t.businessInfo, color: _grey),
            textAlign: pw.TextAlign.center,
          ),
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Invoice metadata ──
        _metadataRow(labels.invoiceNumber, r.invoiceNumber, t),
        _metadataRow(labels.date, r.date, t),
        _metadataRow(labels.time, r.time, t),
        if (r.cashierName != null)
          _metadataRow(labels.cashier, r.cashierName!, t),
        if (r.tableNumber != null)
          _metadataRow(labels.table, r.tableNumber!, t),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Items header ──
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: _clipped(
                labels.item,
                pw.TextStyle(
                  fontSize: t.tableHeader,
                  fontWeight: pw.FontWeight.bold,
                  color: _greyDark,
                ),
              ),
            ),
            pw.SizedBox(
              width: 28,
              child: _clipped(
                labels.qty,
                pw.TextStyle(
                  fontSize: t.tableHeader,
                  fontWeight: pw.FontWeight.bold,
                  color: _greyDark,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.SizedBox(
              width: 50,
              child: _clipped(
                labels.total,
                pw.TextStyle(
                  fontSize: t.tableHeader,
                  fontWeight: pw.FontWeight.bold,
                  color: _greyDark,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        pw.Divider(color: PdfColors.grey300, thickness: 0.75, height: 1),
        pw.SizedBox(height: ReceiptSpacing.dividerGap),

        // ── Line items ──
        if (r.lines.isEmpty)
          _clipped(
            '—',
            pw.TextStyle(fontSize: t.itemName, color: _grey),
            textAlign: pw.TextAlign.center,
          )
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
        _summaryRow(labels.subtotal, r.fmt(r.subtotal), t),
        for (final adj in r.adjustments) ...[
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _summaryRow(adj.type.labelFrom(labels), r.fmtAdjustment(adj), t),
        ],
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        _totalRow(labels.total, r.fmt(r.total), t),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Payment ──
        _summaryRow(labels.paid, r.fmt(r.paidAmount), t, bold: true),
        if (r.changeAmount > 0) ...[
          _summaryRow(
            labels.cashReceived,
            r.fmt(r.paidAmount + r.changeAmount),
            t,
          ),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _summaryRow(labels.change, r.fmt(r.changeAmount), t, color: _green),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
          _dashedDivider(),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
        ],

        // ── Exchange rate ──
        if (r.showExchangeRate) ...[
          _dashedDivider(),
          pw.SizedBox(height: ReceiptSpacing.dividerGap),
          _clipped(
            labels.exchangeRate,
            pw.TextStyle(
              fontSize: t.metadataLabel,
              fontWeight: pw.FontWeight.bold,
              color: _greyDark,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
            labels.exchangeRateValueFormat(
              ReceiptViewModel.khrGroup(r.exchangeRateKhr!),
            ),
            pw.TextStyle(
              fontSize: t.summaryValue,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
            '${labels.totalRiel}:  ${ReceiptViewModel.khrGroup(r.khrTotal)} ៛',
            pw.TextStyle(
              fontSize: t.summaryValue,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
          pw.Divider(color: PdfColors.grey300, thickness: 0.75, height: 1),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
        ],

        // ── Footer ──
        pw.SizedBox(height: ReceiptSpacing.footerGap),
        _clipped(
          r.footer,
          pw.TextStyle(fontSize: t.footer, fontWeight: pw.FontWeight.bold),
          textAlign: pw.TextAlign.center,
        ),
        if (r.website != null && r.website!.isNotEmpty) ...[
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
            r.website!,
            pw.TextStyle(fontSize: t.footerSmall, color: _grey),
            textAlign: pw.TextAlign.center,
          ),
        ],
        pw.SizedBox(height: 2),
        _clipped(
          labels.poweredBy,
          pw.TextStyle(fontSize: t.footerSmall, color: _grey),
          textAlign: pw.TextAlign.center,
        ),
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
            fontSize: t.metadataValue,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
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
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      _clipped(
        value,
        pw.TextStyle(
          fontSize: t.summaryValue,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  pw.Widget _totalRow(String label, String value, ReceiptTypography t) {
    return _safeRow(
      _clipped(
        label,
        pw.TextStyle(fontSize: t.totalLabel, fontWeight: pw.FontWeight.bold),
      ),
      _clipped(
        value,
        pw.TextStyle(fontSize: t.totalValue, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _itemRow(
    ReceiptLineViewModel line,
    ReceiptViewModel r,
    ReceiptTypography t,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _clipped(line.name, pw.TextStyle(fontSize: t.itemName)),
            ),
            pw.SizedBox(
              width: 28,
              child: _clipped(
                line.qty.toStringAsFixed(0),
                pw.TextStyle(fontSize: t.itemQty),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.SizedBox(
              width: 50,
              child: _clipped(
                r.fmt(line.lineTotal),
                pw.TextStyle(
                  fontSize: t.itemPrice,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        if (line.modifierSummary != null && line.modifierSummary!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1),
            child: _clipped(
              line.modifierSummary!,
              pw.TextStyle(fontSize: t.itemNote, color: _grey),
            ),
          ),
        if (line.note != null && line.note!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 1),
            child: _clipped(
              line.note!,
              pw.TextStyle(fontSize: t.itemNote, color: _grey),
            ),
          ),
      ],
    );
  }
}

/// A left widget that fills all remaining row width, and a right widget
/// pinned to its natural width — so the row's total width can never exceed
/// the page's content width.
pw.Widget _safeRow(pw.Widget left, pw.Widget right) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(child: left),
      right,
    ],
  );
}

/// A [pw.Text] with `overflow: clip` instead of the default
/// `TextOverflow.visible`. `package:pdf` only wraps on whitespace; Khmer
/// script is traditionally written without spaces between words, so an
/// unbroken long Khmer name has no internal wrap point — without an
/// explicit clip it would render past the receipt's content width.
pw.Widget _clipped(String text, pw.TextStyle style, {pw.TextAlign? textAlign}) {
  return pw.Text(
    text,
    style: style,
    textAlign: textAlign,
    overflow: pw.TextOverflow.clip,
  );
}

/// Mirrors the on-screen preview's dashed divider (`receipt_paper_view
/// .dart`'s `_dashed`).
pw.Widget _dashedDivider() => pw.Divider(
  color: PdfColors.grey300,
  thickness: 0.75,
  height: 1,
  borderStyle: pw.BorderStyle.dashed,
);

final printServiceProvider = Provider<PrintService>((ref) {
  return PrintService(ref.read(apiServiceProvider), ref);
});
