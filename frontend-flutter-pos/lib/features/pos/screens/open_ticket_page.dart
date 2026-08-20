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
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';
import '../services/printing/receipt_view_model.dart';
import '../widgets/bill_preview_screen.dart';

class OpenTicketPage extends ConsumerStatefulWidget {
  const OpenTicketPage({super.key});

  @override
  ConsumerState<OpenTicketPage> createState() => _OpenTicketPageState();
}

class _OpenTicketPageState extends ConsumerState<OpenTicketPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(heldTicketProvider.notifier).loadHeldTickets(),
    );
  }

  /// Builds this held ticket's pre-payment bill (`isBill: true`) so the
  /// customer can carry it to the cashier — no sale exists for a held
  /// ticket yet (see `held_ticket_provider.dart`'s `holdCurrentCart`), so
  /// this builds the receipt straight from the ticket's saved cart
  /// items/company profile instead of a backend `ReceiptResponse`.
  /// `paidAmount: 0` since nothing has been charged — [ReceiptViewModel
  /// .isBill] is what actually makes every renderer print "UNPAID" instead
  /// of "Paid: ៛0", not the zero amount itself. Mirrors
  /// `held_tickets_dialog.dart`'s `_buildBillReceipt` exactly, so the same
  /// ticket's bill looks identical whichever screen printed it from.
  Future<ReceiptViewModel?> _buildBillReceipt(HeldOrder ticket) async {
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

      if (!mounted) return null;
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
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.printerPrintFailed),
          backgroundColor: PosTheme.errorRed,
        ),
      );
      return null;
    }
  }

  /// "Print" action on a ticket card: builds the current-state bill and
  /// pushes [BillPreviewScreen] to preview/print it — same preview-before-
  /// print step `held_tickets_dialog.dart`'s "Print Bill" already uses.
  Future<void> _openBillPreview(HeldOrder ticket) async {
    final receipt = await _buildBillReceipt(ticket);
    if (receipt == null || !mounted) return;
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: PosTheme.primaryGreenLight,
                borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
              ),
              child: Icon(Icons.history,
                  color: PosTheme.primaryGreen, size: 18),
            ),
            const SizedBox(width: 12),
            Text(context.l10n.posOpenTickets),
            if (!state.loading && state.tickets.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PosTheme.primaryGreenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${state.tickets.length}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: PosTheme.primaryGreen),
                ),
              ),
            ],
          ],
        ),
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.tickets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_rounded,
                          size: 64, color: PosTheme.textHint),
                      const SizedBox(height: 16),
                      Text(context.l10n.openTicketPageEmptyTitle,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: PosTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.openTicketPageEmptySubtitle,
                        style: const TextStyle(
                            fontSize: 14, color: PosTheme.textHint),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: state.tickets.length,
                  itemBuilder: (context, index) {
                    final ticket = state.tickets[index];
                    return _TicketCard(
                      ticket: ticket,
                      onRestore: () async {
                        // Captured BEFORE the await, not checked via
                        // `context.mounted` after it: `context` here is
                        // this specific list item's BuildContext, and
                        // `restoreTicket` ends by calling
                        // `loadHeldTickets()`, which removes this now-
                        // in-progress ticket from the list and rebuilds
                        // it — disposing this exact item's context in the
                        // process. A `mounted` check after the await was
                        // therefore always false, so the pop below never
                        // ran (only the restore itself did). The
                        // NavigatorState captured here stays valid
                        // regardless, since it belongs to the ambient
                        // Navigator, not to this disposable list item.
                        final navigator = Navigator.of(context);
                        final notifier = ref.read(heldTicketProvider.notifier);
                        await notifier.restoreTicket(ticket);
                        // Pop back up to the register (PosScreen, the
                        // app's `home:` route — see main.dart) so the
                        // resumed cart is immediately visible, no matter
                        // how many screens deep the drawer was opened
                        // from. `popUntil(isFirst)` reveals the *existing*
                        // PosScreen instance already at the bottom of the
                        // stack instead of `pushAndRemoveUntil` tearing
                        // down the whole stack and building a brand new one.
                        navigator.popUntil((route) => route.isFirst);
                      },
                      onDelete: () => ref
                          .read(heldTicketProvider.notifier)
                          .deleteTicket(ticket),
                      onPrint: () => _openBillPreview(ticket),
                    );
                  },
                ),
    );
  }
}

/// Loyverse-style ticket card with rich info.
class _TicketCard extends ConsumerWidget {
  const _TicketCard({
    required this.ticket,
    required this.onRestore,
    required this.onDelete,
    required this.onPrint,
  });

  final HeldOrder ticket;
  final VoidCallback onRestore;
  final VoidCallback onDelete;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemCount = ticket.cartItems?.length ?? 0;
    final total = ticket.cartItems?.fold<double>(
          0,
          (sum, item) => sum + item.lineTotal,
        ) ??
        0;
    final timeAgo = _timeAgo(context, ticket.createdAt);
    final cur = watchCurrency(ref);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: const BorderSide(color: PosTheme.borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: PosTheme.primaryGreenLight,
            borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
          ),
          child: Icon(Icons.receipt_long,
              color: PosTheme.primaryGreen, size: 22),
        ),
        title: Row(
          children: [
            FutureBuilder<int?>(
              // Prefer the stable local waiting number bound to this ticket
              // (survives resume/re-hold) over the backend row id, which
              // changes every time a ticket is resumed and held again.
              future: ref
                  .read(waitingNumberServiceProvider)
                  .getNumberForOrder(ticket.id),
              builder: (context, snapshot) {
                final label = snapshot.data != null
                    ? context.l10n.openTicketPageTicketNumber(
                        snapshot.data.toString().padLeft(3, '0'))
                    : context.l10n
                        .openTicketPageTicketNumber(ticket.id.toString());
                return Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                );
              },
            ),
            if (ticket.table?.displayName != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: PosTheme.accentBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.table!.displayName!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: PosTheme.accentBlue),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              if (itemCount > 0) ...[
                Text(context.l10n.openTicketPageItemCount(itemCount),
                    style: const TextStyle(fontSize: 12)),
                Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: PosTheme.textHint)),
              ],
              Text(formatAmount(total, cur),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              if (timeAgo != null) ...[
                Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 3,
                    height: 3,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: PosTheme.textHint)),
                Text(timeAgo!,
                    style: TextStyle(fontSize: 12, color: PosTheme.textHint)),
              ],
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: PosTheme.primaryGreenLight,
                borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
              ),
              child: IconButton(
                onPressed: onRestore,
                icon: Icon(Icons.restore,
                    size: 20, color: PosTheme.primaryGreen),
                tooltip: context.l10n.openTicketPageRestore,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                color: PosTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
              ),
              child: IconButton(
                onPressed: onPrint,
                icon: Icon(Icons.print_outlined,
                    size: 20, color: PosTheme.accentBlue),
                tooltip: context.l10n.heldTicketsPrintBill,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              decoration: BoxDecoration(
                color: PosTheme.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
              ),
              child: IconButton(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline,
                    size: 20, color: PosTheme.errorRed),
                tooltip: context.l10n.commonDelete,
              ),
            ),
          ],
        ),
        onTap: onRestore,
      ),
    );
  }

  String? _timeAgo(BuildContext context, String? dateStr) {
    if (dateStr == null) return null;
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return context.l10n.openTicketPageJustNow;
      if (diff.inMinutes < 60) {
        return context.l10n.openTicketPageMinutesAgo(diff.inMinutes);
      }
      if (diff.inHours < 24) {
        return context.l10n.openTicketPageHoursAgo(diff.inHours);
      }
      return context.l10n.openTicketPageDaysAgo(diff.inDays);
    } catch (_) {
      return null;
    }
  }
}
