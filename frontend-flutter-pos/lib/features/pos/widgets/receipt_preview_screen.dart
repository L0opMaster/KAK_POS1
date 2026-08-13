import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/providers/language_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/cart_models.dart';
import '../services/print_service.dart';
import '../services/printing/printer_profile.dart';
import '../services/printing/receipt_bitmap_renderer.dart';
import '../services/printing/receipt_view_model.dart';
import '../services/printing/thermal_printer_service.dart';
import 'receipt_paper_view.dart';

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
  final String? website;
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
    this.website,
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
    final dispDate = saleDate ?? formatReceiptDate(now);
    final dispTime = saleTime ?? formatReceiptTime(now);

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
      website: website,
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
          child: ReceiptPaperView(receipt: receipt, width: 300),
        ),
      ),
    );
  }

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
    final labels = r.labels;
    final buf = StringBuffer()
      ..writeln()
      ..writeln('       ${r.businessName}')
      ..writeln();
    if (r.address != null) buf.writeln('  ${r.address}');
    if (r.phone != null) buf.writeln('  ${labels.telFormat(r.phone!)}');
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
    buf.writeln('  ${labels.subtotal}${r.fmt(r.subtotal).padLeft(24)}');
    for (final adj in r.adjustments) {
      final label = adj.type.labelFrom(labels);
      buf.writeln('  $label${r.fmtAdjustment(adj).padLeft(32 - label.length)}');
    }
    buf.writeln('  ${labels.total.toUpperCase()}${r.fmt(r.total).padLeft(28)}');
    buf.writeln();
    buf.writeln('  ${labels.paid}${r.fmt(r.paidAmount).padLeft(28)}');
    if (r.changeAmount > 0) {
      buf.writeln(
          '  ${labels.cashReceived}${r.fmt(r.paidAmount + r.changeAmount).padLeft(19)}');
      buf.writeln('  ${labels.change}${r.fmt(r.changeAmount).padLeft(26)}');
    }
    if (r.showExchangeRate) {
      buf.writeln();
      buf.writeln(
          '  ${labels.exchangeRate}   ${labels.exchangeRateValueFormat(ReceiptViewModel.khrGroup(r.exchangeRateKhr!))}');
      buf.writeln(
          '  ${labels.totalRiel}${ReceiptViewModel.khrGroup(r.khrTotal).padLeft(20)} ៛');
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
            .buildReceiptPdf(receipt, config.paperSize, context: context);
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
        final message = e is ReceiptRenderException
            ? e.message
            : context.l10n.printerPrintFailed;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }
}

class SplitRowReceipt {
  final String methodLabel;
  final double amount;
  SplitRowReceipt({required this.methodLabel, required this.amount});
}
