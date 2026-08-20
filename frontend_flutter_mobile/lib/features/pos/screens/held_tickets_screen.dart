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
import '../../shell/mobile_shell_screen.dart';
import '../models/cart_models.dart';
import '../providers/bill_print_status_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';
import '../services/print_service.dart';
import '../services/printing/receipt_view_model.dart';
import '../services/settings_service.dart';
import 'bill_preview_screen.dart';

/// ADAPTED from `frontend-flutter-pos/lib/features/pos/widgets/
/// held_tickets_dialog.dart`'s `HeldTicketsDialog` — same waiting-number-
/// first identity (falling back to the raw ticket id), same table +
/// tap-to-restore behavior, same tap-to-restore / delete-with-
/// confirmation actions. Presented as the Day 5 "Held / Open Tickets"
/// bottom-nav tab's real content (a full screen) instead of a dialog
/// popped from within `PosRegisterScreen`.
///
/// REDESIGNED (this session): the original mobile port was a plain
/// `ListTile` list, all fields the same visual weight — a cashier
/// scanning for "ticket #007" had to read past an identically-styled
/// icon/table-name/timestamp on every row. This is a deliberate visual
/// upgrade (ticket-stub card: waiting number as a large badge on the
/// left, since that's the one field a cashier actually searches for),
/// not a source port — `[OLD/SOURCE]`'s own dialog is the same plain
/// list. Item count (`HeldOrder.cartItems.length`,
/// `l10n.waitingTicketsItemsCount` — an existing key from the
/// queue-board feature this port didn't build, reused here since the
/// wording already fits) and held-since time
/// (`HeldOrder.createdAt`/`parseBackendTimestamp`) are new — both fields
/// already existed on the model, just never shown.
///
/// CORRECTED Day 9: restoring a ticket used to call
/// `Navigator.of(context).pop()` — copied from source's dialog-dismiss
/// pattern (`HeldTicketsDialog` really is a dialog, so `pop()` is correct
/// there) without accounting for this screen being a permanent bottom-nav
/// tab body instead, never pushed via `Navigator`. See
/// `table_picker_screen.dart`'s matching fix / [shellTabIndexProvider] for
/// the full explanation — same bug, same fix, applied here too.
class HeldTicketsScreen extends ConsumerStatefulWidget {
  const HeldTicketsScreen({super.key});

  @override
  ConsumerState<HeldTicketsScreen> createState() => _HeldTicketsScreenState();
}

class _HeldTicketsScreenState extends ConsumerState<HeldTicketsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(heldTicketProvider.notifier).loadHeldTickets(),
    );
  }

  Future<void> _confirmDelete(HeldOrder ticket) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.heldTicketsCancelTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(heldTicketProvider.notifier).deleteTicket(ticket);
    }
  }

  /// Builds this held ticket's pre-payment bill (`isBill: true`) so the
  /// customer can carry it to the cashier — no sale exists for a held
  /// ticket yet (see `held_ticket_provider.dart`'s `holdCurrentCart`), so
  /// this builds the receipt straight from the ticket's saved cart
  /// items/company profile instead of a backend `ReceiptResponse`.
  /// `paidAmount: 0` since nothing has been charged —
  /// [ReceiptViewModel.isBill] is what actually makes every renderer print
  /// "UNPAID" instead of "Paid: $0", not the zero amount itself. Tax is
  /// recomputed from the store's *current* tax rate — a held ticket only
  /// stores its cart items (see [HeldOrder]), not the tax rate active when
  /// it was held. Returns null (after showing an error snackbar) if the
  /// build fails unexpectedly.
  Future<ReceiptViewModel?> _buildBillReceipt(HeldOrder ticket) async {
    final items = ticket.cartItems ?? const <CartItem>[];
    try {
      final subtotal = items.fold(0.0, (sum, i) => sum + i.lineTotal);

      double taxRate = 0.08;
      try {
        final tax = await ref.read(settingsServiceProvider).getTax();
        taxRate = (tax['taxRate'] as num?)?.toDouble() ?? taxRate;
      } catch (_) {
        // Offline/unset — fall back to the same 0.08 default cart_provider
        // uses when its own tax settings fetch fails.
      }
      final taxAmount = subtotal * taxRate;

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
      _showPrintFailed();
      return null;
    }
  }

  /// "Print Bill" action: builds the current-state bill (always recomputed
  /// from `ticket.cartItems`/`.table`, never a stale cached total) and
  /// pushes [BillPreviewScreen] to preview/print it, mirroring the
  /// paid-receipt flow's existing preview-before-print step
  /// ([ReceiptPreviewScreen]).
  Future<void> _openBillPreview(HeldOrder ticket) async {
    final receipt = await _buildBillReceipt(ticket);
    if (receipt == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BillPreviewScreen(receipt: receipt, ticketId: ticket.id),
      ),
    );
  }

  /// Prints just this ticket's queue number (see `waiting_number_service
  /// .dart`) — the ticket stub a customer carries and hears called, distinct
  /// from [_printBill]'s itemized receipt.
  Future<void> _printWaitingNumber(HeldOrder ticket) async {
    try {
      final number = await ref
          .read(waitingNumberServiceProvider)
          .getNumberForOrder(ticket.id);
      if (number == null) {
        if (!mounted) return;
        _showPrintFailed();
        return;
      }
      Map<String, dynamic>? company;
      try {
        company = await ref.read(companyProfileProvider.future);
      } catch (_) {
        // No company profile yet — printed ticket just omits the heading.
      }
      if (!mounted) return;
      final ok = await ref.read(printServiceProvider).printWaitingNumberTicket(
            context,
            waitingNumber: number,
            businessName: company?['businessName'] as String?,
          );
      if (!mounted) return;
      if (!ok) _showPrintFailed();
    } catch (e) {
      debugPrint('Waiting number ticket print failed: $e');
      if (!mounted) return;
      _showPrintFailed();
    }
  }

  void _showPrintFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.printerPrintFailed),
        backgroundColor: PosTheme.errorRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(heldTicketProvider);
    final tickets = state.tickets;

    return Scaffold(
      // appBar: AppBar(title: Text(l10n.heldTicketsTitle)),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(heldTicketProvider.notifier).loadHeldTickets(),
        child: state.loading && tickets.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : tickets.isEmpty
            ? ListView(
                // ListView (not Column) so pull-to-refresh still works
                // on an empty list.
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 18,
                            color: PosTheme.textHintOf(context),
                          ),
                          const SizedBox(height: PosTheme.spacingMd),
                          Text(
                            l10n.heldTicketsEmpty,
                            style: TextStyle(
                              color: PosTheme.textSecondaryOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: PosTheme.spacingXs),
                          Text(
                            l10n.heldTicketsEmptyHint,
                            style: TextStyle(
                              fontSize: 13,
                              color: PosTheme.textHintOf(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(PosTheme.spacingMd),
                itemCount: tickets.length,
                itemBuilder: (context, i) {
                  final ticket = tickets[i];
                  return _HeldTicketCard(
                    ticket: ticket,
                    onDelete: () => _confirmDelete(ticket),
                    onPrintBill: () => _openBillPreview(ticket),
                    onPrintNumber: () => _printWaitingNumber(ticket),
                    onRestore: () {
                      ref
                          .read(heldTicketProvider.notifier)
                          .restoreTicket(ticket);
                      ref.read(shellTabIndexProvider.notifier).state = 0;
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _HeldTicketCard extends ConsumerWidget {
  const _HeldTicketCard({
    required this.ticket,
    required this.onDelete,
    required this.onPrintBill,
    required this.onPrintNumber,
    required this.onRestore,
  });

  final HeldOrder ticket;
  final VoidCallback onDelete;
  final VoidCallback onPrintBill;
  final VoidCallback onPrintNumber;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final itemCount = ticket.cartItems?.length ?? 0;
    final heldAt = parseBackendTimestamp(ticket.createdAt);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: InkWell(
        onTap: onRestore,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Waiting-number stub — the one field a cashier actually
              // scans this list for, so it gets its own high-contrast
              // panel instead of sharing a ListTile row with everything
              // else.
              FutureBuilder<int?>(
                future: ref
                    .read(waitingNumberServiceProvider)
                    .getNumberForOrder(ticket.id),
                builder: (context, snapshot) {
                  final number = snapshot.data;
                  final label = number != null
                      ? number.toString().padLeft(3, '0')
                      : '#${ticket.id}';
                  return Container(
                    width: 76,
                    padding: const EdgeInsets.symmetric(
                      vertical: PosTheme.spacingMd,
                    ),
                    color: PosTheme.primaryGreen,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(PosTheme.spacingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.table?.displayText ??
                                  l10n.tableSelectorNoTable,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.heldTicketsPrintNumber,
                            icon: const Icon(
                              Icons.confirmation_number_outlined,
                              color: PosTheme.accentBlue,
                              size: 20,
                            ),
                            onPressed: onPrintNumber,
                          ),
                          Builder(
                            builder: (context) {
                              final billPrinted = ref
                                  .watch(billPrintStatusProvider)
                                  .contains(ticket.id);
                              return IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: billPrinted
                                    ? l10n.heldTicketsPrintBillAgain
                                    : l10n.heldTicketsPrintBill,
                                icon: Icon(
                                  billPrinted
                                      ? Icons.print
                                      : Icons.print_outlined,
                                  color: billPrinted
                                      ? Colors.amber.shade700
                                      : PosTheme.accentBlue,
                                  size: 20,
                                ),
                                onPressed: onPrintBill,
                              );
                            },
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.heldTicketsCancelTitle,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: PosTheme.errorRed,
                              size: 20,
                            ),
                            onPressed: onDelete,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 13,
                            color: PosTheme.textHintOf(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.waitingTicketsItemsCount(itemCount),
                            style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                          if (heldAt != null) ...[
                            const SizedBox(width: 10),
                            Icon(
                              Icons.schedule_outlined,
                              size: 13,
                              color: PosTheme.textHintOf(context),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatReceiptTime(heldAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: PosTheme.textSecondaryOf(context),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: PosTheme.spacingXs),
                      Row(
                        children: [
                          Text(
                            l10n.heldTicketsTapToRestore,
                            style: TextStyle(
                              fontSize: 12,
                              color: PosTheme.accentBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.restore,
                            color: PosTheme.accentBlue,
                            size: 18,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
