import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';
import 'pos_screen.dart';

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
                        final notifier = ref.read(heldTicketProvider.notifier);
                        await notifier.restoreTicket(ticket);
                        // Navigate to POS after restoring items to cart
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (_) => const PosScreen()),
                            (route) => false,
                          );
                        }
                      },
                      onDelete: () => ref
                          .read(heldTicketProvider.notifier)
                          .deleteTicket(ticket),
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
  });

  final HeldOrder ticket;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

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
