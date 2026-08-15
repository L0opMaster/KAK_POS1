import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../services/print_service.dart';
import '../services/printing/thermal_printer_service.dart';
import '../services/printing/printer_profile.dart';
import '../services/printing/receipt_view_model.dart';
import '../widgets/receipt_paper_view.dart';

/// One authorized payment split, for the receipt's payment breakdown —
/// ported from source's `SplitRowReceipt`.
class SplitRowReceipt {
  const SplitRowReceipt({required this.methodLabel, required this.amount});
  final String methodLabel;
  final double amount;
}

/// MOBILE UI REIMPLEMENT of `frontend-flutter-pos/lib/features/pos/widgets/
/// receipt_preview_screen.dart` — the immediate post-sale preview, built
/// straight from the just-completed cart/payment data via
/// `ReceiptViewModel.fromCart` (no backend round-trip needed to show it).
/// The business logic (`_buildViewModel`'s paid/change computation) is
/// COPY/ADAPT NEARLY EXACTLY; source's 3-icon AppBar (content-copy + print,
/// both wired to the same handler — a pre-existing bug in source, not
/// reproduced here — and close) is reimplemented as a single Print action
/// (added Day 13, once `print_service.dart` existed) plus a Close action.
/// `_printReceipt` mirrors source's `_printPdfOrThermal`'s `pdfDriver`
/// branch (build via `PrintService.buildReceiptPdf`, hand to the OS print
/// dialog via `Printing.layoutPdf`) — the clipboard plain-text fallback and
/// the non-PDF transport branch are dropped, same reasoning as
/// `print_service.dart`'s own header comment.
class ReceiptPreviewScreen extends ConsumerStatefulWidget {
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
  final double? paidAmountOverride;
  final double? changeAmountOverride;
  final double? exchangeRateKhr;

  @override
  ConsumerState<ReceiptPreviewScreen> createState() =>
      _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends ConsumerState<ReceiptPreviewScreen> {
  bool _printing = false;

  ReceiptViewModel _buildViewModel(BuildContext context, WidgetRef ref) {
    final splits = widget.splits;
    final total = widget.total;
    final splitsPaid = splits.fold<double>(0, (s, sp) => s + sp.amount);
    final totalPaid = widget.paidAmountOverride ?? splitsPaid;
    final change =
        widget.changeAmountOverride ??
        (splitsPaid > total ? splitsPaid - total : 0.0);
    final now = DateTime.now();
    return ReceiptViewModel.fromCart(
      language: ref.read(appLanguageProvider),
      l10n: context.l10n,
      total: total,
      subtotal: widget.subtotal,
      discountAmount: widget.discountAmount,
      taxAmount: widget.taxAmount,
      deliveryCharge: widget.deliveryCharge,
      otherCharge: widget.otherCharge,
      items: widget.saleItems ?? const [],
      paidAmount: totalPaid,
      changeAmount: change,
      invoiceNumber: widget.invoiceNumber,
      cashierName: widget.cashierName,
      businessName: widget.businessName,
      businessAddress: widget.businessAddress,
      businessPhone: widget.businessPhone,
      website: widget.website,
      currency: widget.currency,
      footer: widget.footer,
      saleDate: widget.saleDate ?? '${now.day}/${now.month}/${now.year}',
      saleTime: widget.saleTime ?? '${now.hour}:${now.minute}',
      tableNumber: widget.tableNumber,
      exchangeRateKhr: widget.exchangeRateKhr,
      paymentMethodLabel: splits.isNotEmpty ? splits.first.methodLabel : null,
    );
  }

  /// Mirrors source's `_printPdfOrThermal`'s `pdfDriver` branch — see this
  /// class's doc comment for what's dropped.
  Future<void> _printReceipt(ReceiptViewModel receipt) async {
    setState(() => _printing = true);
    try {
      final config = await ref.read(thermalPrinterServiceProvider).loadConfig();
      if (!mounted) return;
      if (config.transportType != PrinterTransportType.pdfDriver) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This printer type needs a later update.'),
          ),
        );
        return;
      }
      final pdfBytes = await ref
          .read(printServiceProvider)
          .buildReceiptPdf(receipt, config.paperSize, context: context);
      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'receipt_${receipt.invoiceNumber}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.printerPrintFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _buildViewModel(context, ref);
    return Scaffold(
      backgroundColor: PosTheme.backgroundPageOf(context),
      appBar: AppBar(
        title: Text(context.l10n.receiptsScreenPrintReceipt),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: _printing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            tooltip: context.l10n.receiptPrint,
            onPressed: _printing ? null : () => _printReceipt(receipt),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: PosTheme.spacingLg),
        child: Center(child: ReceiptPaperView(receipt: receipt)),
      ),
    );
  }
}
