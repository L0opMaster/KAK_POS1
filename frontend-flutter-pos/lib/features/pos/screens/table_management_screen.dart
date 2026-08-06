import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/table_models.dart';
import '../providers/table_provider.dart';
import 'create_table.dart';

/// Table management screen — follows the same list UI as Employees: inline
/// ADD button, checkbox multi-select + bulk delete, search box, and
/// client-side pagination.
class TableManagementScreen extends ConsumerStatefulWidget {
  const TableManagementScreen({super.key});

  @override
  ConsumerState<TableManagementScreen> createState() =>
      _TableManagementScreenState();
}

class _TableManagementScreenState
    extends ConsumerState<TableManagementScreen> {
  static const int _pageSize = 6;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;

  // Selected table IDs remain selected when changing pages.
  final Set<int> _selectedTableIds = {};

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(tableProvider.notifier).search(size: 1000);
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref
        .read(tableProvider.notifier)
        .search(query: _searchCtl.text.trim(), size: 1000);
  }

  void _search(String query) {
    ref.read(tableProvider.notifier).search(query: query.trim(), size: 1000);
    setState(() => _currentPage = 0);
  }

  Future<void> _openCreateTable() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateTable()),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() => _currentPage = 0);
    }
  }

  Future<void> _openEditTable(RestaurantTable table) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateTable(initialTable: table)),
    );
  }

  void _toggleTable(int tableId, bool selected) {
    setState(() {
      if (selected) {
        _selectedTableIds.add(tableId);
      } else {
        _selectedTableIds.remove(tableId);
      }
    });
  }

  void _toggleCurrentPage(List<RestaurantTable> pageTables) {
    final pageIds = pageTables.map((t) => t.id).toSet();
    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedTableIds.contains);

    setState(() {
      if (allPageItemsSelected) {
        _selectedTableIds.removeAll(pageIds);
      } else {
        _selectedTableIds.addAll(pageIds);
      }
    });
  }

  Future<void> _deleteSelectedTables() async {
    if (_selectedTableIds.isEmpty) return;

    final numberSelected = _selectedTableIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.tableManagementDeleteTablesTitle),
          content: Text(
            context.l10n
                .tableManagementDeleteTablesMessage('$numberSelected'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(context.l10n.commonCancel.toUpperCase()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(context.l10n.commonDelete.toUpperCase(),
                  style: const TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final idsToDelete = _selectedTableIds.toList();

    try {
      for (final tableId in idsToDelete) {
        await ref.read(tableProvider.notifier).delete(tableId);
      }

      if (!mounted) return;

      setState(() {
        _selectedTableIds.clear();
        _currentPage = 0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n
              .tableManagementDeleteSuccess('${idsToDelete.length}')),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(context.l10n.tableManagementDeleteFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tableProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.navTables),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (page) {
            final tables = page.content;

            final isSearching = _searchCtl.text.trim().isNotEmpty;
            if (!isSearching && tables.isEmpty && _hasLoadedOnce) {
              return _buildEmptyState();
            }

            return _buildTableList(tables, loading: false);
          },
          loading: () {
            if (!_hasLoadedOnce) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildTableList(const [], loading: true);
          },
          error: (error, _) => _buildErrorState('$error'),
        ),
      ),
    );
  }

  Widget _buildTableList(
    List<RestaurantTable> allTables, {
    required bool loading,
  }) {
    final totalItems = allTables.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);

    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageTables = allTables.sublist(startIndex, endIndex);

    final pageIds = pageTables.map((t) => t.id).toSet();
    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedTableIds.contains);
    final somePageItemsSelected = pageIds.any(_selectedTableIds.contains);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          Card(
            color: Colors.white,
            elevation: 3,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(30, 28, 30, 22),
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _openCreateTable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(160, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.tableManagementAddTable.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: context.l10n.tableManagementDeleteSelectedTooltip,
                        onPressed: _selectedTableIds.isEmpty
                            ? null
                            : _deleteSelectedTables,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          foregroundColor: Colors.red,
                          disabledForegroundColor: Colors.grey.shade400,
                          side: BorderSide(
                            color: _selectedTableIds.isEmpty
                                ? Colors.grey.shade300
                                : Colors.red,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      if (_selectedTableIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.tableManagementSelectedCount(
                              '${_selectedTableIds.length}'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText: context.l10n.tableManagementSearchHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchCtl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtl.clear();
                                      _search('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: PosTheme.backgroundPage,
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(PosTheme.radiusMedium),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                              horizontal: 12,
                            ),
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Checkbox(
                          tristate: true,
                          value: allPageItemsSelected
                              ? true
                              : somePageItemsSelected
                                  ? null
                                  : false,
                          onChanged: (_) => _toggleCurrentPage(pageTables),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.navTables,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.paginationShowingOfTotal(
                            '${pageTables.length}', '$totalItems'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageTables.isEmpty)
                  _buildNoResultsRow(loading: loading)
                else
                  ...pageTables.map(_buildTableRow),
                if (pageTables.isNotEmpty)
                  _buildPaginationControls(
                    currentPage: safeCurrentPage,
                    totalPages: totalPages,
                    totalItems: totalItems,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsRow({required bool loading}) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              context.l10n.tableManagementNoResults,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(RestaurantTable table) {
    final selected = _selectedTableIds.contains(table.id);

    final subtitleParts = [
      context.l10n.tableManagementSeatsCount('${table.capacity}'),
      if (table.section != null && table.section!.isNotEmpty) table.section!,
    ];
    final subtitle = subtitleParts.join(' • ');

    final statusColor = switch (table.status) {
      'AVAILABLE' => PosTheme.successGreen,
      'OCCUPIED' => PosTheme.errorRed,
      'RESERVED' => PosTheme.warningAmber,
      _ => Colors.grey,
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                child: Checkbox(
                  value: selected,
                  onChanged: (value) => _toggleTable(table.id, value ?? false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _openEditTable(table),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFF99D267),
                          child:
                              Icon(Icons.table_restaurant, color: Colors.white),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                table.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  table.status.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              if (!table.isActive) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.l10n.commonInactive.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required int totalItems,
  }) {
    final firstItem = totalItems == 0 ? 0 : currentPage * _pageSize + 1;
    final lastItem = math.min((currentPage + 1) * _pageSize, totalItems);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            context.l10n.paginationRangeOfTotal(
                '$firstItem', '$lastItem', '$totalItems'),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(width: 20),
          IconButton(
            tooltip: context.l10n.paginationFirstPage,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: context.l10n.paginationPreviousPage,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(
              context.l10n
                  .paginationPageOfTotal('${currentPage + 1}', '$totalPages'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: context.l10n.paginationNextPage,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: context.l10n.paginationLastPage,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _currentPage = totalPages - 1),
            icon: const Icon(Icons.last_page),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Card(
              color: Colors.white,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 45,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 105,
                      height: 105,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.table_restaurant_outlined,
                        size: 52,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.l10n.navTables,
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.tableManagementEmptyStateDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _openCreateTable,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(165, 54),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.l10n.tableManagementAddTable.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _refresh,
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
