import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/waiting_ticket_provider.dart';
import '../services/print_service.dart';

/// Mobile-friendly waiting-tickets "queue board" — a customer-facing-style
/// list of local waiting numbers with Ready/Collected actions.
///
/// ADAPTED from `frontend-flutter-pos/lib/features/pos/widgets/
/// waiting_tickets_dialog.dart`'s `WaitingTicketsDialog` — same data
/// (`waitingTicketsProvider`, sorted by `createdAt`), same two actions
/// (`markTicketReady` / `completeWaitingTicket`, each followed by
/// `ref.invalidate(waitingTicketsProvider)`), same print-the-bare-number
/// button. MOBILE UI REIMPLEMENT: desktop's fixed 650x550 `Dialog` becomes
/// a full-screen route (this app's established convention — see
/// `mobile_role_management_screen.dart`'s permission editor) so a long
/// queue never overflows a phone screen, and adds pull-to-refresh plus an
/// AppBar refresh action since there is no auto-refresh/polling.
class MobileWaitingTicketsScreen extends ConsumerWidget {
  const MobileWaitingTicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ticketsAsync = ref.watch(waitingTicketsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.waitingTicketsTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(waitingTicketsProvider),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(waitingTicketsProvider);
          await ref.read(waitingTicketsProvider.future);
        },
        child: ticketsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stack) => ListView(
            children: [
              SizedBox(
                height: 400,
                child: Center(
                  child: Text('${l10n.commonError}: $error'),
                ),
              ),
            ],
          ),
          data: (List<WaitingTicket> tickets) {
            if (tickets.isEmpty) {
              return ListView(
                // ListView (not Column) so pull-to-refresh still works on
                // an empty list.
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 40,
                            color: PosTheme.textHintOf(context),
                          ),
                          const SizedBox(height: PosTheme.spacingMd),
                          Text(
                            l10n.waitingTicketsEmpty,
                            style: TextStyle(
                              color: PosTheme.textSecondaryOf(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              itemCount: tickets.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: PosTheme.spacingSm),
              itemBuilder: (_, int index) {
                return _WaitingTicketCard(ticket: tickets[index]);
              },
            );
          },
        ),
      ),
    );
  }
}

class _WaitingTicketCard extends ConsumerWidget {
  const _WaitingTicketCard({required this.ticket});

  final WaitingTicket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final String number = ticket.waitingNumber.toString().padLeft(3, '0');
    final int quantity = ticket.items.fold<int>(
      0,
      (int total, CartItem item) => total + item.qty,
    );
    final String currency = watchCurrency(ref);

    return Container(
      padding: const EdgeInsets.all(PosTheme.spacingMd),
      decoration: BoxDecoration(
        border: Border.all(color: PosTheme.borderColorOf(context)),
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: PosTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                child: Text(
                  '#$number',
                  style: TextStyle(
                    color: PosTheme.primaryGreen,
                    fontSize: PosTheme.fontSizeLg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: PosTheme.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ticket.orderMode.label} • ${ticket.status.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.waitingTicketsItemsCount(quantity)} • '
                      '${formatAmount(ticket.total, currency)}',
                      style: TextStyle(
                        fontSize: PosTheme.fontSizeSm,
                        color: PosTheme.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l10n.receiptPrint,
                icon: const Icon(
                  Icons.print_outlined,
                  size: 20,
                  color: PosTheme.accentBlue,
                ),
                onPressed: () => _printWaitingTicket(context, ref, ticket),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.spacingSm),
          Row(
            children: [
              if (ticket.status != WaitingTicketStatus.ready) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref
                          .read(waitingNumberServiceProvider)
                          .markTicketReady(ticket.id);
                      ref.invalidate(waitingTicketsProvider);
                    },
                    child: Text(l10n.waitingTicketsReady),
                  ),
                ),
                const SizedBox(width: PosTheme.spacingSm),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    await ref
                        .read(waitingNumberServiceProvider)
                        .completeWaitingTicket(ticket.id);
                    ref.invalidate(waitingTicketsProvider);
                  },
                  child: Text(l10n.waitingTicketsCollected),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Prints a compact queue-number ticket for [ticket] — just the waiting
/// number in large print, not an itemized bill — so the customer can carry
/// it and come back to the counter when their order/number is called.
Future<void> _printWaitingTicket(
  BuildContext context,
  WidgetRef ref,
  WaitingTicket ticket,
) async {
  final l10n = context.l10n;
  try {
    Map<String, dynamic>? company;
    try {
      company = await ref.read(companyProfileProvider.future);
    } catch (_) {
      // No company profile yet — the ticket still prints without a
      // business name header.
    }

    if (!context.mounted) return;
    final bool ok =
        await ref.read(printServiceProvider).printWaitingNumberTicket(
              context,
              waitingNumber: ticket.waitingNumber,
              businessName: company?['businessName'] as String?,
              heading: l10n.waitingTicketsPrintYourNumber,
              instruction: l10n.waitingTicketsPrintInstruction,
            );
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.printerPrintFailed),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  } catch (e) {
    debugPrint('Waiting number ticket print failed: $e');
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.printerPrintFailed),
        backgroundColor: PosTheme.errorRed,
      ),
    );
  }
}
