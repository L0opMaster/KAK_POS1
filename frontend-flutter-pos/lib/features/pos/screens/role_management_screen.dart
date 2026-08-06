import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/features/pos/models/role_model.dart';
import 'package:frontend_flutter_pos/features/pos/providers/role_provider.dart';

import '../../../core/utils/l10n_extensions.dart';

class RoleManagementScreen extends ConsumerStatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  ConsumerState<RoleManagementScreen> createState() =>
      _RoleManagementScreenState();
}

class _RoleManagementScreenState extends ConsumerState<RoleManagementScreen> {
  static const int _pageSize = 6;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(roleProvider.notifier).load();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _search(String value) {
    setState(() => _currentPage = 0);
  }

  List<RoleModel> _filtered(List<RoleModel> roles) {
    final needle = _searchCtl.text.trim().toLowerCase();
    if (needle.isEmpty) return roles;
    return roles.where((r) => r.name.toLowerCase().contains(needle)).toList();
  }

  Future<void> _openPermissionEditor(RoleModel role) async {
    final allPermissions = ref.read(roleProvider).permissions;
    final selected = <String>{...role.permissions.map((p) => p.name)};
    final permissionSearchCtl = TextEditingController();
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              setDialogState(() {
                saving = true;
                error = null;
              });
              try {
                await ref
                    .read(roleProvider.notifier)
                    .updateRolePermissions(role.id, selected.toList());
                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  error = context.l10n.roleManagementScreenSaveFailed(
                    e.toString(),
                  );
                });
              }
            }

            final needle = permissionSearchCtl.text.trim().toLowerCase();
            final visiblePermissions = needle.isEmpty
                ? allPermissions
                : allPermissions
                    .where((p) => p.name.toLowerCase().contains(needle))
                    .toList();

            return AlertDialog(
              title: Text(
                context.l10n.roleManagementScreenPermissionsFor(role.name),
              ),
              content: SizedBox(
                width: 420,
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (error != null) ...[
                      Text(error!,
                          style: const TextStyle(color: PosTheme.errorRed)),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: permissionSearchCtl,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: context.l10n.permissionScreenSearchHint,
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(PosTheme.radiusMedium),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: visiblePermissions.isEmpty
                          ? Center(
                              child:
                                  Text(context.l10n.permissionScreenEmpty),
                            )
                          : ListView(
                              children: visiblePermissions.map((permission) {
                                final isChecked =
                                    selected.contains(permission.name);
                                return CheckboxListTile(
                                  value: isChecked,
                                  dense: true,
                                  title: Text(permission.name),
                                  subtitle: permission.description != null &&
                                          permission.description!.isNotEmpty
                                      ? Text(
                                          permission.description!,
                                          style: const TextStyle(fontSize: 12),
                                        )
                                      : null,
                                  onChanged: (checked) {
                                    setDialogState(() {
                                      if (checked == true) {
                                        selected.add(permission.name);
                                      } else {
                                        selected.remove(permission.name);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(context.l10n.commonSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.roleManagementScreenTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () => ref.read(roleProvider.notifier).load(),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(builder: (context) {
          if (!_hasLoadedOnce && state.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.roles.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.error!, textAlign: TextAlign.center),
              ),
            );
          }

          return _buildList(state.roles, loading: state.loading);
        }),
      ),
    );
  }

  Widget _buildList(List<RoleModel> allRoles, {required bool loading}) {
    final filtered = _filtered(allRoles);
    final totalItems = filtered.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageRoles = filtered.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () => ref.read(roleProvider.notifier).load(),
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
                  padding: const EdgeInsets.fromLTRB(30, 24, 30, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.roleManagementScreenTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText: context.l10n.roleManagementScreenSearchHint,
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.roleManagementScreenListHeader,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.paginationShowingOfTotal(
                          pageRoles.length.toString(),
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
                if (pageRoles.isEmpty)
                  _buildNoResults(loading: loading)
                else
                  ...pageRoles.map(_buildRoleRow),
                if (pageRoles.isNotEmpty)
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

  Widget _buildNoResults({required bool loading}) {
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
            Icon(Icons.accessibility_new, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchCtl.text.trim().isEmpty
                  ? context.l10n.roleManagementScreenEmpty
                  : context.l10n.roleManagementScreenNoMatch,
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

  Widget _buildRoleRow(RoleModel role) {
    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          leading: const CircleAvatar(
            radius: 22,
            backgroundColor: Color(0xFF99D267),
            child: Icon(Icons.accessibility_new, color: Colors.white),
          ),
          title: Text(
            role.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            context.l10n.roleManagementScreenPermissionsGranted(
              role.permissions.length.toString(),
            ),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openPermissionEditor(role),
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
              firstItem.toString(),
              lastItem.toString(),
              totalItems.toString(),
            ),
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
              context.l10n.paginationPageOf(
                (currentPage + 1).toString(),
                totalPages.toString(),
              ),
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
}
