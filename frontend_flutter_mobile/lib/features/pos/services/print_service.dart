import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

import '../../../core/providers/language_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/khmer_text.dart';
import '../../../core/utils/print_perf.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/receipt_models.dart';
import 'printing/khmer_pdf_font.dart';
import 'printing/printer_pdf_format.dart';
import 'printing/printer_profile.dart';
import 'printing/receipt_bitmap_renderer.dart';
import 'printing/receipt_layout_spec.dart';
import 'printing/receipt_view_model.dart';
import 'printing/thermal_printer_service.dart';
import 'printing/ticket_line_widgets.dart';

const _grey = PdfColor.fromInt(0xFF999999);
const _greyDark = PdfColor.fromInt(0xFF666666);
const _green = PdfColor.fromInt(0xFF4CAF50);

/// Ported from `frontend-flutter-pos/lib/features/pos/services/
/// print_service.dart` — PARTIAL PORT. `printReceipt`/`buildReceiptPdf`/
/// `_pageContent`/`_khmerImagePageContent`/`_receiptPageContent` and all
/// its private row-building helpers are COPY/ADAPT NEARLY EXACTLY —
/// confirmed (like source) zero platform-conditional code needed anywhere
/// in this pipeline, PDF or Khmer-bitmap-embedded PDF alike.
///
/// One thing dropped, genuinely unreachable in this port today:
/// `buildReceiptsPdf` (one combined PDF for "Print All") — no caller;
/// `receipts_screen.dart` (Day 12) never built that action. Add it back
/// when/if that action happens, not speculatively.
///
/// `printReceipt`'s non-`pdfDriver` branch (bluetooth/usb/network, wired
/// via `ThermalPrinterService.printReceipt` — Day 15/16) can only be
/// reached once Settings (Day 19) lets a cashier actually pick one of
/// those — until then `ThermalPrinterService.loadConfig()` always returns
/// `PrinterConfig.defaultConfig` (`pdfDriver`), so it's a
/// currently-unreachable defensive branch, not dead code to delete —
/// deleting it would silently break the day a real Day 19 transport gets
/// configured.
class PrintService {
  PrintService(
    this._api,
    this._ref, {
    this.bitmapRenderer = const ReceiptBitmapRenderer(),
  });

  final ApiService _api;
  final Ref _ref;

  /// Injectable for tests — the same pattern [EscPosReceiptBuilder]
  /// (Day 15) uses to substitute a fake renderer that skips real
  /// off-screen widget mounting (which needs a live `Overlay`/frame pump).
  final ReceiptBitmapRenderer bitmapRenderer;

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

      return printReceiptViewModel(
        context,
        viewModel,
        jobName: 'receipt_$saleId',
      );
    } catch (e) {
      debugPrint('Print failed: $e');
      return false;
    }
  }

  /// Print an already-built [receipt] directly — no backend sale lookup.
  /// Used for [printReceipt] itself (after it fetches and builds the view
  /// model) and for a pre-payment "bill" print of an in-progress cart or
  /// held ticket (see [ReceiptViewModel.fromCart]), where no sale exists
  /// yet. Shares the exact PDF/thermal transport branching [printReceipt]
  /// already used, so a pre-payment bill and the final paid receipt always
  /// come out of the same pipeline. Returns true if the print job was
  /// submitted successfully.
  Future<bool> printReceiptViewModel(
    BuildContext context,
    ReceiptViewModel receipt, {
    required String jobName,
  }) async {
    try {
      final config = await _ref
          .read(thermalPrinterServiceProvider)
          .loadConfig();
      if (!context.mounted) return false;
      if (config.transportType == PrinterTransportType.pdfDriver) {
        final pdfBytes = await buildReceiptPdf(
          receipt,
          config.paperSize,
          context: context,
        );
        await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: jobName);
      } else {
        if (!context.mounted) return false;
        await _ref
            .read(thermalPrinterServiceProvider)
            .printReceipt(context, receipt, config);
      }
      return true;
    } catch (e) {
      if (e is ReceiptRenderException) {
        debugPrint('Khmer receipt render failed: ${e.message}');
      } else {
        debugPrint('Print failed: $e');
      }
      return false;
    }
  }

  /// Prints a compact queue-number ticket — just the number in large print,
  /// not an itemized bill — so a customer can carry it and be called up
  /// when their order is ready. Distinct from [printReceiptViewModel],
  /// which always renders the full receipt layout (header/items/totals)
  /// that a bare number ticket has no use for.
  ///
  /// [heading]/[instruction] are best-effort labels (e.g. "Your Number" /
  /// "Please come to the counter when your number is called") — the PDF
  /// path renders them through [KhmerPdfFont]'s fallback-aware theme same
  /// as every other PDF in the app. Native ESC/POS text has no Khmer glyphs
  /// at all, so if any of [businessName]/[heading]/[instruction] is Khmer,
  /// the whole ticket is rasterized as one bitmap via
  /// [ReceiptBitmapRenderer.renderWidget] (see [WaitingNumberTicketContent])
  /// instead of native ESC/POS text — a fully Latin/English ticket stays
  /// fast native text. Returns true if the print job was submitted
  /// successfully.
  Future<bool> printWaitingNumberTicket(
    BuildContext context, {
    required int waitingNumber,
    String? businessName,
    String? heading,
    String? instruction,
  }) async {
    final numberText = '#${waitingNumber.toString().padLeft(3, '0')}';
    // Native pw.Text (PDF) and native ESC/POS text both need this same
    // decision: package:pdf's font-fallback shaping isn't reliable for
    // Khmer (see [_khmerImagePageContent]'s doc comment) and native ESC/POS
    // text has no Khmer glyphs at all — so on EITHER transport, if any of
    // businessName/heading/instruction is Khmer, the whole ticket is
    // rasterized as one Flutter-shaped bitmap via WaitingNumberTicketContent
    // instead of native text. Computed once here so both builders below
    // agree on the same decision.
    final hasKhmer = [
      businessName,
      heading,
      instruction,
    ].whereType<String>().any(containsKhmerText);
    try {
      final config = await _ref
          .read(thermalPrinterServiceProvider)
          .loadConfig();
      if (!context.mounted) return false;
      if (config.transportType == PrinterTransportType.pdfDriver) {
        final pdfBytes = await _buildWaitingNumberPdf(
          context,
          numberText,
          config.paperSize,
          hasKhmer: hasKhmer,
          businessName: businessName,
          heading: heading,
          instruction: instruction,
        );
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'ticket_$waitingNumber',
        );
      } else {
        if (!context.mounted) return false;
        final bytes = await _buildWaitingNumberEscPos(
          context,
          numberText,
          config.paperSize,
          hasKhmer: hasKhmer,
          businessName: businessName,
          heading: heading,
          instruction: instruction,
        );
        await _ref.read(thermalPrinterServiceProvider).printRaw(bytes, config);
      }
      return true;
    } catch (e) {
      debugPrint('Waiting number ticket print failed: $e');
      return false;
    }
  }

  Future<Uint8List> _buildWaitingNumberPdf(
    BuildContext context,
    String numberText,
    PrinterPaperSize paperSize, {
    required bool hasKhmer,
    String? businessName,
    String? heading,
    String? instruction,
  }) async {
    final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
    final content = hasKhmer && context.mounted
        ? await _khmerImageWidgetContent(
            context,
            WaitingNumberTicketContent(
              businessName: businessName,
              heading: heading,
              numberText: numberText,
              instruction: instruction,
            ),
            paperSize,
          )
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              if (businessName != null && businessName.isNotEmpty) ...[
                pw.Text(
                  businessName,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: ReceiptSpacing.smallGap),
              ],
              if (heading != null && heading.isNotEmpty) ...[
                pw.Text(
                  heading,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 13, color: _greyDark),
                ),
                pw.SizedBox(height: ReceiptSpacing.sectionGap),
              ],
              // Bordered box around the number — same "ticket stub" touch
              // as WaitingNumberTicketContent (the Khmer bitmap path's
              // widget), so the printed ticket looks the same regardless
              // of which pipeline produced it. Stretched to the page's full
              // available width (via the outer Column's `stretch`, not
              // wrapped in `pw.Center`) so FittedBox has a genuinely bounded
              // width to shrink into — at a fixed 64pt, "#055" plus this
              // box's own padding doesn't fit `mm58`'s ~136pt usable width
              // (only `mm80`'s ~204pt), so without this the number silently
              // overflowed/clipped on the small paper size specifically.
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  child: pw.Text(
                    numberText,
                    style: pw.TextStyle(
                      fontSize: 64,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (instruction != null && instruction.isNotEmpty) ...[
                pw.SizedBox(height: ReceiptSpacing.sectionGap),
                pw.Text(
                  instruction,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 11, color: _greyDark),
                ),
              ],
            ],
          );
    doc.addPage(
      pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content),
    );
    return doc.save();
  }

  Future<List<int>> _buildWaitingNumberEscPos(
    BuildContext context,
    String numberText,
    PrinterPaperSize paperSize, {
    required bool hasKhmer,
    String? businessName,
    String? heading,
    String? instruction,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize.escPosPaperSize, profile);
    var bytes = <int>[];
    bytes += generator.reset();

    if (hasKhmer) {
      final image = await bitmapRenderer.renderWidget(
        context,
        WaitingNumberTicketContent(
          businessName: businessName,
          heading: heading,
          numberText: numberText,
          instruction: instruction,
        ),
        paperSize,
      );
      bytes += generator.imageRaster(image, align: PosAlign.center);
    } else {
      void line(
        String text, {
        bool bold = false,
        PosTextSize size = PosTextSize.size1,
      }) {
        bytes += generator.text(
          text,
          styles: PosStyles(
            align: PosAlign.center,
            bold: bold,
            height: size,
            width: size,
          ),
        );
      }

      if (businessName != null && businessName.isNotEmpty) {
        line(businessName, bold: true);
      }
      if (heading != null && heading.isNotEmpty) {
        line(heading);
      }
      bytes += generator.feed(1);
      line(numberText, bold: true, size: PosTextSize.size6);
      bytes += generator.feed(1);
      if (instruction != null && instruction.isNotEmpty) {
        line(instruction);
      }
    }

    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
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
    final content = await _pageContent(context, r, paperSize);

    doc.addPage(
      pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content),
    );

    return timePrintStage('receiptPdfDocSave', () => doc.save());
  }

  /// [context] present and [r] Khmer → Flutter-rendered bitmap embedded as
  /// a `pw.Image`. Otherwise → the existing `pw.Text`-based layout. Without
  /// a [context], a Khmer receipt still renders — via the `pw.Text` path —
  /// rather than failing to produce a PDF at all.
  Future<pw.Widget> _pageContent(
    BuildContext? context,
    ReceiptViewModel r,
    PrinterPaperSize paperSize,
  ) async {
    if (r.containsKhmer && context != null && context.mounted) {
      return _khmerImagePageContent(context, r, paperSize);
    }
    return _receiptPageContent(r, paperSize);
  }

  /// Renders [r] via [ReceiptBitmapRenderer] (the same renderer the ESC/POS
  /// thermal path uses for Khmer receipts — see `escpos_receipt_builder
  /// .dart`, Day 15) and embeds it as a single full-page image, sized to
  /// exactly fill the receipt's printable content width
  /// (`paperSize.pdfPageFormat.availableWidth`) with height computed from
  /// the source image's own aspect ratio, so it's never stretched/distorted
  /// and never needs a second resize pass after rendering.
  ///
  /// Embeds the decoded `image` package raster directly via [pw.ImageImage]
  /// instead of going through [pw.MemoryImage] with a PNG-encoded byte
  /// array, which would round-trip freshly-rendered pixels through a PNG
  /// encode only to have `doc.save()` immediately decode that same PNG
  /// again — pure waste, since [pw.ImageImage] accepts [decoded] as-is.
  Future<pw.Widget> _khmerImagePageContent(
    BuildContext context,
    ReceiptViewModel r,
    PrinterPaperSize paperSize,
  ) async {
    final decoded = await timePrintStage(
      'receiptPdfBitmapRender',
      () => bitmapRenderer.renderImage(context, r, paperSize),
    );
    if (kDebugMode) {
      debugPrint(
        '[PrintPerf] receiptPdfBitmapDimensions='
        '${decoded.width}x${decoded.height} '
        'rawBytes=${decoded.width * decoded.height * 4}',
      );
    }
    final targetWidth = paperSize.pdfPageFormat.availableWidth;
    final targetHeight = targetWidth * decoded.height / decoded.width;
    return pw.Image(
      pw.ImageImage(decoded),
      width: targetWidth,
      height: targetHeight,
      fit: pw.BoxFit.fill,
    );
  }

  /// [_khmerImagePageContent], generalized to an arbitrary Flutter [child]
  /// widget instead of a [ReceiptViewModel] — used by the waiting-number
  /// ticket PDF builder, which has no [ReceiptViewModel] of its own but
  /// needs the exact same "never send Khmer through pw.Text + font-fallback
  /// shaping" treatment (see [_khmerImagePageContent]'s doc comment for why
  /// that's unreliable for Khmer specifically).
  Future<pw.Widget> _khmerImageWidgetContent(
    BuildContext context,
    Widget child,
    PrinterPaperSize paperSize,
  ) async {
    final decoded = await timePrintStage(
      'receiptPdfBitmapRender',
      () => bitmapRenderer.renderWidgetImage(context, child, paperSize),
    );
    if (kDebugMode) {
      debugPrint(
        '[PrintPerf] receiptPdfBitmapDimensions='
        '${decoded.width}x${decoded.height} '
        'rawBytes=${decoded.width * decoded.height * 4}',
      );
    }
    final targetWidth = paperSize.pdfPageFormat.availableWidth;
    final targetHeight = targetWidth * decoded.height / decoded.width;
    return pw.Image(
      pw.ImageImage(decoded),
      width: targetWidth,
      height: targetHeight,
      fit: pw.BoxFit.fill,
    );
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
