import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/bill_print_status_provider.dart';
import '../services/print_service.dart';
import '../services/printing/receipt_view_model.dart';
import '../widgets/receipt_paper_view.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/widgets/
/// bill_preview_screen.dart` — COPY/ADAPT NEARLY EXACTLY. Preview for a
/// held ticket's pre-payment bill, pushed from `held_tickets_screen.dart`'s
/// "Print Bill" action — the same preview-before-print step
/// [ReceiptPreviewScreen] already gives the final paid receipt, kept as a
/// separate (simpler) screen since a bill has no splits/payment-method
/// inputs to carry.
///
/// [receipt] must already have `isBill: true` (see
/// `ReceiptViewModel.isBill`'s doc comment) — this screen only previews and
/// prints it, it doesn't decide what kind of document it is.
class BillPreviewScreen extends ConsumerWidget {
  const BillPreviewScreen({
    super.key,
    required this.receipt,
    required this.ticketId,
  });

  final ReceiptViewModel receipt;

  /// Held ticket id, used only to mark [billPrintStatusProvider] once a
  /// print succeeds — never sent to the print pipeline itself.
  final int ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F6),
      appBar: AppBar(
        title: Text(l10n.heldTicketsBillPreviewTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, size: 22),
            tooltip: l10n.receiptPrint,
            onPressed: () => _print(context, ref),
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

  Future<void> _print(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(printServiceProvider)
        .printReceiptViewModel(context, receipt, jobName: 'bill_$ticketId');
    if (!context.mounted) return;
    if (ok) {
      await ref.read(billPrintStatusProvider.notifier).markPrinted(ticketId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.heldTicketsPrintBill)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.printerPrintFailed),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  }
}
