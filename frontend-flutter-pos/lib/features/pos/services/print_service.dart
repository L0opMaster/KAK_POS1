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
// `printing/receipt_view_model.dart`), so PDF and thermal output never
// drift out of sync with each other or with the on-screen preview.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/providers/language_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/receipt_models.dart';
import 'printing/printer_profile.dart';
import 'printing/receipt_view_model.dart';
import 'printing/thermal_printer_service.dart';

class PrintService {
  PrintService(this._api, this._ref);

  final ApiService _api;
  final Ref _ref;

  static pw.Font? _khmerRegular;
  static pw.Font? _khmerBold;

  static Future<void> _ensureKhmerFontLoaded() async {
    if (_khmerRegular != null) return;
    final regularData =
        await rootBundle.load('assets/fonts/NotoSansKhmer-Regular.ttf');
    final boldData =
        await rootBundle.load('assets/fonts/NotoSansKhmer-Bold.ttf');
    _khmerRegular = pw.Font.ttf(regularData);
    _khmerBold = pw.Font.ttf(boldData);
  }

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
        final pdfBytes = await _generateReceiptPdf(viewModel);
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

  /// Generate a PDF receipt from an already-localized [ReceiptViewModel].
  Future<Uint8List> _generateReceiptPdf(ReceiptViewModel r) async {
    await _ensureKhmerFontLoaded();
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _khmerRegular!, bold: _khmerBold!),
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Text(
                r.businessName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              if (r.address != null && r.address!.isNotEmpty)
                pw.Text(r.address!,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 12)),
              if (r.phone != null && r.phone!.isNotEmpty)
                pw.Text('Tel: ${r.phone}',
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(r.invoiceNumber, style: const pw.TextStyle(fontSize: 13)),
                  pw.Text(r.date, style: const pw.TextStyle(fontSize: 13)),
                ],
              ),
              pw.SizedBox(height: 4),
              if (r.cashierName != null)
                pw.Text(r.cashierName!, style: const pw.TextStyle(fontSize: 13)),
              if (r.customerName != null)
                pw.Text(r.customerName!, style: const pw.TextStyle(fontSize: 13)),
              if (r.tableNumber != null)
                pw.Text(r.tableNumber!, style: const pw.TextStyle(fontSize: 13)),
              pw.Divider(),
              // ── Line items ──
              ...r.lines.map<pw.Widget>((line) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(line.name, style: const pw.TextStyle(fontSize: 13)),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                            '  ${line.qty.toStringAsFixed(0)} × ${r.fmt(line.unitPrice)}',
                            style: const pw.TextStyle(fontSize: 12)),
                        pw.Text(r.fmt(line.lineTotal),
                            style: const pw.TextStyle(fontSize: 13)),
                      ],
                    ),
                    if (line.modifierAmount != 0)
                      pw.Text(
                        '  Base: ${r.fmt(line.basePrice)} + Modifier: ${r.fmt(line.modifierAmount)}',
                        style: pw.TextStyle(
                            fontSize: 10, fontStyle: pw.FontStyle.italic),
                      ),
                    if (line.modifierSummary != null &&
                        line.modifierSummary!.isNotEmpty)
                      pw.Text(
                        '  ${line.modifierSummary}',
                        style: pw.TextStyle(
                            fontSize: 10, fontStyle: pw.FontStyle.italic),
                      ),
                  ],
                );
              }),
              pw.Divider(),
              // ── Totals ──
              _totalsRow('Subtotal', r.subtotal, r),
              if (r.deliveryCharge > 0)
                _totalsRow('Delivery', r.deliveryCharge, r),
              if (r.otherCharge > 0) _totalsRow('Other Charge', r.otherCharge, r),
              if (r.discountAmount > 0)
                _totalsRow('Discount', -r.discountAmount, r),
              _totalsRow('Tax', r.taxAmount, r),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.Text(
                    r.fmt(r.total),
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (r.showExchangeRate) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Exchange Rate', style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                        '1 USD = ${ReceiptViewModel.khrGroup(r.exchangeRateKhr!)} KHR',
                        style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total (Riel)',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${ReceiptViewModel.khrGroup(r.khrTotal)} ៛',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
              if (r.paidAmount > 0) _totalsRow('Paid', r.paidAmount, r),
              if (r.changeAmount > 0) _totalsRow('Change', r.changeAmount, r),
              pw.Divider(),
              pw.Text(
                r.footer,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 13, fontStyle: pw.FontStyle.italic),
              ),
              if (r.qrImageData != null && r.qrImageData!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Image(
                    pw.MemoryImage(
                        Uint8List.fromList(r.qrImageData!.codeUnits)),
                    height: 62,
                    alignment: pw.Alignment.center,
                  ),
                ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _totalsRow(String label, num amount, ReceiptViewModel r) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 13)),
          pw.Text(r.fmt(amount.toDouble()), style: const pw.TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

final printServiceProvider = Provider<PrintService>((ref) {
  return PrintService(ref.read(apiServiceProvider), ref);
});
