import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/employee_model.dart';
import '../../pos/providers/employee_provider.dart';
import 'mobile_create_employee_screen.dart';

/// Admin employee-management screen — create/edit/delete employee HR
/// records. Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// employee_management_screen.dart`: server-side search (`q` query param,
/// unlike Category/Table/Modifier's client-side filtering), checkbox
/// multi-select + bulk delete (sequential per-id, no bulk endpoint — matches
/// source), FAB opens the create form, tapping a row opens edit. Desktop's
/// numbered pagination footer becomes a plain scrolling list (mobile UI
/// reimplement), matching this app's established admin-list convention
/// (`mobile_item_management_screen.dart`/`mobile_table_management_screen.dart`).
class MobileEmployeeManagementScreen extends ConsumerStatefulWidget {
  const MobileEmployeeManagementScreen({super.key});

  @override
  ConsumerState<MobileEmployeeManagementScreen> createState() =>
      _MobileEmployeeManagementScreenState();
}

class _MobileEmployeeManagementScreenState
    extends ConsumerState<MobileEmployeeManagementScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(employeeProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    await ref.read(employeeProvider.notifier).load(query: query.trim());
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileCreateEmployeeScreen()),
    );
    if (created == true) _search(_searchCtl.text);
  }

  Future<void> _openEdit(EmployeeResponse employee) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCreateEmployeeScreen(initialEmployee: employee),
      ),
    );
    if (updated == true) _search(_searchCtl.text);
  }

  Future<void> _deleteSelected() async {
    final l10n = context.l10n;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.employeeManagementDeleteDialogTitle),
        content: Text(l10n.employeeManagementDeleteDialogMessage('$count')),
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
      final notifier = ref.read(employeeProvider.notifier);
      for (final id in ids) {
        await notifier.delete(id);
      }
      setState(() => _selected.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.employeeManagementDeleteSuccess('${ids.length}'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.employeeManagementDeleteFailed('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(employeeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty
              ? l10n.employeeManagementTitle
              : l10n.employeeManagementSelectedCount('${_selected.length}'),
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: l10n.employeeManagementDeleteSelectedTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
            )
          else
            IconButton(
              tooltip: l10n.commonRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: () => _search(_searchCtl.text),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.employeeManagementAddEmployee,
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
              onSubmitted: _search,
              onChanged: (v) {
                if (v.isEmpty) _search('');
              },
              decoration: InputDecoration(
                hintText: l10n.employeeManagementSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          if (state.loading && state.employees.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null && state.employees.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(PosTheme.spacingLg),
                  child: Text('${l10n.commonError}: ${state.error}',
                      textAlign: TextAlign.center),
                ),
              ),
            )
          else if (state.employees.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  l10n.employeeManagementNoEmployeesFound,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _search(_searchCtl.text),
                child: ListView.builder(
                  padding: const EdgeInsets.all(PosTheme.spacingMd),
                  itemCount: state.employees.length,
                  itemBuilder: (context, i) {
                    final employee = state.employees[i];
                    final selected = _selected.contains(employee.id);
                    final subtitleParts = [
                      if (employee.position?.isNotEmpty == true) employee.position!,
                      if (employee.department?.isNotEmpty == true) employee.department!,
                    ];
                    final isActive = employee.status.toUpperCase() == 'ACTIVE';

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                        side: BorderSide(
                          color: selected
                              ? PosTheme.primaryGreen
                              : PosTheme.borderColorOf(context),
                        ),
                      ),
                      child: ListTile(
                        onTap: () => _openEdit(employee),
                        leading: Checkbox(
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(employee.id);
                            } else {
                              _selected.remove(employee.id);
                            }
                          }),
                        ),
                        title: Text(
                          employee.fullName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          subtitleParts.isEmpty
                              ? l10n.employeeManagementNoPositionSet
                              : subtitleParts.join(' • '),
                          style: TextStyle(
                            fontSize: PosTheme.fontSizeXs,
                            color: PosTheme.textSecondaryOf(context),
                          ),
                        ),
                        trailing: _StatusPill(
                          label: employee.status,
                          color: isActive ? PosTheme.successGreen : PosTheme.errorRed,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
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
