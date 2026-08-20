import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/table_models.dart';
import '../providers/cart_provider.dart';
import '../providers/table_provider.dart';
import '../providers/table_selection_provider.dart';

/// Full-screen table picker pushed from the cart's Table chip (replaces the
/// old [TableSelector] dialog for this entry point — see cart_panel.dart).
///
/// Selection here is staged locally in [_pending] and only committed to
/// [tableSelectionProvider]/`cartProvider` when the user taps CONFIRM;
/// popping via the back button (system or AppBar) leaves both untouched.
/// Both providers are app-wide singletons, so everything else the cart
/// carries (items, customer, discount, order mode, ...) is naturally
/// preserved across this push/pop — this screen never touches cartProvider
/// except via `setTable`/`clearTable` in [_confirm].
class TableSelectionScreen extends ConsumerStatefulWidget {
  const TableSelectionScreen({super.key});

  @override
  ConsumerState<TableSelectionScreen> createState() =>
      _TableSelectionScreenState();
}

class _TableSelectionScreenState extends ConsumerState<TableSelectionScreen> {
  String? _sectionFilter;
  RestaurantTable? _pending;

  @override
  void initState() {
    super.initState();
    _pending = ref.read(tableSelectionProvider);
    // Same "always refetch on open" reasoning as the dialog this replaces:
    // tableProvider is a shared singleton, so a stale cached page would
    // otherwise show tables as AVAILABLE after another till occupied them.
    Future.microtask(() => ref.read(tableProvider.notifier).search());
  }

  void _confirm() {
    final selectionNotifier = ref.read(tableSelectionProvider.notifier);
    final cartNotifier = ref.read(cartProvider.notifier);
    final table = _pending;
    if (table == null) {
      selectionNotifier.select(null);
      cartNotifier.clearTable();
    } else {
      selectionNotifier.select(table);
      cartNotifier.setTable(table.id);
    }
    Navigator.of(context).pop();
  }

  /// Sections present in the current table data, in sorted order. Not
  /// hardcoded — derived from `RestaurantTable.section`, which already
  /// exists on the model, so a section only appears here if some table
  /// actually uses it.
  List<String> _sections(List<RestaurantTable> tables) {
    final set = <String>{};
    for (final table in tables) {
      final section = table.section?.trim();
      if (section != null && section.isNotEmpty) set.add(section);
    }
    final list = set.toList()..sort();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tableProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tableSelectorTitle),
      ),
      body: SafeArea(
        child: state.when(
          data: (page) {
            final sections = _sections(page.content);
            final visible = _sectionFilter == null
                ? page.content
                : page.content
                    .where((t) => t.section == _sectionFilter)
                    .toList();

            return Column(
              children: [
                _buildSectionFilters(sections),
                const SizedBox(height: PosTheme.spacingSm),
                Expanded(
                  child: visible.isEmpty
                      ? _buildEmptyState(context)
                      : _buildGrid(visible),
                ),
                _buildBottomBar(context),
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
    );
  }

  Widget _buildSectionFilters(List<String> sections) {
    final chips = <String?>[null, ...sections];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosTheme.spacingLg,
        PosTheme.spacingMd,
        PosTheme.spacingLg,
        0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: chips.map((section) {
            final selected = _sectionFilter == section;
            return Padding(
              padding: const EdgeInsets.only(right: PosTheme.spacingSm),
              child: FilterChip(
                label: Text(
                  section ?? context.l10n.commonAll,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white : Colors.black,
                  ),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _sectionFilter = section),
                selectedColor: PosTheme.primaryGreen,
                checkmarkColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.table_restaurant_outlined,
              size: 48, color: PosTheme.textHintOf(context)),
          const SizedBox(height: PosTheme.spacingMd),
          Text(
            context.l10n.tableSelectorEmpty,
            style: TextStyle(color: PosTheme.textSecondaryOf(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<RestaurantTable> tables) {
    // `null` sentinel renders the "No Table" tile; kept in the same
    // scrolling grid (rather than a separate pinned button) so the layout
    // stays a single responsive region regardless of table count.
    final items = <RestaurantTable?>[null, ...tables];

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        PosTheme.spacingLg,
        PosTheme.spacingSm,
        PosTheme.spacingLg,
        PosTheme.spacingLg,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: PosTheme.spacingSm,
        crossAxisSpacing: PosTheme.spacingSm,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final table = items[index];
        if (table == null) {
          return _NoTableTile(
            selected: _pending == null,
            onTap: () => setState(() => _pending = null),
          );
        }
        return _TableGridTile(
          table: table,
          selected: _pending?.id == table.id,
          onTap: () => setState(() => _pending = table),
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final l10n = context.l10n;
    final label = _pending == null
        ? l10n.tableSelectorNoneSelected
        : l10n.tableSelectorSelectedLabel(_pending!.displayText);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PosTheme.spacingLg,
        vertical: PosTheme.spacingMd,
      ),
      decoration: BoxDecoration(
        color: PosTheme.backgroundCardOf(context),
        border: Border(top: BorderSide(color: PosTheme.borderColorOf(context))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
            ),
            const SizedBox(width: PosTheme.spacingMd),
            ElevatedButton(
              onPressed: _confirm,
              child: Text(l10n.commonConfirm.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grid card for a single table — status-colored border/icon like the
/// dialog this screen replaces (table_selector.dart), plus a highlighted
/// border + check badge when it's the in-progress (not yet confirmed)
/// selection.
class _TableGridTile extends StatelessWidget {
  const _TableGridTile({
    required this.table,
    required this.selected,
    required this.onTap,
  });

  final RestaurantTable table;
  final bool selected;
  final VoidCallback onTap;

  bool get _isAvailable => table.status.toUpperCase() == 'AVAILABLE';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColor =
        _isAvailable ? PosTheme.primaryGreen : PosTheme.errorRed;
    final borderColor =
        selected ? PosTheme.primaryGreen : statusColor.withValues(alpha: 0.35);

    return Material(
      color: PosTheme.backgroundCardOf(context),
      borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
        onTap: _isAvailable
            ? onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.tableSelectorInUse(table.displayText)),
                    backgroundColor: PosTheme.errorRed,
                  ),
                ),
        child: Container(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            color: selected
                ? PosTheme.primaryGreen.withValues(alpha: 0.08)
                : statusColor.withValues(alpha: 0.06),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.table_restaurant_rounded,
                      color: statusColor, size: 26),
                  if (selected)
                    Icon(Icons.check_circle,
                        color: PosTheme.primaryGreen, size: 18)
                  else
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                ],
              ),
              const SizedBox(height: PosTheme.spacingSm),
              Text(
                table.displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.people_outline,
                      size: 12, color: PosTheme.textHintOf(context)),
                  const SizedBox(width: 2),
                  Text(
                    '${table.capacity}',
                    style: TextStyle(
                        fontSize: 11, color: PosTheme.textHintOf(context)),
                  ),
                  if (!_isAvailable) ...[
                    const Spacer(),
                    Text(
                      l10n.tableSelectorInUseBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "No Table" tile — clears the pending selection instead of picking one.
/// Always shown first regardless of the active section filter, mirroring
/// the "No Table" action that used to live in the dialog's actions row.
class _NoTableTile extends StatelessWidget {
  const _NoTableTile({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = PosTheme.textSecondaryOf(context);
    final borderColor =
        selected ? PosTheme.primaryGreen : PosTheme.borderColorOf(context);

    return Material(
      color: PosTheme.backgroundCardOf(context),
      borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(PosTheme.spacingMd),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            color:
                selected ? PosTheme.primaryGreen.withValues(alpha: 0.08) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, color: color, size: 26),
              const SizedBox(height: PosTheme.spacingSm),
              Text(
                context.l10n.tableSelectorNoTable,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: color),
              ),
              if (selected) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle,
                    color: PosTheme.primaryGreen, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
