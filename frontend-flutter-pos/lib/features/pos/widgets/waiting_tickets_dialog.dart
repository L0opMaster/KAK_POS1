import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/waiting_ticket_provider.dart';
import '../services/print_service.dart';

class WaitingTicketsDialog extends ConsumerWidget {
  const WaitingTicketsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticketsAsync =
        ref.watch(waitingTicketsProvider);

    return Dialog(
      child: SizedBox(
        width: 650,
        height: 550,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: PosTheme.primaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    context.l10n.waitingTicketsTitle,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ticketsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (Object error, StackTrace stack) {
                  return Center(
                    child: Text('${context.l10n.commonError}: $error'),
                  );
                },
                data: (List<WaitingTicket> tickets) {
                  if (tickets.isEmpty) {
                    return Center(
                      child: Text(
                        context.l10n.waitingTicketsEmpty,
                        style: TextStyle(
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, int index) {
                      final WaitingTicket ticket =
                          tickets[index];

                      return _WaitingTicketTile(
                        ticket: ticket,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingTicketTile extends ConsumerWidget {
  const _WaitingTicketTile({
    required this.ticket,
  });

  final WaitingTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String number = ticket.waitingNumber
        .toString()
        .padLeft(3, '0');

    final int quantity = ticket.items.fold<int>(
      0,
      (int total, CartItem item) => total + item.qty,
    );
    final cur = watchCurrency(ref);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: PosTheme.borderColorOf(context),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PosTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '#$number',
              style: TextStyle(
                color: PosTheme.primaryGreen,
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  '${ticket.orderMode.label} • '
                  '${ticket.status.label}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${context.l10n.waitingTicketsItemsCount(quantity)} • '
                  '${formatAmount(ticket.total, cur)}',
                  style: TextStyle(
                    color: PosTheme.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.receiptPrint,
            icon: const Icon(Icons.print_outlined,
                size: 20, color: PosTheme.accentBlue),
            onPressed: () => _printWaitingTicket(context, ref, ticket),
          ),
          if (ticket.status != WaitingTicketStatus.ready)
            OutlinedButton(
              onPressed: () async {
                await ref
                    .read(waitingNumberServiceProvider)
                    .markTicketReady(ticket.id);

                ref.invalidate(waitingTicketsProvider);
              },
              child: Text(context.l10n.waitingTicketsReady),
            ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(waitingNumberServiceProvider)
                  .completeWaitingTicket(ticket.id);

              ref.invalidate(waitingTicketsProvider);
            },
            child: Text(context.l10n.waitingTicketsCollected),
          ),
        ],
      ),
    );
  }
}

/// Prints a compact queue-number ticket for [ticket] — just the waiting
/// number in large print, not an itemized bill — so the customer can carry
/// it and come back to the counter when their order/number is called. See
/// [PrintService.printWaitingNumberTicket] for the itemized-bill vs.
/// bare-number distinction (that's `held_tickets_dialog.dart`'s
/// `_buildBillReceipt`/`_openBillPreview`, for the *held ticket* bill, a
/// different flow).
Future<void> _printWaitingTicket(
  BuildContext context,
  WidgetRef ref,
  WaitingTicket ticket,
) async {
  try {
    Map<String, dynamic>? company;
    try {
      company = await ref.read(companyProfileProvider.future);
    } catch (_) {
      // No company profile yet — the ticket still prints without a
      // business name header.
    }

    if (!context.mounted) return;
    final ok = await ref.read(printServiceProvider).printWaitingNumberTicket(
          context,
          waitingNumber: ticket.waitingNumber,
          businessName: company?['businessName'] as String?,
          heading: context.l10n.waitingTicketsPrintYourNumber,
          instruction: context.l10n.waitingTicketsPrintInstruction,
        );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.printerPrintFailed),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  } catch (e) {
    debugPrint('Waiting number ticket print failed: $e');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.printerPrintFailed),
        backgroundColor: PosTheme.errorRed,
      ),
    );
  }
}