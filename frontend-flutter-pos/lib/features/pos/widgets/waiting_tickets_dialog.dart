import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/waiting_ticket_provider.dart';

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