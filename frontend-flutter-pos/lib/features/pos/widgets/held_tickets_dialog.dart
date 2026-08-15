import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(heldTicketProvider);
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
        width: 400,
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
                height: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tickets.length,
                  itemBuilder: (ctx, i) {
                    final ticket = tickets[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium),
                        side: BorderSide(color: PosTheme.borderColorOf(ctx)),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: PosTheme.backgroundPageOf(ctx),
                            borderRadius:
                                BorderRadius.circular(PosTheme.radiusSmall),
                          ),
                          child: Icon(Icons.receipt_long,
                              color: PosTheme.primaryGreen, size: 20),
                        ),
                        title: FutureBuilder<int?>(
                          // Prefer the stable local waiting number bound to
                          // this ticket (survives resume/re-hold) over the
                          // backend row id, which changes every time a
                          // ticket is resumed and held again.
                          future: ref
                              .read(waitingNumberServiceProvider)
                              .getNumberForOrder(ticket.id),
                          builder: (context, snapshot) {
                            final label = snapshot.data != null
                                ? context.l10n.heldTicketsTicketLabel(
                                    snapshot.data.toString().padLeft(3, '0'))
                                : context.l10n
                                    .heldTicketsTicketLabel(ticket.id.toString());
                            return Text(label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14));
                          },
                        ),
                        subtitle: Text(
                            ticket.table != null
                                ? '${ticket.table!.displayText} • ${ctx.l10n.heldTicketsTapToRestore}'
                                : ctx.l10n.heldTicketsTapToRestore,
                            style: TextStyle(
                                fontSize: 12,
                                color: PosTheme.textSecondaryOf(ctx))),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: ctx.l10n.heldTicketsCancelTitle,
                              icon: const Icon(Icons.delete_outline,
                                  size: 20, color: PosTheme.errorRed),
                              onPressed: () => _confirmDelete(context, ref, ticket),
                            ),
                            const Icon(Icons.restore,
                                size: 20, color: PosTheme.accentBlue),
                          ],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusMedium),
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
