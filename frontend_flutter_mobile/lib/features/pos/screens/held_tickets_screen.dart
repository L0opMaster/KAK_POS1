import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../shell/mobile_shell_screen.dart';
import '../models/cart_models.dart';
import '../providers/cart_provider.dart';
import '../providers/held_ticket_provider.dart';

/// ADAPTED from `frontend-flutter-pos/lib/features/pos/widgets/
/// held_tickets_dialog.dart`'s `HeldTicketsDialog` — same tile layout
/// (waiting-number-first title, falling back to the raw ticket id;
/// table + "tap to restore" subtitle; delete icon + restore chevron),
/// same tap-to-restore / delete-with-confirmation behavior. Presented as
/// the Day 5 "Held / Open Tickets" bottom-nav tab's real content (a full
/// screen) instead of a dialog popped from within `PosRegisterScreen` —
/// this task's Day 5 shell already reserved that tab for this feature.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(heldTicketProvider);
    final tickets = state.tickets;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.heldTicketsTitle)),
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
                            size: 48,
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
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        PosTheme.radiusMedium,
                      ),
                      side: BorderSide(color: PosTheme.borderColorOf(context)),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: PosTheme.backgroundPageOf(context),
                          borderRadius: BorderRadius.circular(
                            PosTheme.radiusSmall,
                          ),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: PosTheme.primaryGreen,
                        ),
                      ),
                      title: FutureBuilder<int?>(
                        // Prefer the stable local waiting number bound
                        // to this ticket (survives resume/re-hold) over
                        // the backend row id, which changes every time
                        // a ticket is resumed and held again.
                        future: ref
                            .read(waitingNumberServiceProvider)
                            .getNumberForOrder(ticket.id),
                        builder: (context, snapshot) {
                          final label = snapshot.data != null
                              ? l10n.heldTicketsTicketLabel(
                                  snapshot.data.toString().padLeft(3, '0'),
                                )
                              : l10n.heldTicketsTicketLabel(
                                  ticket.id.toString(),
                                );
                          return Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          );
                        },
                      ),
                      subtitle: Text(
                        ticket.table != null
                            ? '${ticket.table!.displayText} • ${l10n.heldTicketsTapToRestore}'
                            : l10n.heldTicketsTapToRestore,
                        style: TextStyle(
                          fontSize: 12,
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: l10n.heldTicketsCancelTitle,
                            icon: const Icon(
                              Icons.delete_outline,
                              color: PosTheme.errorRed,
                            ),
                            onPressed: () => _confirmDelete(ticket),
                          ),
                          const Icon(Icons.restore, color: PosTheme.accentBlue),
                        ],
                      ),
                      onTap: () {
                        ref
                            .read(heldTicketProvider.notifier)
                            .restoreTicket(ticket);
                        ref.read(shellTabIndexProvider.notifier).state = 0;
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
