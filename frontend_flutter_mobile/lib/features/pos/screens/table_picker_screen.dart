import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../shell/mobile_shell_screen.dart';
import '../models/table_models.dart';
import '../providers/cart_provider.dart';
import '../providers/table_provider.dart';
import '../providers/table_selection_provider.dart';
import '../widgets/table_tile.dart';

/// ADAPTED from `frontend-flutter-pos/lib/features/pos/widgets/
/// table_selector.dart`'s `TableSelector` — same status coloring/tap
/// behavior (AVAILABLE tables are tappable, everything else shows an
/// "IN USE" badge and a SnackBar on tap instead of a selection),
/// same dual-write on selection (`tableSelectionProvider.notifier.select`
/// for the persisted device-local default AND
/// `cartProvider.notifier.setTable` for the active sale), same "No Table"
/// clear action.
///
/// REDESIGNED (this session): the original mobile port was a plain
/// `ListTile` list — functional but visually flat, and it never used
/// `RestaurantTable.section`/`.capacity`, both of which have been sitting
/// unused in the model since Day 9. Neither `[OLD/SOURCE]`'s own
/// `TableSelector` groups by section or shows capacity either (confirmed
/// — it's the same plain list), so this is a deliberate visual upgrade
/// for the mobile form factor, not a source port: a search field, tables
/// grouped under their `section` (falling back to a single ungrouped
/// group when a table has none), and a 3-column grid of the shared
/// `TableTile` card (see that file) showing capacity and status at a
/// glance instead of one row of text per table.
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
///
/// CORRECTED (this session, same root cause as the Day 9 fix above but on
/// the AppBar side of it): this screen used to wrap itself in its own
/// `Scaffold(appBar: AppBar(...))`, stacked on top of `MobileShellScreen`'s
/// own `AppBar(title: Text(destinations[index].label))` — every tab body
/// renders inside that shell `Scaffold`'s body, not as its own screen, so
/// a second `Scaffold` here just rendered a second toolbar directly below
/// the first one. Harder to notice here than on `held_tickets_screen.dart`
/// (whose inner title happened to be the literal same string as its shell
/// tab label, "Held Tickets" shown twice) since this screen's inner title
/// ("Select Table") read differently from the shell's "Tables" label and
/// looked like an intentional title/subtitle pair — structurally the same
/// bug though. Fixed the same way `pos_register_screen.dart` (which never
/// had this problem) already does it: no `Scaffold`/`AppBar` here at all,
/// content returned directly. The "No Table" action that used to live in
/// the removed AppBar's `actions` now sits next to the search field.
class TablePickerScreen extends ConsumerStatefulWidget {
  const TablePickerScreen({super.key});

  @override
  ConsumerState<TablePickerScreen> createState() => _TablePickerScreenState();
}

class _TablePickerScreenState extends ConsumerState<TablePickerScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Refetch every time this screen opens — tableProvider is a shared,
    // app-wide singleton, so relying on "only fetch while loading" would
    // replay a stale AVAILABLE/OCCUPIED snapshot on every later open.
    Future.microtask(() => ref.read(tableProvider.notifier).search());
    _searchCtl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _selectNone() {
    ref.read(tableSelectionProvider.notifier).select(null);
    ref.read(cartProvider.notifier).clearTable();
    ref.read(shellTabIndexProvider.notifier).state = 0;
  }

  void _select(RestaurantTable table) {
    ref.read(tableSelectionProvider.notifier).select(table);
    ref.read(cartProvider.notifier).setTable(table.id);
    ref.read(shellTabIndexProvider.notifier).state = 0;
  }

  /// Stable grouping + ordering: tables sharing a `section` stay together,
  /// sections appear in first-seen order, sectionless tables collect under
  /// one trailing `null`-keyed group.
  Map<String?, List<RestaurantTable>> _grouped(List<RestaurantTable> tables) {
    final groups = <String?, List<RestaurantTable>>{};
    for (final table in tables) {
      final key = (table.section?.trim().isEmpty ?? true) ? null : table.section;
      groups.putIfAbsent(key, () => []).add(table);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tableProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    // The search field + "No Table" button are a PERSISTENT header, deliberately
    // outside `state.when()` below — "No Table" must stay reachable in the
    // loading/error states too, not only once table data has loaded (this
    // was a real bug in an earlier draft here: nesting it inside the `data`
    // branch made it disappear whenever the fetch was still in flight or
    // had failed, exactly the states a real "No Table" action needs to
    // survive — mirrors how it used to live in this screen's now-removed
    // AppBar's `actions`, unconditionally rendered no matter what the body
    // below it was doing).
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PosTheme.spacingMd,
            PosTheme.spacingSm,
            PosTheme.spacingMd,
            PosTheme.spacingMd,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtl,
                  decoration: InputDecoration(
                    hintText: l10n.commonSearch,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: PosTheme.backgroundCardOf(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        PosTheme.radiusMedium,
                      ),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PosTheme.spacingSm),
              OutlinedButton(
                onPressed: _selectNone,
                child: Text(l10n.tableSelectorNoTable),
              ),
            ],
          ),
        ),
        Expanded(
          child: state.when(
            data: (page) {
              final visible = query.isEmpty
                  ? page.content
                  : page.content
                        .where(
                          (t) => t.displayText.toLowerCase().contains(query),
                        )
                        .toList();
              if (visible.isEmpty) {
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
                        style: TextStyle(
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final groups = _grouped(visible);
              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  PosTheme.spacingMd,
                  0,
                  PosTheme.spacingMd,
                  PosTheme.spacingMd,
                ),
                children: [
                  for (final entry in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: PosTheme.spacingSm,
                      ),
                      child: Text(
                        entry.key ?? l10n.tableSelectorTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: PosTheme.spacingSm,
                            crossAxisSpacing: PosTheme.spacingSm,
                            childAspectRatio: 0.95,
                          ),
                      itemCount: entry.value.length,
                      itemBuilder: (context, i) {
                        final table = entry.value[i];
                        return TableTile(
                          table: table,
                          onTap: () => _select(table),
                        );
                      },
                    ),
                    const SizedBox(height: PosTheme.spacingSm),
                  ],
                ],
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
        ),
      ],
    );
  }
}
