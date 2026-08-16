import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../providers/held_ticket_provider.dart';

/// Reached from `CartItemsList`'s empty-cart state ("Open Held Tickets"
/// button — mirrors `frontend-flutter-pos/lib/features/pos/widgets/
/// cart_items_list.dart`'s same button, which opens `HeldTicketsDialog`
/// there). A dedicated bottom-nav tab already exists for browsing/printing/
/// deleting held tickets (`held_tickets_screen.dart`), so this sheet stays
/// deliberately minimal — just enough to glance at what's held and restore
/// one into the cart without leaving the Register tab — following the same
/// lightweight-bottom-sheet-with-a-list pattern `table_picker_sheet.dart`
/// already established for the cart's table chip.
Future<void> showHeldTicketsPickerSheet(BuildContext context, WidgetRef ref) {
  Future.microtask(
    () => ref.read(heldTicketProvider.notifier).loadHeldTickets(),
  );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(heldTicketProvider);
              final tickets = state.tickets;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PosTheme.spacingLg,
                      PosTheme.spacingMd,
                      PosTheme.spacingLg,
                      PosTheme.spacingSm,
                    ),
                    child: Text(
                      l10n.heldTicketsTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: state.loading && tickets.isEmpty
                        ? const Center(child: CircularProgressIndicator())
                        : tickets.isEmpty
                        ? Center(child: Text(l10n.heldTicketsEmpty))
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(PosTheme.spacingMd),
                            itemCount: tickets.length,
                            itemBuilder: (context, i) {
                              final ticket = tickets[i];
                              final itemCount = ticket.cartItems?.length ?? 0;
                              final heldAt = parseBackendTimestamp(
                                ticket.createdAt,
                              );
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(
                                  bottom: PosTheme.spacingSm,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    PosTheme.radiusMedium,
                                  ),
                                  side: BorderSide(
                                    color: PosTheme.borderColorOf(context),
                                  ),
                                ),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.receipt_long_outlined,
                                  ),
                                  iconColor: PosTheme.primaryGreen,
                                  title: Text(
                                    ticket.table?.displayText ??
                                        l10n.heldTicketsTicketLabel(
                                          ticket.id.toString(),
                                        ),
                                  ),
                                  subtitle: Text(
                                    heldAt != null
                                        ? '${l10n.waitingTicketsItemsCount(itemCount)} · ${formatReceiptTime(heldAt)}'
                                        : l10n.waitingTicketsItemsCount(
                                            itemCount,
                                          ),
                                  ),
                                  trailing: const Icon(
                                    Icons.restore,
                                    color: PosTheme.accentBlue,
                                  ),
                                  onTap: () {
                                    ref
                                        .read(heldTicketProvider.notifier)
                                        .restoreTicket(ticket);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}
