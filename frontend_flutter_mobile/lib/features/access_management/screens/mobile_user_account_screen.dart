import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/user_account_model.dart';
import '../../pos/providers/role_provider.dart';
import '../../pos/providers/user_account_provider.dart';

/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// user_account_screen.dart` — same functionality: client-side
/// search/filter (name/email/role substring match), a list of accounts
/// with an active/inactive `Switch` that calls `setStatus(id, !active)`
/// immediately (no confirmation dialog), and a create flow with 4 required
/// fields (full name, email, password, single-select role). There is no
/// edit or delete anywhere in this feature — matches source exactly.
///
/// Desktop's paginated `DataTable`-in-`AlertDialog` layout is dropped
/// (MOBILE UI REIMPLEMENT): the list becomes a plain scrolling
/// `Card`+`ListTile` list (following `mobile_suppliers_screen.dart`'s
/// pattern) and the create dialog becomes a scrollable modal bottom sheet
/// sized to avoid overflow on a phone, with the keyboard inset handled via
/// `MediaQuery.viewInsets`.
class MobileUserAccountScreen extends ConsumerStatefulWidget {
  const MobileUserAccountScreen({super.key});

  @override
  ConsumerState<MobileUserAccountScreen> createState() =>
      _MobileUserAccountScreenState();
}

class _MobileUserAccountScreenState
    extends ConsumerState<MobileUserAccountScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(userAccountProvider.notifier).load();
      await ref.read(roleProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<UserAccountResponse> _filtered(List<UserAccountResponse> users) {
    final needle = _searchCtl.text.trim().toLowerCase();
    if (needle.isEmpty) return users;
    return users
        .where((u) =>
            u.fullName.toLowerCase().contains(needle) ||
            u.email.toLowerCase().contains(needle) ||
            u.roles.any((r) => r.toLowerCase().contains(needle)))
        .toList();
  }

  Future<void> _toggleActive(UserAccountResponse user, bool active) async {
    try {
      await ref.read(userAccountProvider.notifier).setStatus(user.id, active);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.userAccountUpdateStatusFailed('$e')),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PosTheme.backgroundCardOf(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosTheme.radiusLarge)),
      ),
      builder: (_) => const _CreateUserSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(userAccountProvider);
    final query = _searchCtl.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userAccountScreenTitle),
        actions: [
          IconButton(
            tooltip: l10n.commonRefresh,
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(userAccountProvider.notifier).load(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        tooltip: l10n.userAccountAddButton,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.userAccountSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searchCtl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchCtl.clear()),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          Expanded(
            child: Builder(builder: (context) {
              if (state.loading && state.users.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.error != null && state.users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(PosTheme.spacingXl),
                    child: Text(state.error!, textAlign: TextAlign.center),
                  ),
                );
              }

              final visible = _filtered(state.users);
              if (visible.isEmpty) {
                return Center(
                  child: Text(
                    query.isEmpty
                        ? l10n.userAccountEmptyMessage
                        : l10n.userAccountNoResultsMessage,
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () => ref.read(userAccountProvider.notifier).load(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    PosTheme.spacingMd,
                    0,
                    PosTheme.spacingMd,
                    PosTheme.spacingXxl,
                  ),
                  itemCount: visible.length,
                  itemBuilder: (context, i) => _UserCard(
                    user: visible[i],
                    onToggle: (active) => _toggleActive(visible[i], active),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onToggle});

  final UserAccountResponse user;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: PosTheme.primaryGreen,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: PosTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: TextStyle(
                      fontSize: PosTheme.fontSizeMd,
                      fontWeight: FontWeight.bold,
                      color: PosTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.email,
                    style: TextStyle(
                      fontSize: PosTheme.fontSizeSm,
                      color: PosTheme.textSecondaryOf(context),
                    ),
                  ),
                  if (user.roles.isNotEmpty) ...[
                    const SizedBox(height: PosTheme.spacingSm),
                    Wrap(
                      spacing: PosTheme.spacingXs,
                      runSpacing: PosTheme.spacingXs,
                      children: user.roles
                          .map((r) => Chip(
                                label: Text(r, style: const TextStyle(fontSize: PosTheme.fontSizeXs)),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: PosTheme.primaryGreen.withValues(alpha: 0.12),
                              ))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              value: user.active,
              activeThumbColor: PosTheme.primaryGreen,
              onChanged: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

/// Create-account modal bottom sheet. All 4 fields are required (full
/// name, email, password, role); default selected role is the first
/// loaded role, or none if roles haven't loaded yet. On success the sheet
/// closes and the caller's list refresh already happened as part of
/// `UserAccountNotifier.create()`. On failure the error is shown inline
/// and the sheet stays open, matching source.
class _CreateUserSheet extends ConsumerStatefulWidget {
  const _CreateUserSheet();

  @override
  ConsumerState<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends ConsumerState<_CreateUserSheet> {
  final _fullNameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  String? _selectedRole;
  bool _saving = false;
  String? _error;
  bool _roleInitialized = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_fullNameCtl.text.trim().isEmpty ||
        _emailCtl.text.trim().isEmpty ||
        _passwordCtl.text.trim().isEmpty ||
        _selectedRole == null) {
      setState(() => _error = l10n.userAccountAllFieldsRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(userAccountProvider.notifier).create(
            UserAccountCreateRequest(
              email: _emailCtl.text.trim(),
              fullName: _fullNameCtl.text.trim(),
              password: _passwordCtl.text.trim(),
              roles: [_selectedRole!],
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.l10n.userAccountCreateFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final roleState = ref.watch(roleProvider);
    final roles = roleState.roles;

    if (!_roleInitialized && roles.isNotEmpty) {
      _selectedRole = roles.first.name;
      _roleInitialized = true;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            PosTheme.spacingLg,
            PosTheme.spacingLg,
            PosTheme.spacingLg,
            PosTheme.spacingXl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: PosTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: PosTheme.dividerColorOf(context),
                    borderRadius: BorderRadius.circular(PosTheme.radiusPill),
                  ),
                ),
              ),
              Text(
                l10n.userAccountAddTitle,
                style: TextStyle(
                  fontSize: PosTheme.fontSizeLg,
                  fontWeight: FontWeight.bold,
                  color: PosTheme.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: PosTheme.spacingLg),
              TextField(
                controller: _fullNameCtl,
                decoration: InputDecoration(
                  labelText: l10n.userAccountFullNameLabel,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: PosTheme.spacingMd),
              TextField(
                controller: _emailCtl,
                decoration: InputDecoration(
                  labelText: l10n.userAccountEmailLabel,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: PosTheme.spacingMd),
              TextField(
                controller: _passwordCtl,
                decoration: InputDecoration(
                  labelText: l10n.userAccountPasswordLabel,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: PosTheme.spacingMd),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: InputDecoration(
                  labelText: l10n.userAccountRoleLabel,
                  border: const OutlineInputBorder(),
                ),
                items: roles
                    .map((r) => DropdownMenuItem(value: r.name, child: Text(r.name)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedRole = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: PosTheme.spacingMd),
                Text(_error!, style: const TextStyle(color: PosTheme.errorRed)),
              ],
              const SizedBox(height: PosTheme.spacingLg),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(l10n.userAccountCreateButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
