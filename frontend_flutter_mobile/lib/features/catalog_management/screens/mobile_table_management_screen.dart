import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/table_models.dart';
import '../../pos/providers/table_provider.dart';
import 'mobile_create_table_screen.dart';

/// Admin table-management screen — create/edit/delete physical restaurant
/// tables. Distinct from `table_picker_screen.dart` (the Tables bottom-nav
/// tab used to pick a table for an in-progress sale): that screen only ever
/// calls `tableProvider.notifier.search()`, which this screen shares, but
/// neither screen calls into the other, and this screen owns its own
/// `Scaffold`/`AppBar` (it's pushed as a route, not a permanent tab body).
///
/// Mirrors `mobile_suppliers_screen.dart`'s established admin-list pattern:
/// AppBar title toggles to "N selected" during multi-select, FAB opens the
/// create form, tapping a row opens edit, checkbox multi-select + bulk
/// delete behind an `AlertDialog` confirm (sequential per-id delete,
/// matching desktop's `TableManagementScreen`). Desktop's paged `DataTable`
/// becomes a plain scrolling list (mobile UI reimplement) with live
/// client-side search filtering, same as suppliers.
class MobileTableManagementScreen extends ConsumerStatefulWidget {
  const MobileTableManagementScreen({super.key});

  @override
  ConsumerState<MobileTableManagementScreen> createState() =>
      _MobileTableManagementScreenState();
}

class _MobileTableManagementScreenState
    extends ConsumerState<MobileTableManagementScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final Set<int> _selected = {};

  TableStats? _stats;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(tableProvider.notifier).search(size: 1000);
      _loadStats();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await ref.read(tableProvider.notifier).loadStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // Summary row is a nice-to-have — silently skip it on failure.
    }
  }

  Future<void> _refresh() async {
    await ref
        .read(tableProvider.notifier)
        .search(query: _searchCtl.text.trim(), size: 1000);
    _loadStats();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileCreateTableScreen()),
    );
    // `_refresh()` re-triggers `search()` explicitly rather than relying on
    // `create()`'s own internal refresh alone — matches every other admin
    // list screen in this app (category/unit/item/modifier), all of which
    // reload after returning from their create/edit form.
    if (created == true) _refresh();
  }

  Future<void> _openEdit(RestaurantTable table) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCreateTableScreen(initialTable: table),
      ),
    );
    if (updated == true) _refresh();
  }

  Future<void> _deleteSelected() async {
    final l10n = context.l10n;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.tableManagementDeleteTablesTitle),
        content: Text(l10n.tableManagementDeleteTablesMessage('$count')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ids = [..._selected];
    try {
      for (final id in ids) {
        await ref.read(tableProvider.notifier).delete(id);
      }
      setState(() => _selected.clear());
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tableManagementDeleteSuccess('${ids.length}')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.tableManagementDeleteFailed('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  Color _statusColor(String status) => switch (status) {
        'AVAILABLE' => PosTheme.successGreen,
        'OCCUPIED' => PosTheme.errorRed,
        'RESERVED' => PosTheme.warningAmber,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(tableProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty
              ? l10n.navTables
              : l10n.tableManagementSelectedCount('${_selected.length}'),
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: l10n.tableManagementDeleteSelectedTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
            )
          else
            IconButton(
              tooltip: l10n.commonRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.tableManagementAddTable,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              PosTheme.spacingMd,
              PosTheme.spacingMd,
              PosTheme.spacingMd,
              0,
            ),
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.tableManagementSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          if (_stats != null) _buildStatsRow(_stats!),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(PosTheme.spacingLg),
                  child: Text('${l10n.commonError}: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (page) {
                final tables = query.isEmpty
                    ? page.content
                    : page.content
                        .where(
                          (t) =>
                              t.displayName.toLowerCase().contains(query) ||
                              t.tableNumber.toLowerCase().contains(query),
                        )
                        .toList();

                if (tables.isEmpty) {
                  return Center(
                    child: Text(
                      query.isEmpty
                          ? l10n.tableManagementEmptyStateDescription
                          : l10n.tableManagementNoResults,
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(PosTheme.spacingMd),
                    itemCount: tables.length,
                    itemBuilder: (context, i) {
                      final table = tables[i];
                      final selected = _selected.contains(table.id);
                      final subtitleParts = [
                        l10n.tableManagementSeatsCount('${table.capacity}'),
                        if (table.section?.isNotEmpty == true) table.section!,
                      ];

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(
                          bottom: PosTheme.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PosTheme.radiusMedium,
                          ),
                          side: BorderSide(
                            color: selected
                                ? PosTheme.primaryGreen
                                : PosTheme.borderColorOf(context),
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _openEdit(table),
                          leading: Checkbox(
                            value: selected,
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected.add(table.id);
                              } else {
                                _selected.remove(table.id);
                              }
                            }),
                          ),
                          title: Text(
                            table.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            subtitleParts.join(' • '),
                            style: TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StatusPill(
                                label: table.status.replaceAll('_', ' '),
                                color: _statusColor(table.status),
                              ),
                              if (!table.isActive) ...[
                                const SizedBox(width: PosTheme.spacingXs),
                                _StatusPill(
                                  label: l10n.commonInactive,
                                  color: PosTheme.textHintOf(context),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(TableStats stats) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosTheme.spacingMd,
        PosTheme.spacingSm,
        PosTheme.spacingMd,
        0,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatChip(
              label: l10n.navTables,
              value: stats.totalTables,
              color: PosTheme.primaryGreen,
            ),
            const SizedBox(width: PosTheme.spacingSm),
            _StatChip(
              label: 'AVAILABLE',
              value: stats.availableTables,
              color: PosTheme.successGreen,
            ),
            const SizedBox(width: PosTheme.spacingSm),
            _StatChip(
              label: 'OCCUPIED',
              value: stats.occupiedTables,
              color: PosTheme.errorRed,
            ),
            const SizedBox(width: PosTheme.spacingSm),
            _StatChip(
              label: 'RESERVED',
              value: stats.reservedTables,
              color: PosTheme.warningAmber,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PosTheme.spacingMd,
        vertical: PosTheme.spacingXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(
          fontSize: PosTheme.fontSizeXs,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PosTheme.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: PosTheme.fontSizeXs,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
