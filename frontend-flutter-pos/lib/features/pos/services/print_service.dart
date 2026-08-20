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
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/khmer_text.dart';
import '../../../core/utils/print_perf.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/receipt_models.dart';
import '../screens/payment_screen.dart' show PaymentMethodX;
import 'printing/khmer_pdf_font.dart';
import 'printing/printer_pdf_format.dart';
import 'printing/printer_profile.dart';
import 'printing/receipt_bitmap_renderer.dart';
import 'printing/receipt_labels.dart';
import 'printing/receipt_layout_spec.dart';
import 'printing/receipt_view_model.dart';
import 'printing/thermal_printer_service.dart';
import 'printing/ticket_line_widgets.dart';

const _grey = PdfColor.fromInt(0xFF999999);
const _greyDark = PdfColor.fromInt(0xFF666666);
const _green = PdfColor.fromInt(0xFF4CAF50);

/// Warning/pending color for a pre-payment bill's "UNPAID" status — matches
/// receipt_paper_view.dart's `_amber`, never used on a paid receipt.
const _amber = PdfColor.fromInt(0xFFE08900);

class PrintService {
  PrintService(this._api, this._ref,
      {this.bitmapRenderer = const ReceiptBitmapRenderer()});

  final ApiService _api;
  final Ref _ref;

  /// Injectable for tests — the same pattern [EscPosReceiptBuilder] already
  /// uses to substitute a fake renderer that skips real off-screen widget
  /// mounting (which needs a live `Overlay`/frame pump; see that class's
  /// test file for why this matters).
  final ReceiptBitmapRenderer bitmapRenderer;

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
      return printReceiptViewModel(context, viewModel,
          jobName: 'receipt_$saleId');
    } catch (e) {
      debugPrint('Print failed: $e');
      return false;
    }
  }

  /// Print an already-built [receipt] directly — no backend sale lookup.
  /// Used for [printReceipt] itself (after it fetches and builds the
  /// view model) and for a pre-payment "bill" print of an in-progress cart
  /// (see [ReceiptViewModel.fromCart]), where no sale exists yet. Shares the
  /// exact PDF/thermal transport branching [printReceipt] already used, so a
  /// pre-payment bill and the final paid receipt always come out of the same
  /// pipeline. Returns true if the print job was submitted successfully.
  Future<bool> printReceiptViewModel(
    BuildContext context,
    ReceiptViewModel receipt, {
    required String jobName,
  }) async {
    try {
      final config =
          await _ref.read(thermalPrinterServiceProvider).loadConfig();
      if (!context.mounted) return false;
      if (config.transportType == PrinterTransportType.pdfDriver) {
        final pdfBytes = await buildReceiptPdf(receipt, config.paperSize,
            context: context);
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: jobName,
        );
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
  /// at all (see [EscPosReceiptBuilder]'s doc comment), so if any of
  /// [businessName]/[heading]/[instruction] is Khmer, the whole ticket is
  /// rasterized as one bitmap via [ReceiptBitmapRenderer.renderWidget]
  /// (see [WaitingNumberTicketContent]) instead of native ESC/POS text — a
  /// fully Latin/English ticket stays fast native text. Returns true if the
  /// print job was submitted successfully.
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
    final hasKhmer = [businessName, heading, instruction]
        .whereType<String>()
        .any(containsKhmerText);
    try {
      final config =
          await _ref.read(thermalPrinterServiceProvider).loadConfig();
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
                pw.Text(businessName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: ReceiptSpacing.smallGap),
              ],
              if (heading != null && heading.isNotEmpty) ...[
                pw.Text(heading,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 13, color: _greyDark)),
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
                    horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.FittedBox(
                  fit: pw.BoxFit.scaleDown,
                  child: pw.Text(numberText,
                      style: pw.TextStyle(
                          fontSize: 64, fontWeight: pw.FontWeight.bold)),
                ),
              ),
              if (instruction != null && instruction.isNotEmpty) ...[
                pw.SizedBox(height: ReceiptSpacing.sectionGap),
                pw.Text(instruction,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: 11, color: _greyDark)),
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
      void line(String text,
          {bool bold = false, PosTextSize size = PosTextSize.size1}) {
        bytes += generator.text(
          text,
          styles: PosStyles(
              align: PosAlign.center, bold: bold, height: size, width: size),
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

  /// Prints a "Credit Payment Receipt" — the transaction-only stub for one
  /// repayment against a credit sale (previous/paid/remaining balance, due
  /// date, method), not the full itemized bill. Distinct from
  /// [printReceiptViewModel] (which prints the itemized sale receipt — used
  /// for the *initial* credit sale) the same way [printWaitingNumberTicket]
  /// is distinct from it: a lightweight, non-[ReceiptViewModel] layout built
  /// directly with the same PDF/ESC-POS primitives.
  ///
  /// Every label is resolved once here via [_CreditPaymentLabels.fromL10n]
  /// and [method] (a raw code like `'CASH'`/`'KHQR'`, see
  /// `payment_screen.dart`'s `PaymentMethod.code`) is resolved to its
  /// display label the same way the payment screen itself does — this used
  /// to hardcode every label in English and print [method] verbatim, so a
  /// Khmer-language store's printed credit-payment stub never matched the
  /// rest of the (localized) app. [customerName]/[cashierName] are
  /// user-entered and can independently be Khmer even when [context]'s
  /// language is English. On a thermal transport, if anything on the ticket
  /// is Khmer, the whole ticket is rasterized as one bitmap via
  /// [ReceiptBitmapRenderer.renderWidget] (see
  /// [CreditPaymentReceiptContent]) instead of native ESC/POS text, which
  /// has no Khmer glyphs at all. Returns true if the print job was
  /// submitted successfully.
  Future<bool> printCreditPaymentReceipt(
    BuildContext context, {
    required String creditSaleNumber,
    required String customerName,
    required double amount,
    required double previousBalance,
    required double remainingBalance,
    DateTime? dueDate,
    required String method,
    String? cashierName,
    String currency = 'KHR',
  }) async {
    try {
      final l10n = AppLocalizations.of(context);
      final labels = _CreditPaymentLabels.fromL10n(l10n);
      final methodLabel = PaymentMethodX.fromCode(method).label(l10n);
      final dueDateText = dueDate == null ? null : _formatDate(dueDate);
      // Native pw.Text (PDF) and native ESC/POS text both need this same
      // decision: package:pdf's font-fallback shaping isn't reliable for
      // Khmer (see [_khmerImagePageContent]'s doc comment) and native
      // ESC/POS text has no Khmer glyphs at all. Once the receipt's own
      // labels are localized, a Khmer-language store has Khmer text on
      // nearly every row (not just an occasional Khmer customer name), so
      // rather than decide per-row, check once here and, if anything at
      // all is Khmer, rasterize the whole ticket as one Flutter-shaped
      // bitmap via CreditPaymentReceiptContent on EITHER transport. Native
      // text stays the fast path for a fully Latin/English ticket.
      final hasKhmer = <String>[
        labels.title,
        labels.creditSale,
        labels.customer,
        labels.cashier,
        labels.previousBalance,
        labels.payment,
        labels.remaining,
        labels.dueDate,
        labels.method,
        customerName,
        cashierName ?? '',
        methodLabel,
      ].any(containsKhmerText);
      final config =
          await _ref.read(thermalPrinterServiceProvider).loadConfig();
      if (!context.mounted) return false;
      if (config.transportType == PrinterTransportType.pdfDriver) {
        final pdfBytes = await _buildCreditPaymentPdf(
          context,
          config.paperSize,
          hasKhmer: hasKhmer,
          labels: labels,
          creditSaleNumber: creditSaleNumber,
          customerName: customerName,
          amount: amount,
          previousBalance: previousBalance,
          remainingBalance: remainingBalance,
          dueDateText: dueDateText,
          methodLabel: methodLabel,
          cashierName: cashierName,
          currency: currency,
        );
        await Printing.layoutPdf(
          onLayout: (_) => pdfBytes,
          name: 'credit_payment_$creditSaleNumber',
        );
      } else {
        if (!context.mounted) return false;
        final bytes = await _buildCreditPaymentEscPos(
          context,
          config.paperSize,
          hasKhmer: hasKhmer,
          labels: labels,
          creditSaleNumber: creditSaleNumber,
          customerName: customerName,
          amount: amount,
          previousBalance: previousBalance,
          remainingBalance: remainingBalance,
          dueDateText: dueDateText,
          methodLabel: methodLabel,
          cashierName: cashierName,
          currency: currency,
        );
        await _ref.read(thermalPrinterServiceProvider).printRaw(bytes, config);
      }
      return true;
    } catch (e) {
      debugPrint('Credit payment receipt print failed: $e');
      return false;
    }
  }

  Future<Uint8List> _buildCreditPaymentPdf(
    BuildContext context,
    PrinterPaperSize paperSize, {
    required bool hasKhmer,
    required _CreditPaymentLabels labels,
    required String creditSaleNumber,
    required String customerName,
    required double amount,
    required double previousBalance,
    required double remainingBalance,
    String? dueDateText,
    required String methodLabel,
    String? cashierName,
    required String currency,
  }) async {
    final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
    pw.Widget row(String label, String value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: bold ? _green : null)),
            ],
          ),
        );
    final content = hasKhmer && context.mounted
        ? await _khmerImageWidgetContent(
            context,
            CreditPaymentReceiptContent(
              title: labels.title,
              creditSaleLabel: labels.creditSale,
              creditSaleNumber: creditSaleNumber,
              customerLabel: labels.customer,
              customerName: customerName,
              cashierLabel: labels.cashier,
              cashierName: cashierName,
              previousBalanceLabel: labels.previousBalance,
              previousBalanceValue: formatAmount(previousBalance, currency),
              paymentLabel: labels.payment,
              paymentValue: formatAmount(amount, currency),
              remainingLabel: labels.remaining,
              remainingValue: formatAmount(remainingBalance, currency),
              dueDateLabel: labels.dueDate,
              dueDateValue: dueDateText,
              methodFieldLabel: labels.method,
              methodValue: methodLabel,
            ),
            paperSize,
          )
        : pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(labels.title,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: ReceiptSpacing.sectionGap),
              row(labels.creditSale, creditSaleNumber),
              row(labels.customer, customerName),
              if (cashierName != null && cashierName.isNotEmpty)
                row(labels.cashier, cashierName),
              pw.SizedBox(height: ReceiptSpacing.smallGap),
              pw.Divider(color: PdfColors.grey300, thickness: 0.75, height: 1),
              pw.SizedBox(height: ReceiptSpacing.smallGap),
              row(labels.previousBalance,
                  formatAmount(previousBalance, currency)),
              row(labels.payment, formatAmount(amount, currency), bold: true),
              row(labels.remaining, formatAmount(remainingBalance, currency),
                  bold: true),
              if (dueDateText != null) row(labels.dueDate, dueDateText),
              row(labels.method, methodLabel),
            ],
          );
    doc.addPage(
      pw.Page(pageFormat: paperSize.pdfPageFormat, build: (_) => content),
    );
    return doc.save();
  }

  Future<List<int>> _buildCreditPaymentEscPos(
    BuildContext context,
    PrinterPaperSize paperSize, {
    required bool hasKhmer,
    required _CreditPaymentLabels labels,
    required String creditSaleNumber,
    required String customerName,
    required double amount,
    required double previousBalance,
    required double remainingBalance,
    String? dueDateText,
    required String methodLabel,
    String? cashierName,
    required String currency,
  }) async {
    final previousBalanceText = formatAmount(previousBalance, currency);
    final amountText = formatAmount(amount, currency);
    final remainingText = formatAmount(remainingBalance, currency);

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize.escPosPaperSize, profile);
    var bytes = <int>[];
    bytes += generator.reset();

    if (hasKhmer) {
      final image = await bitmapRenderer.renderWidget(
        context,
        CreditPaymentReceiptContent(
          title: labels.title,
          creditSaleLabel: labels.creditSale,
          creditSaleNumber: creditSaleNumber,
          customerLabel: labels.customer,
          customerName: customerName,
          cashierLabel: labels.cashier,
          cashierName: cashierName,
          previousBalanceLabel: labels.previousBalance,
          previousBalanceValue: previousBalanceText,
          paymentLabel: labels.payment,
          paymentValue: amountText,
          remainingLabel: labels.remaining,
          remainingValue: remainingText,
          dueDateLabel: labels.dueDate,
          dueDateValue: dueDateText,
          methodFieldLabel: labels.method,
          methodValue: methodLabel,
        ),
        paperSize,
      );
      bytes += generator.imageRaster(image, align: PosAlign.left);
    } else {
      void line(String text,
          {PosAlign align = PosAlign.left, bool bold = false}) {
        bytes +=
            generator.text(text, styles: PosStyles(align: align, bold: bold));
      }

      void row(String left, String right, {bool bold = false}) {
        bytes += generator.row([
          PosColumn(
              text: left,
              width: 6,
              styles: PosStyles(bold: bold, align: PosAlign.left)),
          PosColumn(
              text: right,
              width: 6,
              styles: PosStyles(bold: bold, align: PosAlign.right)),
        ]);
      }

      line(labels.title, align: PosAlign.center, bold: true);
      bytes += generator.hr();
      row(labels.creditSale, creditSaleNumber);
      row(labels.customer, customerName);
      if (cashierName != null && cashierName.isNotEmpty) {
        row(labels.cashier, cashierName);
      }
      bytes += generator.hr(ch: '-');
      row(labels.previousBalance, previousBalanceText);
      row(labels.payment, amountText, bold: true);
      row(labels.remaining, remainingText, bold: true);
      if (dueDateText != null) row(labels.dueDate, dueDateText);
      row(labels.method, methodLabel);
    }

    bytes += generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  /// Generate a PDF receipt from an already-localized [ReceiptViewModel],
  /// sized and margined for [paperSize] (see `printing/printer_pdf_format.dart`)
  /// and typeset from `printing/receipt_layout_spec.dart` — the single
  /// production receipt PDF builder. Used for the immediate post-sale print
  /// (receipt_preview_screen.dart), reprints (receipts_screen.dart), and the
  /// developer print test screen, so there is exactly one PDF receipt design
  /// in the app, matching the on-screen preview section-for-section.
  ///
  /// [context], when given, is used only for a Khmer receipt: the page is
  /// rendered as a Flutter-shaped bitmap (see [ReceiptBitmapRenderer]) and
  /// embedded as an image, instead of `pw.Text` + a Khmer font fallback that
  /// package:pdf doesn't shape as reliably as Flutter's own text engine (see
  /// `printing/khmer_pdf_font.dart`'s doc comment). An English-only receipt
  /// always uses the fast native `pw.Text` path regardless of [context].
  /// Without a [context], a Khmer receipt still renders — via the older
  /// `pw.Text` path — rather than failing to produce a PDF at all.
  Future<Uint8List> buildReceiptPdf(
    ReceiptViewModel r,
    PrinterPaperSize paperSize, {
    BuildContext? context,
  }) async {
    final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());
    final content = await _pageContent(context, r, paperSize);

    doc.addPage(
      pw.Page(
        pageFormat: paperSize.pdfPageFormat,
        build: (_) => content,
      ),
    );

    return timePrintStage('receiptPdfDocSave', () => doc.save());
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
  ///
  /// [context] is threaded through to [buildReceiptPdf]'s Khmer bitmap path
  /// — see that method's doc comment. Receipts are rendered one at a time,
  /// in order (not `Future.wait`), the same sequential discipline
  /// [ThermalPrinterService.printReceipts] already uses for its batch, since
  /// concurrent off-screen widget mounts race against each other.
  Future<Uint8List> buildReceiptsPdf(
    List<ReceiptViewModel> receipts,
    PrinterPaperSize paperSize, {
    BuildContext? context,
  }) async {
    final doc = pw.Document(theme: await KhmerPdfFont.loadTheme());

    await timePrintStage('receiptsPdfContentTotal', () async {
      for (final r in receipts) {
        final content = await _pageContent(context, r, paperSize);
        doc.addPage(
          pw.Page(
            pageFormat: paperSize.pdfPageFormat,
            build: (_) => content,
          ),
        );
      }
    });

    return timePrintStage('receiptsPdfDocSave', () => doc.save());
  }

  /// [context] present and [r] Khmer → Flutter-rendered bitmap embedded as
  /// a `pw.Image`. Otherwise → the existing `pw.Text`-based layout.
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
  /// .dart`) and embeds it as a single full-page image, sized to exactly
  /// fill the receipt's printable content width
  /// (`paperSize.pdfPageFormat.availableWidth`) with height computed from
  /// the source image's own aspect ratio, so it's never stretched/distorted
  /// and never needs a second resize pass after rendering.
  ///
  /// Embeds the decoded `image` package raster directly via [pw.ImageImage]
  /// instead of going through [pw.MemoryImage] with a PNG-encoded byte
  /// array. `package:pdf`'s underlying `PdfImage` only ever wants raw RGBA
  /// pixels — [pw.MemoryImage] exists to accept an already-*encoded* file
  /// (e.g. a PNG downloaded from a server), and internally decodes it
  /// straight back to raw pixels before embedding (`PdfImage.file` →
  /// `image.decodeImage`). Round-tripping our own freshly-rendered pixels
  /// through a PNG encode only to have `doc.save()` immediately decode that
  /// same PNG again was profiled at ~2.3s encode plus a large share of a
  /// ~4.3s `doc.save()` for one receipt (see `[PrintPerf]` logs) — pure
  /// waste, since [pw.ImageImage] accepts [decoded] as-is and skips both
  /// the encode and the redundant decode.
  Future<pw.Widget> _khmerImagePageContent(
    BuildContext context,
    ReceiptViewModel r,
    PrinterPaperSize paperSize,
  ) async {
    final decoded = await timePrintStage('receiptPdfBitmapRender',
        () => bitmapRenderer.renderImage(context, r, paperSize));
    if (kDebugMode) {
      debugPrint('[PrintPerf] receiptPdfBitmapDimensions='
          '${decoded.width}x${decoded.height} '
          'rawBytes=${decoded.width * decoded.height * 4}');
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
  /// ticket and credit-payment receipt PDF builders, which have no
  /// [ReceiptViewModel] of their own but need the exact same "never send
  /// Khmer through pw.Text + font-fallback shaping" treatment (see this
  /// class's doc comment above [_khmerImagePageContent] for why that's
  /// unreliable for Khmer specifically).
  Future<pw.Widget> _khmerImageWidgetContent(
    BuildContext context,
    Widget child,
    PrinterPaperSize paperSize,
  ) async {
    final decoded = await timePrintStage('receiptPdfBitmapRender',
        () => bitmapRenderer.renderWidgetImage(context, child, paperSize));
    if (kDebugMode) {
      debugPrint('[PrintPerf] receiptPdfBitmapDimensions='
          '${decoded.width}x${decoded.height} '
          'rawBytes=${decoded.width * decoded.height * 4}');
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
      ReceiptViewModel r, PrinterPaperSize paperSize) {
    final t = paperSize.receiptTypography;
    final labels = r.labels;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Bill banner (pre-payment bill only) ──
        if (r.isBill) ...[
          _clipped(
            labels.billHeaderTitle,
            pw.TextStyle(
                fontSize: t.metadataValue + 1,
                fontWeight: pw.FontWeight.bold,
                color: _amber),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
        ],

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
          _clipped(labels.telFormat(r.phone!),
              pw.TextStyle(fontSize: t.businessInfo, color: _grey),
              textAlign: pw.TextAlign.center),
        pw.SizedBox(height: ReceiptSpacing.smallGap),
        _dashedDivider(),
        pw.SizedBox(height: ReceiptSpacing.sectionGap),

        // ── Table / order type (pre-payment bill only) ──
        if (r.isBill && r.tableNumber != null) ...[
          _billTableBanner(r, labels, t),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
        ],

        // ── Invoice metadata ──
        _metadataRow(r.isBill ? labels.ticket : labels.invoiceNumber,
            r.invoiceNumber, t),
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
                        color: _greyDark))),
            pw.SizedBox(
                width: 28,
                child: _clipped(
                    labels.qty,
                    pw.TextStyle(
                        fontSize: t.tableHeader,
                        fontWeight: pw.FontWeight.bold,
                        color: _greyDark),
                    textAlign: pw.TextAlign.right)),
            pw.SizedBox(
                width: 50,
                child: _clipped(
                    labels.total,
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

        // ── Payment (or UNPAID status, for a pre-payment bill) ──
        if (r.isBill) ...[
          _clipped(
              labels.paymentStatus,
              pw.TextStyle(
                  fontSize: t.summaryLabel,
                  fontWeight: pw.FontWeight.bold,
                  color: _greyDark),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
              labels.unpaid,
              pw.TextStyle(
                  fontSize: t.totalValue - 2,
                  fontWeight: pw.FontWeight.bold,
                  color: _amber),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.dividerGap),
          _clipped(labels.billDisclaimer,
              pw.TextStyle(fontSize: t.itemNote, color: _grey),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
              labels.billCashierNotice,
              pw.TextStyle(
                  fontSize: t.summaryLabel,
                  fontWeight: pw.FontWeight.bold,
                  color: _amber),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
          _dashedDivider(),
          pw.SizedBox(height: ReceiptSpacing.sectionGap),
        ] else ...[
          _summaryRow(labels.paid, r.fmt(r.paidAmount), t, bold: true),
          if (r.changeAmount > 0) ...[
            // Cash Received (= paidAmount + changeAmount, what the customer
            // actually handed over) makes Change legible — Paid alone is the
            // amount APPLIED to the sale (never more than the total), so
            // Change would otherwise look like it appeared from nowhere.
            pw.SizedBox(height: ReceiptSpacing.smallGap),
            _summaryRow(
                labels.cashReceived, r.fmt(r.paidAmount + r.changeAmount), t),
            pw.SizedBox(height: ReceiptSpacing.smallGap),
            _summaryRow(labels.change, r.fmt(r.changeAmount), t,
                color: _green),
            pw.SizedBox(height: ReceiptSpacing.sectionGap),
            _dashedDivider(),
            pw.SizedBox(height: ReceiptSpacing.sectionGap),
          ],
        ],

        // ── Credit ── (only for a sale that is/was a credit sale)
        if (r.creditStatus != null) ...[
          _summaryRow(
              labels.creditStatus, r.creditStatusDisplay ?? r.creditStatus!, t,
              bold: true),
          if (r.creditDueAt != null) ...[
            pw.SizedBox(height: ReceiptSpacing.smallGap),
            _summaryRow(labels.dueDate, r.creditDueAt!, t),
          ],
          if (r.remainingBalance != null && r.remainingBalance! > 0) ...[
            pw.SizedBox(height: ReceiptSpacing.smallGap),
            _summaryRow(labels.remaining, r.fmt(r.remainingBalance!), t,
                bold: true, color: _green),
          ],
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
                  color: _greyDark),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
              labels.exchangeRateValueFormat(
                  ReceiptViewModel.khrGroup(r.exchangeRateKhr!)),
              pw.TextStyle(
                  fontSize: t.summaryValue, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(
              '${labels.totalRiel}:  ${ReceiptViewModel.khrGroup(r.khrTotal)} ៛',
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
        // Settings → Company Profile's "Website" field — never a hardcoded
        // placeholder, and never rendered at all when unset.
        if (r.website != null && r.website!.isNotEmpty) ...[
          pw.SizedBox(height: ReceiptSpacing.smallGap),
          _clipped(r.website!,
              pw.TextStyle(fontSize: t.footerSmall, color: _grey),
              textAlign: pw.TextAlign.center),
        ],
        pw.SizedBox(height: 2),
        _clipped(labels.poweredBy,
            pw.TextStyle(fontSize: t.footerSmall, color: _grey),
            textAlign: pw.TextAlign.center),
      ],
    );
  }

  /// PDF counterpart of receipt_paper_view.dart's `_billTableBanner` —
  /// bordered "TABLE T05 / DINE IN" block for a pre-payment bill.
  pw.Widget _billTableBanner(
      ReceiptViewModel r, ReceiptLabels labels, ReceiptTypography t) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          _clipped(
              r.tableNumber!.toUpperCase(),
              pw.TextStyle(
                  fontSize: t.metadataValue + 3, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center),
          if (r.isDineIn) ...[
            pw.SizedBox(height: 2),
            _clipped(labels.dineIn.toUpperCase(),
                pw.TextStyle(fontSize: t.metadataLabel, color: _greyDark),
                textAlign: pw.TextAlign.center),
          ],
        ],
      ),
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

/// `YYYY-MM-DD`, used by the credit payment receipt's due-date row on both
/// the PDF and ESC-POS/bitmap paths — plain digits, so it never needs
/// localization or Khmer rendering of its own.
String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Labels for [PrintService.printCreditPaymentReceipt], resolved once via
/// [fromL10n] at the point a [BuildContext]/[AppLocalizations] is
/// available, then threaded as plain strings into the context-free PDF
/// builder and (for the fast native-text case) the ESC-POS builder — same
/// pattern `ReceiptLabels` already established for the main itemized
/// receipt, which had the identical "hardcoded English regardless of app
/// language" bug before that class existed.
class _CreditPaymentLabels {
  const _CreditPaymentLabels({
    required this.title,
    required this.creditSale,
    required this.customer,
    required this.cashier,
    required this.previousBalance,
    required this.payment,
    required this.remaining,
    required this.dueDate,
    required this.method,
  });

  factory _CreditPaymentLabels.fromL10n(AppLocalizations l10n) =>
      _CreditPaymentLabels(
        title: l10n.creditPaymentReceiptTitle,
        creditSale: l10n.creditPaymentReceiptCreditSaleLabel,
        customer: l10n.receiptCustomer,
        cashier: l10n.receiptCashier,
        previousBalance: l10n.creditPaymentReceiptPreviousBalanceLabel,
        payment: l10n.creditPaymentReceiptPaymentLabel,
        remaining: l10n.creditRepaymentRemainingLabel,
        dueDate: l10n.paymentScreenCreditDueLabel,
        method: l10n.receiptPaymentMethod,
      );

  final String title;
  final String creditSale;
  final String customer;
  final String cashier;
  final String previousBalance;
  final String payment;
  final String remaining;
  final String dueDate;
  final String method;
}

final printServiceProvider = Provider<PrintService>((ref) {
  return PrintService(ref.read(apiServiceProvider), ref);
});
