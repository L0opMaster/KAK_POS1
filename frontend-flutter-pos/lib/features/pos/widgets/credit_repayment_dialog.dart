import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../screens/payment_screen.dart' show PaymentMethodX;
import '../services/print_service.dart';
import '../services/sale_service.dart';

/// Payment methods the backend's `SaleService.normalizePaymentMethod`
/// actually accepts today. Deliberately not `payment_screen.dart`'s full
/// `PaymentMethod` enum, which also offers ACLEDA/CHECK/OTHER — those are
/// already rejected server-side for a normal sale too (a pre-existing,
/// unrelated bug); this dialog just avoids adding a second instance of it.
const _kSupportedRepaymentMethods = <String>[
  'CASH',
  'KHQR',
  'ABA',
  'WING',
  'CARD',
  'BANK_TRANSFER',
];

/// Records a payment against an open credit [sale] — the amount, up to and
/// including "pay full balance", a payment method, and an optional note.
/// Shared by the Customer Credit Detail screen and the Receipts screen so
/// "record a payment" has exactly one implementation. On success, prints a
/// Credit Payment Receipt (best-effort — a printer failure doesn't undo the
/// already-recorded payment) and returns the updated [SaleResponse]; returns
/// null if the cashier cancels.
Future<SaleResponse?> showCreditRepaymentDialog(
  BuildContext context,
  WidgetRef ref, {
  required SaleResponse sale,
}) {
  return showDialog<SaleResponse>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) => _CreditRepaymentDialog(sale: sale),
  );
}

class _CreditRepaymentDialog extends ConsumerStatefulWidget {
  final SaleResponse sale;
  const _CreditRepaymentDialog({required this.sale});

  @override
  ConsumerState<_CreditRepaymentDialog> createState() =>
      _CreditRepaymentDialogState();
}

class _CreditRepaymentDialogState
    extends ConsumerState<_CreditRepaymentDialog> {
  // Owned by this State (not the closure that opened the dialog) so Flutter
  // disposes them at the normal widget-lifecycle point — after this widget
  // is actually unmounted, not the instant `Navigator.pop()` is called. A
  // manual `showDialog(...).whenComplete(controller.dispose)` disposes while
  // the dialog's exit transition is still animating/rebuilding the same
  // TextField, which throws "used after being disposed".
  final _amountCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  String _method = 'CASH';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final sale = widget.sale;
    final amount = double.tryParse(_amountCtl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = context.l10n.creditRepaymentAmountInvalid);
      return;
    }
    if (amount > sale.remainingBalance) {
      setState(() => _error = context.l10n.creditRepaymentExceedsBalance);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      // The sale's own currency (it's what its amounts were actually
      // recorded in) — not the live app-wide setting, which can differ (or
      // still be mid-load and defaulting to KHR) and previously caused
      // amounts to render zero-decimal-rounded (e.g. "$2.70" shown as "3").
      final cur = sale.currency ?? readCurrency(ref);
      final previousBalance = sale.remainingBalance;
      final updated = await ref.read(saleServiceProvider).repayCreditSale(
            sale.id,
            amount: amount,
            method: _method,
            notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
          );

      // Best-effort — a printer being offline must not undo the repayment
      // that already succeeded server-side.
      if (mounted) {
        unawaited(
          ref.read(printServiceProvider).printCreditPaymentReceipt(
                context,
                creditSaleNumber: sale.invoiceNumber ?? '#${sale.id}',
                customerName: sale.customerName ?? '',
                amount: amount,
                previousBalance: previousBalance,
                remainingBalance: updated.remainingBalance,
                dueDate: parseBackendTimestamp(updated.creditDueAt),
                method: _method,
                currency: cur,
              ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.creditRepaymentSuccess)),
      );
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = context.l10n.creditRepaymentFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = widget.sale;
    final cur = sale.currency ?? readCurrency(ref);
    return AlertDialog(
      title: Text(context.l10n.creditRepaymentDialogTitle),
      content: SizedBox(
        width: 360,
        // Scrollable so the dialog never overflows once the on-screen
        // keyboard opens (or on a short window) instead of clipping content
        // under a "BOTTOM OVERFLOWED" banner.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l10n.creditRepaymentRemainingLabel,
                      style: TextStyle(
                          fontSize: 13,
                          color: PosTheme.textSecondaryOf(context))),
                  Text(formatAmount(sale.remainingBalance, cur),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountCtl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: context.l10n.creditRepaymentAmountLabel,
                  prefixText: '${currencySymbol(cur)} ',
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    _amountCtl.text = sale.remainingBalance.toStringAsFixed(2);
                  }),
                  child: Text(context.l10n.creditRepaymentPayFullButton),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _method,
                items: _kSupportedRepaymentMethods
                    .map((m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                            PaymentMethodX.fromCode(m).label(context.l10n))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _method = v);
                },
                decoration: InputDecoration(
                  labelText: context.l10n.creditRepaymentMethodLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.creditRepaymentNotesLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!,
                    style: const TextStyle(
                        color: PosTheme.errorRed, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _confirm,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(context.l10n.creditRepaymentConfirmButton(
                  formatAmount(double.tryParse(_amountCtl.text) ?? 0, cur))),
        ),
      ],
    );
  }
}
