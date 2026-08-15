import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';
import '../providers/table_selection_provider.dart';
import '../providers/table_provider.dart';

/// Loyverse-inspired dialog for selecting a table.
///
/// Table selection is optional — counter-service shops that don't use
/// tables at all can just leave it unset ("No Table"). Picking a table (or
/// clearing it) updates both [tableSelectionProvider] (read by
/// held_ticket_provider.dart when holding/restoring a ticket) and the
/// active cart's `tableId` (read at checkout — see payment_screen.dart).
class TableSelector extends ConsumerStatefulWidget {
  const TableSelector({super.key});

  @override
  ConsumerState<TableSelector> createState() => _TableSelectorState();
}

class _TableSelectorState extends ConsumerState<TableSelector> {
  @override
  void initState() {
    super.initState();
    // tableProvider is a shared, app-wide singleton — once it's loaded once
    // anywhere (this dialog, the admin Tables screen, ...) it stays cached,
    // so relying on "only fetch while state is loading" (the old behavior)
    // meant every later open of this picker replayed a stale snapshot and
    // never reflected tables that became OCCUPIED/freed since. Refetch
    // every time this dialog actually opens instead.
    Future.microtask(() => ref.read(tableProvider.notifier).search());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tableProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: PosTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            ),
            child: Icon(Icons.table_restaurant,
                color: PosTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            context.l10n.tableSelectorTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: PosTheme.textPrimaryOf(context),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: state.when(
          data: (page) {
            if (page.content.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: PosTheme.backgroundPageOf(context),
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
                child: Column(
                  children: [
                    Icon(Icons.table_restaurant_outlined,
                        size: 48, color: PosTheme.textHintOf(context)),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.tableSelectorEmpty,
                      style: TextStyle(
                        color: PosTheme.textSecondaryOf(context),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: page.content.length,
                itemBuilder: (context, index) {
                  final table = page.content[index];
                  final isAvailable = table.status == 'AVAILABLE';
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 8),
                    color: isAvailable
                        ? null
                        : PosTheme.errorRed.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(PosTheme.radiusMedium),
                      side: BorderSide(
                        color: isAvailable
                            ? PosTheme.borderColorOf(context)
                            : PosTheme.errorRed.withValues(alpha: 0.4),
                      ),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? PosTheme.primaryGreenLight
                              : PosTheme.errorRed.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusSmall),
                        ),
                        child: Icon(
                          isAvailable ? Icons.table_restaurant : Icons.block,
                          color: isAvailable
                              ? PosTheme.primaryGreen
                              : PosTheme.errorRed,
                          size: 20,
                        ),
                      ),
                      title: Text(table.displayText,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: isAvailable
                          ? null
                          : Text(table.status,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: PosTheme.errorRed)),
                      trailing: isAvailable
                          ? Icon(Icons.chevron_right,
                              size: 20, color: PosTheme.textHintOf(context))
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color:
                                    PosTheme.errorRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                context.l10n.tableSelectorInUseBadge,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: PosTheme.errorRed,
                                ),
                              ),
                            ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(PosTheme.radiusMedium),
                      ),
                      onTap: () {
                        if (!isAvailable) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context.l10n.tableSelectorInUse(table.displayText),
                              ),
                              backgroundColor: PosTheme.errorRed,
                            ),
                          );
                          return;
                        }
                        ref.read(tableSelectionProvider.notifier).select(table);
                        ref.read(cartProvider.notifier).setTable(table.id);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator())),
          error: (e, st) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 40, color: PosTheme.errorRed),
                const SizedBox(height: 8),
                Text('${context.l10n.commonError}: $e',
                    style: const TextStyle(color: PosTheme.errorRed)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(tableSelectionProvider.notifier).select(null);
            ref.read(cartProvider.notifier).clearTable();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: PosTheme.textSecondaryOf(context),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            ),
          ),
          child: Text(
            context.l10n.tableSelectorNoTable,
            style: const TextStyle(color: Colors.blue),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            foregroundColor: PosTheme.textSecondaryOf(context),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
            ),
          ),
          child: Text(context.l10n.commonCancel),
        ),
      ],
    );
  }
}
