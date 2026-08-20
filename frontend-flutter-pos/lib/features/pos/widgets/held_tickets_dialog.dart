import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/cart_models.dart';
import '../providers/bill_print_status_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';
import '../services/printing/receipt_view_model.dart';
import '../utils/held_order_totals.dart';
import 'bill_preview_screen.dart';

/// Loyverse-inspired dialog for viewing and restoring held/saved tickets.
class HeldTicketsDialog extends ConsumerStatefulWidget {
  const HeldTicketsDialog({super.key});

  @override
  ConsumerState<HeldTicketsDialog> createState() => _HeldTicketsDialogState();
}

class _HeldTicketsDialogState extends ConsumerState<HeldTicketsDialog> {
  String _search = '';
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(heldTicketProvider.notifier).loadHeldTickets());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// Cancels (voids) a held ticket before it's ever paid — frees its table
  /// (see HeldTicketService.softDelete on the backend) and removes it from
  /// the list. This does not touch payment/sales records since the ticket
  /// was never converted into a completed sale.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HeldOrder ticket,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.heldTicketsCancelTitle),
        content: Text(
          dialogContext.l10n.heldTicketsCancelConfirm(ticket.id.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.heldTicketsKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.heldTicketsCancelTicketButton,
                style: const TextStyle(color: PosTheme.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(heldTicketProvider.notifier).deleteTicket(ticket);

    if (!context.mounted) return;

    final error = ref.read(heldTicketProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error != null
            ? context.l10n.heldTicketsCancelFailed(error)
            : context.l10n.heldTicketsCancelled(ticket.id.toString())),
        backgroundColor: error != null ? PosTheme.errorRed : null,
      ),
    );
  }

  /// Builds this held ticket's pre-payment bill (`isBill: true`) so the
  /// customer can carry it to the cashier — no sale exists for a held
  /// ticket yet (see `held_ticket_provider.dart`'s `holdCurrentCart`), so
  /// this builds the receipt straight from the ticket's saved cart
  /// items/company profile instead of a backend `ReceiptResponse`.
  /// `paidAmount: 0` since nothing has been charged — [ReceiptViewModel
  /// .isBill] is what actually makes every renderer print "UNPAID" instead
  /// of "Paid: ₀", not the zero amount itself. Returns null (after
  /// showing an error snackbar) if the company profile / waiting-number
  /// lookups fail unexpectedly.
  Future<ReceiptViewModel?> _buildBillReceipt(
    BuildContext context,
    WidgetRef ref,
    HeldOrder ticket,
  ) async {
    final items = ticket.cartItems ?? const <CartItem>[];
    try {
      final subtotal = items.fold(0.0, (sum, i) => sum + i.lineTotal);
      final taxAmount = items.fold(
          0.0,
          (sum, i) =>
              sum +
              (i.lineTotal - (i.discountAmount ?? 0) * i.qty) *
                  i.product.taxRate);

      Map<String, dynamic>? company;
      try {
        company = await ref.read(companyProfileProvider.future);
      } catch (_) {
        // No company profile yet — fromCart falls back to the app name and
        // omits address/phone/website.
      }

      final waitingNumber = await ref
          .read(waitingNumberServiceProvider)
          .getNumberForOrder(ticket.id);

      if (!context.mounted) return null;
      final language = ref.read(appLanguageProvider);
      final l10n = AppLocalizations.of(context);
      final cashierName = ref.read(currentUserProvider)?.fullName ?? '';
      final now = DateTime.now();

      return ReceiptViewModel.fromCart(
        language: language,
        l10n: l10n,
        total: subtotal + taxAmount,
        subtotal: subtotal,
        taxAmount: taxAmount,
        items: items,
        paidAmount: 0,
        invoiceNumber:
            '#${(waitingNumber ?? ticket.id).toString().padLeft(3, '0')}',
        cashierName: cashierName,
        businessName: company?['businessName'] as String?,
        businessAddress: company?['address'] as String?,
        businessPhone: company?['phone'] as String?,
        website: company?['website'] as String?,
        currency: readCurrency(ref),
        saleDate: formatReceiptDate(now),
        saleTime: formatReceiptTime(now),
        tableNumber: ticket.table?.displayText,
        isBill: true,
        isDineIn: ticket.table != null,
      );
    } catch (e) {
      debugPrint('Held ticket bill build failed: $e');
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.printerPrintFailed),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return null;
    }
  }

  /// "Print Bill" action: builds the current-state bill (always recomputed
  /// from `ticket.cartItems`/`.table`, never a stale cached total — see
  /// req. "order changed after bill printed") and pushes [BillPreviewScreen]
  /// to preview/print it, mirroring the paid-receipt flow's existing
  /// preview-before-print step ([ReceiptPreviewScreen]).
  Future<void> _openBillPreview(
    BuildContext context,
    WidgetRef ref,
    HeldOrder ticket,
  ) async {
    final receipt = await _buildBillReceipt(context, ref, ticket);
    if (receipt == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            BillPreviewScreen(receipt: receipt, ticketId: ticket.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(heldTicketProvider);
    final printedIds = ref.watch(billPrintStatusProvider);
    final currency = readCurrency(ref);
    final tickets = state.tickets.where((t) {
      if (_search.isEmpty) return true;
      final lower = _search.toLowerCase();
      if (t.id.toString().contains(_search)) return true;
      if (t.status.toLowerCase().contains(lower)) return true;
      return false;
    }).toList();

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PosTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            ),
            child: Icon(Icons.history,
                color: PosTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.heldTicketsTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: PosTheme.textPrimaryOf(context),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: context.l10n.heldTicketsSearchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: PosTheme.backgroundPageOf(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            if (state.loading)
              const Center(child: CircularProgressIndicator())
            else if (tickets.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: PosTheme.backgroundPageOf(context),
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded,
                        size: 48, color: PosTheme.textHintOf(context)),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.heldTicketsEmpty,
                      style: TextStyle(
                        color: PosTheme.textSecondaryOf(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.heldTicketsEmptyHint,
                      style: TextStyle(
                        color: PosTheme.textHintOf(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.maxFinite,
                height: 380,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tickets.length,
                  itemBuilder: (ctx, i) {
                    final ticket = tickets[i];
                    final billPrinted = printedIds.contains(ticket.id);
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium),
                        side: BorderSide(color: PosTheme.borderColorOf(ctx)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Ticket # / table / item count ──
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: PosTheme.backgroundPageOf(ctx),
                                    borderRadius: BorderRadius.circular(
                                        PosTheme.radiusSmall),
                                  ),
                                  child: Icon(Icons.receipt_long,
                                      color: PosTheme.primaryGreen, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      FutureBuilder<int?>(
                                        // Prefer the stable local waiting
                                        // number bound to this ticket
                                        // (survives resume/re-hold) over the
                                        // backend row id, which changes
                                        // every time a ticket is resumed and
                                        // held again.
                                        future: ref
                                            .read(waitingNumberServiceProvider)
                                            .getNumberForOrder(ticket.id),
                                        builder: (context, snapshot) {
                                          final label = snapshot.data != null
                                              ? context.l10n
                                                  .heldTicketsTicketLabel(
                                                      snapshot.data
                                                          .toString()
                                                          .padLeft(3, '0'))
                                              : context.l10n
                                                  .heldTicketsTicketLabel(
                                                      ticket.id.toString());
                                          return Text(label,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15));
                                        },
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          if (ticket.table != null)
                                            ticket.table!.displayText,
                                          context.l10n.heldTicketsItemsCount(
                                              heldOrderItemCount(ticket)
                                                  .toString()),
                                        ].join(' • '),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                PosTheme.textSecondaryOf(ctx)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: ctx.l10n.heldTicketsCancelTitle,
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: PosTheme.errorRed),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, ticket),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // ── Total ──
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(context.l10n.receiptTotal,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: PosTheme.textSecondaryOf(ctx))),
                                Text(
                                  formatAmount(heldOrderTotal(ticket), currency),
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // ── Status badges — a bill printed once is
                            // still fully unpaid; never imply otherwise. ──
                            Row(
                              children: [
                                _StatusChip(
                                  label: context.l10n.heldTicketsUnpaidBadge,
                                  color: PosTheme.warningAmber,
                                ),
                                if (billPrinted) ...[
                                  const SizedBox(width: 6),
                                  _StatusChip(
                                    label: context
                                        .l10n.heldTicketsBillPrintedBadge,
                                    color: Colors.amber.shade700,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── Actions ──
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      ref
                                          .read(heldTicketProvider.notifier)
                                          .restoreTicket(ticket);
                                      Navigator.of(context).pop();
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: PosTheme.primaryGreen,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    icon: const Icon(Icons.restore, size: 18),
                                    label: Text(
                                        context.l10n.heldTicketsResumeOrder,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openBillPreview(
                                        context, ref, ticket),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: PosTheme.accentBlue,
                                      side: const BorderSide(
                                          color: PosTheme.accentBlue),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                    ),
                                    icon: const Icon(Icons.print_outlined,
                                        size: 18),
                                    label: Text(
                                        billPrinted
                                            ? context.l10n
                                                .heldTicketsPrintBillAgain
                                            : context
                                                .l10n.heldTicketsPrintBill,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: PosTheme.textSecondaryOf(context),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            ),
          ),
          child: Text(context.l10n.commonClose),
        ),
      ],
    );
  }
}

/// Small pill used for a ticket card's status row — e.g. "UNPAID" or "BILL
/// PRINTED" (see [_HeldTicketsDialogState.build]). Deliberately never
/// implies payment: printing a bill only ever adds a second chip alongside
/// UNPAID, it never replaces it.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
