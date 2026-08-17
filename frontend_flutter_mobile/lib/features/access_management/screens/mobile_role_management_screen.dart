import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/role_models.dart';
import '../../pos/providers/role_provider.dart';

/// Mobile-friendly Role Management screen.
///
/// Ported functionality from `frontend-flutter-pos/lib/features/pos/
/// screens/role_management_screen.dart` — role assignment only: this app
/// has a FIXED set of pre-existing roles, there is no create/rename/delete
/// role anywhere (source has no such endpoint either). Same client-side
/// name search, same "{N} permission(s) granted" subtitle, same
/// tap-row-to-edit-permissions flow.
///
/// UI is a fresh mobile build (MOBILE UI REIMPLEMENT): desktop's paginated
/// `Card`+`DataTable`-like list becomes a single scrolling `ListView` with
/// touch-sized rows, using `PosTheme`'s dark-mode-aware `*Of(context)`
/// tokens — mirrors `mobile_category_management_screen.dart`'s pattern
/// since role management is also a flat, no-delete admin list. Desktop's
/// fixed-size `AlertDialog` permission editor becomes its own full-screen
/// route (`_RolePermissionEditorScreen` below) rather than a modal, so a
/// long permission list never overflows a phone screen.
class MobileRoleManagementScreen extends ConsumerStatefulWidget {
  const MobileRoleManagementScreen({super.key});

  @override
  ConsumerState<MobileRoleManagementScreen> createState() =>
      _MobileRoleManagementScreenState();
}

class _MobileRoleManagementScreenState
    extends ConsumerState<MobileRoleManagementScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(roleProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<RoleModel> _filtered(List<RoleModel> roles) {
    final needle = _searchCtl.text.trim().toLowerCase();
    if (needle.isEmpty) return roles;
    return roles.where((r) => r.name.toLowerCase().contains(needle)).toList();
  }

  Future<void> _openPermissionEditor(RoleModel role) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _RolePermissionEditorScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(roleProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.roleManagementScreenTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(roleProvider.notifier).load(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.roleManagementScreenSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(builder: (context) {
              if (state.loading && state.roles.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.error != null && state.roles.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(PosTheme.spacingLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            color: PosTheme.errorRed, size: 40),
                        const SizedBox(height: PosTheme.spacingMd),
                        Text(state.error!, textAlign: TextAlign.center),
                        const SizedBox(height: PosTheme.spacingMd),
                        OutlinedButton.icon(
                          onPressed: () =>
                              ref.read(roleProvider.notifier).load(),
                          icon: const Icon(Icons.refresh),
                          label: Text(l10n.commonRetry),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final visible = _filtered(state.roles);

              if (visible.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 48, color: PosTheme.textHintOf(context)),
                      const SizedBox(height: PosTheme.spacingMd),
                      Text(
                        query.isEmpty
                            ? l10n.roleManagementScreenEmpty
                            : l10n.roleManagementScreenNoMatch,
                        style: TextStyle(
                          color: PosTheme.textSecondaryOf(context),
                          fontSize: PosTheme.fontSizeMd,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(roleProvider.notifier).load(),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: PosTheme.spacingMd,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final role = visible[i];
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          PosTheme.radiusMedium,
                        ),
                        side: BorderSide(color: PosTheme.borderColorOf(context)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: PosTheme.primaryGreen,
                          child: const Icon(Icons.admin_panel_settings,
                              color: Colors.white),
                        ),
                        title: Text(
                          role.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          l10n.roleManagementScreenPermissionsGranted(
                            role.permissions.length.toString(),
                          ),
                          style: TextStyle(
                            fontSize: PosTheme.fontSizeXs,
                            color: PosTheme.textSecondaryOf(context),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openPermissionEditor(role),
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Full-screen permission editor for a single role — the mobile analogue
/// of desktop's fixed-size `AlertDialog`. Loads the full flat permission
/// catalog from `roleProvider`'s already-loaded state, pre-checks the
/// role's current permissions, offers its own local search box (separate
/// from the outer role-list search), and saves by replacing the role's
/// entire permission set in one call — never a per-permission diff.
class _RolePermissionEditorScreen extends ConsumerStatefulWidget {
  const _RolePermissionEditorScreen({required this.role});

  final RoleModel role;

  @override
  ConsumerState<_RolePermissionEditorScreen> createState() =>
      _RolePermissionEditorScreenState();
}

class _RolePermissionEditorScreenState
    extends ConsumerState<_RolePermissionEditorScreen> {
  late final Set<String> _selected;
  final TextEditingController _searchCtl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.role.permissions.map((p) => p.name)};
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<PermissionModel> _filtered(List<PermissionModel> permissions) {
    final needle = _searchCtl.text.trim().toLowerCase();
    if (needle.isEmpty) return permissions;
    return permissions
        .where((p) => p.name.toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(roleProvider.notifier)
          .updateRolePermissions(widget.role.id, _selected.toList());
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.roleManagementScreenSaveFailed(e.toString());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allPermissions = ref.watch(roleProvider).permissions;
    final visible = _filtered(allPermissions);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.roleManagementScreenPermissionsFor(widget.role.name),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    l10n.commonSave,
                    style: const TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                color: PosTheme.errorRed.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(PosTheme.spacingMd),
                child: Text(
                  _error!,
                  style: const TextStyle(color: PosTheme.errorRed),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              child: TextField(
                controller: _searchCtl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.permissionScreenSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                  ),
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        l10n.permissionScreenEmpty,
                        style: TextStyle(
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PosTheme.spacingMd,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final permission = visible[i];
                        final isChecked = _selected.contains(permission.name);
                        return CheckboxListTile(
                          value: isChecked,
                          title: Text(permission.name),
                          subtitle: permission.description != null &&
                                  permission.description!.isNotEmpty
                              ? Text(permission.description!)
                              : null,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selected.add(permission.name);
                              } else {
                                _selected.remove(permission.name);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
