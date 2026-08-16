import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/cart_provider.dart';
import '../providers/table_provider.dart';
import '../providers/table_selection_provider.dart';
import 'table_tile.dart';

/// Genuinely new — reached from the cart header's table chip (see
/// `cart_header.dart`), not from `[OLD/SOURCE]`. `table_picker_screen.dart`
/// (the Tables bottom-nav tab) can't be reused directly here: it's a
/// permanent tab body that switches `shellTabIndexProvider` on selection
/// instead of popping (see that file's Day 9 doc comment) — pushing it as
/// a route from the cart and having it "select by switching tabs
/// underneath" would be confusing. This is a lightweight bottom sheet with
/// the SAME dual-write on selection (`tableSelectionProvider.notifier
/// .select` + `cartProvider.notifier.setTable`/`clearTable`), reusing the
/// same `tableProvider` data and the shared `TableTile` card, but it just
/// pops itself when done.
Future<void> showTablePickerSheet(BuildContext context, WidgetRef ref) {
  Future.microtask(() => ref.read(tableProvider.notifier).search());

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      return DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(tableProvider);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      PosTheme.spacingLg,
                      PosTheme.spacingMd,
                      PosTheme.spacingSm,
                      PosTheme.spacingSm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.tableSelectorTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ref.read(tableSelectionProvider.notifier).select(null);
                            ref.read(cartProvider.notifier).clearTable();
                            Navigator.of(context).pop();
                          },
                          child: Text(l10n.tableSelectorNoTable),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: state.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          '${l10n.commonError}: $e',
                          style: TextStyle(color: PosTheme.errorRed),
                        ),
                      ),
                      data: (page) {
                        if (page.content.isEmpty) {
                          return Center(child: Text(l10n.tableSelectorEmpty));
                        }
                        return GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(PosTheme.spacingMd),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: PosTheme.spacingSm,
                            crossAxisSpacing: PosTheme.spacingSm,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: page.content.length,
                          itemBuilder: (context, i) {
                            final table = page.content[i];
                            return TableTile(
                              table: table,
                              dense: true,
                              onTap: () {
                                ref
                                    .read(tableSelectionProvider.notifier)
                                    .select(table);
                                ref
                                    .read(cartProvider.notifier)
                                    .setTable(table.id);
                                Navigator.of(context).pop();
                              },
                            );
                          },
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
