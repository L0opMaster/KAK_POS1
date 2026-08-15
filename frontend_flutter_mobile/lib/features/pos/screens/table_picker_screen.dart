import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../shell/mobile_shell_screen.dart';
import '../providers/cart_provider.dart';
import '../providers/table_provider.dart';
import '../providers/table_selection_provider.dart';

/// ADAPTED from `frontend-flutter-pos/lib/features/pos/widgets/
/// table_selector.dart`'s `TableSelector` — same status coloring/tap
/// behavior (AVAILABLE tables are tappable, everything else shows an
/// "IN USE" badge and a SnackBar on tap instead of a selection),
/// same dual-write on selection (`tableSelectionProvider.notifier.select`
/// for the persisted device-local default AND
/// `cartProvider.notifier.setTable` for the active sale), same "No Table"
/// clear action. Presented as a full screen (this task's mobile picker
/// convention) instead of an `AlertDialog` — matches
/// `customer_picker_screen.dart`'s equivalent choice.
///
/// CORRECTED Day 9: selecting a table (or "No Table") used to call
/// `Navigator.of(context).pop()`, copied from source's dialog-dismiss
/// pattern without noticing this screen isn't a dialog — it's a permanent
/// bottom-nav tab body (see `mobile_shell_screen.dart`'s `destinations`
/// list), never pushed via `Navigator`. Since `MobileShellScreen` is the
/// app's `home:` and therefore the only route on the root `Navigator`,
/// that `pop()` had nothing beneath it and tore the whole shell down
/// instead of just "closing" this screen — confirmed with a throwaway
/// reproduction test before fixing. Switching to the Register tab via
/// [shellTabIndexProvider] is the correct equivalent of "done, show me the
/// result".
class TablePickerScreen extends ConsumerStatefulWidget {
  const TablePickerScreen({super.key});

  @override
  ConsumerState<TablePickerScreen> createState() => _TablePickerScreenState();
}

class _TablePickerScreenState extends ConsumerState<TablePickerScreen> {
  @override
  void initState() {
    super.initState();
    // Refetch every time this screen opens — tableProvider is a shared,
    // app-wide singleton, so relying on "only fetch while loading" would
    // replay a stale AVAILABLE/OCCUPIED snapshot on every later open.
    Future.microtask(() => ref.read(tableProvider.notifier).search());
  }

  void _selectNone() {
    ref.read(tableSelectionProvider.notifier).select(null);
    ref.read(cartProvider.notifier).clearTable();
    ref.read(shellTabIndexProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tableProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tableSelectorTitle),
        actions: [
          TextButton(
            onPressed: _selectNone,
            child: Text(
              l10n.tableSelectorNoTable,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: state.when(
        data: (page) {
          if (page.content.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_restaurant_outlined,
                    size: 48,
                    color: PosTheme.textHintOf(context),
                  ),
                  const SizedBox(height: PosTheme.spacingMd),
                  Text(
                    l10n.tableSelectorEmpty,
                    style: TextStyle(color: PosTheme.textSecondaryOf(context)),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            itemCount: page.content.length,
            itemBuilder: (context, index) {
              final table = page.content[index];
              final isAvailable = table.status == 'AVAILABLE';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                color: isAvailable
                    ? null
                    : PosTheme.errorRed.withValues(alpha: 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
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
                      borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
                    ),
                    child: Icon(
                      isAvailable ? Icons.table_restaurant : Icons.block,
                      color: isAvailable
                          ? PosTheme.primaryGreen
                          : PosTheme.errorRed,
                    ),
                  ),
                  title: Text(
                    table.displayText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: isAvailable
                      ? null
                      : Text(
                          table.status,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: PosTheme.errorRed,
                          ),
                        ),
                  trailing: isAvailable
                      ? Icon(
                          Icons.chevron_right,
                          color: PosTheme.textHintOf(context),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: PosTheme.errorRed.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            l10n.tableSelectorInUseBadge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PosTheme.errorRed,
                            ),
                          ),
                        ),
                  onTap: () {
                    if (!isAvailable) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.tableSelectorInUse(table.displayText),
                          ),
                          backgroundColor: PosTheme.errorRed,
                        ),
                      );
                      return;
                    }
                    ref.read(tableSelectionProvider.notifier).select(table);
                    ref.read(cartProvider.notifier).setTable(table.id);
                    ref.read(shellTabIndexProvider.notifier).state = 0;
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Text(
            '${l10n.commonError}: $e',
            style: TextStyle(color: PosTheme.errorRed),
          ),
        ),
      ),
    );
  }
}
