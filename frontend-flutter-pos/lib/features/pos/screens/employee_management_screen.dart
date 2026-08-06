import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/features/pos/models/employee_model.dart';
import 'package:frontend_flutter_pos/features/pos/providers/employee_provider.dart';
import 'package:frontend_flutter_pos/features/pos/screens/create_employee.dart';
import 'package:frontend_flutter_pos/core/utils/l10n_extensions.dart';

class EmployeeManagementScreen extends ConsumerStatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  ConsumerState<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState
    extends ConsumerState<EmployeeManagementScreen> {
  static const int _pageSize = 6;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;

  // Selected employee IDs remain selected when changing pages.
  final Set<int> _selectedEmployeeIds = {};

  // Once the very first load finishes, the card stays mounted for good —
  // later fetches (search, refresh) only ever update its contents instead
  // of tearing down the whole screen for a bare spinner.
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(employeeProvider.notifier).load();
      if (mounted) {
        setState(() => _hasLoadedOnce = true);
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref
        .read(employeeProvider.notifier)
        .load(query: _searchCtl.text.trim());
  }

  void _search(String query) {
    ref.read(employeeProvider.notifier).load(query: query.trim());

    setState(() {
      _currentPage = 0;
    });
  }

  Future<void> _openCreateEmployee() async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (context) {
        return const CreateEmployee();
      },
    ));

    if (!mounted) {
      return;
    }

    if (result == true) {
      await ref.read(employeeProvider.notifier).load();

      if (!mounted) return;

      // Return to first page after adding an employee.
      setState(() {
        _currentPage = 0;
      });
    }
  }

  Future<void> _openEditEmployee(EmployeeResponse employee) async {
    final result = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (context) {
        return CreateEmployee(initialEmployee: employee);
      },
    ));

    if (!mounted) return;

    if (result == true) {
      await ref.read(employeeProvider.notifier).load();
    }
  }

  void _toggleEmployee(int employeeId, bool selected) {
    setState(() {
      if (selected) {
        _selectedEmployeeIds.add(employeeId);
      } else {
        _selectedEmployeeIds.remove(employeeId);
      }
    });
  }

  /// Selects or deselects only the employees visible
  /// on the current page.
  void _toggleCurrentPage(List<EmployeeResponse> pageEmployees) {
    final pageIds = pageEmployees.map((employee) => employee.id).toSet();

    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedEmployeeIds.contains);

    setState(() {
      if (allPageItemsSelected) {
        _selectedEmployeeIds.removeAll(pageIds);
      } else {
        _selectedEmployeeIds.addAll(pageIds);
      }
    });
  }

  Future<void> _deleteSelectedEmployees() async {
    if (_selectedEmployeeIds.isEmpty) return;

    final numberSelected = _selectedEmployeeIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(dialogContext.l10n.employeeManagementDeleteDialogTitle),
          content: Text(
            dialogContext.l10n.employeeManagementDeleteDialogMessage(
              numberSelected.toString(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.commonCancel.toUpperCase()),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                dialogContext.l10n.commonDelete.toUpperCase(),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final idsToDelete = _selectedEmployeeIds.toList();

    try {
      for (final employeeId in idsToDelete) {
        await ref.read(employeeProvider.notifier).delete(employeeId);
      }

      if (!mounted) return;

      final remainingEmployees = ref.read(employeeProvider).employees;

      final totalPages = remainingEmployees.isEmpty
          ? 1
          : (remainingEmployees.length / _pageSize).ceil();

      setState(() {
        _selectedEmployeeIds.clear();

        // Move backward when the last page becomes empty.
        if (_currentPage >= totalPages) {
          _currentPage = totalPages - 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.employeeManagementDeleteSuccess(
              idsToDelete.length.toString(),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.employeeManagementDeleteFailed(e.toString()),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeProvider);
    return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.employeeManagementTitle),
          elevation: 0.5,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.commonRefresh,
              onPressed: _refresh,
            ),
          ],
        ),
        body: SafeArea(child: Builder(builder: (context) {
          // Only take over the whole screen before the very first load
          // ever completes. Every later fetch (search, refresh, clearing
          // the search box) must update the existing card in place instead
          // of tearing the whole screen down for a bare spinner.
          if (!_hasLoadedOnce) {
            if (state.loading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state.error != null) {
              return _buildErrorState(state.error!);
            }
          }

          final isSearching = _searchCtl.text.trim().isNotEmpty;

          if (!state.loading && !isSearching && state.employees.isEmpty) {
            if (state.error != null) {
              return _buildErrorState(state.error!);
            }
            return _buildEmptyState();
          }

          return _buildEmployeeList(state.employees, loading: state.loading);
        })));
  }

  Widget _buildEmployeeList(
    List<EmployeeResponse> allEmployees, {
    required bool loading,
  }) {
    final totalItems = allEmployees.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());

    // Protect against an invalid page after data changes.
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);

    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);

    final pageEmployees = allEmployees.sublist(startIndex, endIndex);

    final pageIds = pageEmployees.map((employee) => employee.id).toSet();

    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedEmployeeIds.contains);

    final somePageItemsSelected = pageIds.any(_selectedEmployeeIds.contains);

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
                        onPressed: _openCreateEmployee,
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
                          context.l10n.employeeManagementAddEmployee,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Delete icon near ADD EMPLOYEE.
                      IconButton(
                        tooltip:
                            context.l10n.employeeManagementDeleteSelectedTooltip,
                        onPressed: _selectedEmployeeIds.isEmpty
                            ? null
                            : _deleteSelectedEmployees,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          foregroundColor: Colors.red,
                          disabledForegroundColor: Colors.grey.shade400,
                          side: BorderSide(
                            color: _selectedEmployeeIds.isEmpty
                                ? Colors.grey.shade300
                                : Colors.red,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),

                      if (_selectedEmployeeIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.employeeManagementSelectedCount(
                            _selectedEmployeeIds.length.toString(),
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ],

                      const Spacer(),

                      // Search box in the top-right corner of the card.
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText: context.l10n.employeeManagementSearchHint,
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
                              borderRadius: BorderRadius.circular(
                                PosTheme.radiusMedium,
                              ),
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
                          onChanged: (_) => _toggleCurrentPage(pageEmployees),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.employeeManagementEmployeesHeader,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.employeeManagementShowingCount(
                          pageEmployees.length.toString(),
                          totalItems.toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                if (pageEmployees.isEmpty)
                  _buildNoResultsRow(loading: loading)
                else
                  ...pageEmployees.map(_buildEmployeeRow),

                if (pageEmployees.isNotEmpty)
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
              context.l10n.employeeManagementNoEmployeesFound,
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

  Widget _buildEmployeeRow(EmployeeResponse employee) {
    final selected = _selectedEmployeeIds.contains(employee.id);

    final subtitleParts = [
      if (employee.position != null && employee.position!.isNotEmpty)
        employee.position!,
      if (employee.department != null && employee.department!.isNotEmpty)
        employee.department!,
    ];

    final subtitle = subtitleParts.isEmpty
        ? context.l10n.employeeManagementNoPositionSet
        : subtitleParts.join(' • ');

    final isActive = employee.status.toUpperCase() == 'ACTIVE';

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
                  onChanged: (value) =>
                      _toggleEmployee(employee.id, value ?? false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _openEditEmployee(employee),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFF99D267),
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                employee.fullName,
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
                  color: isActive
                      ? PosTheme.successGreen.withOpacity(0.12)
                      : PosTheme.errorRed.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  employee.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? PosTheme.successGreen
                        : PosTheme.errorRed,
                  ),
                ),
              ),
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
            context.l10n.employeeManagementRangeOfTotal(
              firstItem.toString(),
              lastItem.toString(),
              totalItems.toString(),
            ),
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(width: 20),
          IconButton(
            tooltip: context.l10n.employeeManagementFirstPage,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: context.l10n.employeeManagementPreviousPage,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(
              context.l10n.employeeManagementPageOf(
                (currentPage + 1).toString(),
                totalPages.toString(),
              ),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: context.l10n.employeeManagementNextPage,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: context.l10n.employeeManagementLastPage,
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
            constraints: const BoxConstraints(
              maxWidth: 650,
            ),
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
                        Icons.people,
                        size: 52,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.l10n.employeeManagementEmptyTitle,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.employeeManagementEmptyDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _openCreateEmployee,
                      style: ElevatedButton.styleFrom(
                        // backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(165, 54),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.l10n.employeeManagementAddEmployee,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}


