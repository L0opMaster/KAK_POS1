import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/role_models.dart';
import '../../pos/providers/role_provider.dart';

/// Mobile-friendly, read-only Permission browsing screen.
///
/// Ported functionality from `frontend-flutter-pos/lib/features/pos/
/// screens/permission_screen.dart`. Permission browsing is NOT a separate
/// feature in this app — desktop's screen just reads `roleProvider`'s
/// already-loaded `permissions` list (the full flat system permission
/// catalog, loaded alongside roles by the same `load()` call), and so does
/// this screen: no dedicated permission service/provider exists or is
/// needed. Same client-side name/description search as source; no tap
/// action (permissions are only ever edited from within a role, via
/// `MobileRoleManagementScreen`).
///
/// UI is a fresh mobile build (MOBILE UI REIMPLEMENT): desktop's paginated
/// `Card`+`DataTable`-like list becomes a single scrolling `ListView`
/// (no pagination needed on a phone), using `PosTheme`'s dark-mode-aware
/// `*Of(context)` tokens.
class MobilePermissionScreen extends ConsumerStatefulWidget {
  const MobilePermissionScreen({super.key});

  @override
  ConsumerState<MobilePermissionScreen> createState() =>
      _MobilePermissionScreenState();
}

class _MobilePermissionScreenState
    extends ConsumerState<MobilePermissionScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      // Reuse roleProvider's state — only trigger a load if nothing has
      // been loaded yet, matching source's "load alongside roles" design.
      if (ref.read(roleProvider).roles.isEmpty &&
          ref.read(roleProvider).permissions.isEmpty) {
        ref.read(roleProvider.notifier).load();
      }
    });
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
        .where((p) =>
            p.name.toLowerCase().contains(needle) ||
            (p.description ?? '').toLowerCase().contains(needle))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(roleProvider);
    final query = _searchCtl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.permissionScreenTitle),
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
                hintText: l10n.permissionScreenSearchHint,
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
              if (state.loading && state.permissions.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (state.error != null && state.permissions.isEmpty) {
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

              final visible = _filtered(state.permissions);

              if (visible.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user_outlined,
                          size: 48, color: PosTheme.textHintOf(context)),
                      const SizedBox(height: PosTheme.spacingMd),
                      Text(
                        query.isEmpty
                            ? l10n.permissionScreenEmpty
                            : l10n.permissionScreenNoMatch,
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
                    final permission = visible[i];
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
                        leading: Icon(Icons.verified_user_outlined,
                            color: PosTheme.primaryGreen),
                        title: Text(
                          permission.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: permission.description != null &&
                                permission.description!.isNotEmpty
                            ? Text(
                                permission.description!,
                                style: TextStyle(
                                  fontSize: PosTheme.fontSizeXs,
                                  color: PosTheme.textSecondaryOf(context),
                                ),
                              )
                            : null,
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
