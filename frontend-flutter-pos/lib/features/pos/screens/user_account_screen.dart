import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/core/config/pos_theme.dart';
import 'package:frontend_flutter_pos/features/pos/models/user_account_model.dart';
import 'package:frontend_flutter_pos/features/pos/providers/role_provider.dart';
import 'package:frontend_flutter_pos/features/pos/providers/user_account_provider.dart';

import '../../../core/utils/l10n_extensions.dart';

class UserAccountScreen extends ConsumerStatefulWidget {
  const UserAccountScreen({super.key});

  @override
  ConsumerState<UserAccountScreen> createState() => _UserAccountScreenState();
}

class _UserAccountScreenState extends ConsumerState<UserAccountScreen> {
  static const int _pageSize = 6;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(userAccountProvider.notifier).load();
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

  Future<void> _openCreateUserDialog() async {
    final roles = ref.read(roleProvider).roles;
    final fullNameCtl = TextEditingController();
    final emailCtl = TextEditingController();
    final passwordCtl = TextEditingController();
    String? selectedRole = roles.isNotEmpty ? roles.first.name : null;
    bool saving = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (fullNameCtl.text.trim().isEmpty ||
                  emailCtl.text.trim().isEmpty ||
                  passwordCtl.text.trim().isEmpty ||
                  selectedRole == null) {
                setDialogState(
                    () => error = context.l10n.userAccountAllFieldsRequired);
                return;
              }

              setDialogState(() {
                saving = true;
                error = null;
              });

              try {
                await ref.read(userAccountProvider.notifier).create(
                      UserAccountCreateRequest(
                        email: emailCtl.text.trim(),
                        fullName: fullNameCtl.text.trim(),
                        password: passwordCtl.text.trim(),
                        roles: [selectedRole!],
                      ),
                    );
                if (context.mounted) Navigator.of(dialogContext).pop();
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  error = context.l10n.userAccountCreateFailed('$e');
                });
              }
            }

            return AlertDialog(
              title: Text(context.l10n.userAccountAddTitle),
              content: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: fullNameCtl,
                        decoration: InputDecoration(
                          labelText: context.l10n.userAccountFullNameLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtl,
                        decoration: InputDecoration(
                          labelText: context.l10n.userAccountEmailLabel,
                          border: const OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordCtl,
                        decoration: InputDecoration(
                          labelText: context.l10n.userAccountPasswordLabel,
                          border: const OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: InputDecoration(
                          labelText: context.l10n.userAccountRoleLabel,
                          border: const OutlineInputBorder(),
                        ),
                        items: roles
                            .map((r) => DropdownMenuItem(
                                  value: r.name,
                                  child: Text(r.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => selectedRole = value);
                        },
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!,
                            style: const TextStyle(color: PosTheme.errorRed)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: Text(context.l10n.commonCancel.toUpperCase()),
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
                      : Text(context.l10n.userAccountCreateButton.toUpperCase()),
                ),
              ],
            );
          },
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userAccountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.userAccountScreenTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () => ref.read(userAccountProvider.notifier).load(),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(builder: (context) {
          if (!_hasLoadedOnce && state.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.error != null && state.users.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(state.error!, textAlign: TextAlign.center),
              ),
            );
          }

          return _buildList(state.users, loading: state.loading);
        }),
      ),
    );
  }

  Widget _buildList(List<UserAccountResponse> allUsers, {required bool loading}) {
    final filtered = _filtered(allUsers);
    final totalItems = filtered.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageUsers = filtered.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () => ref.read(userAccountProvider.notifier).load(),
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
                        onPressed: _openCreateUserDialog,
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
                          context.l10n.userAccountAddButton.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: _search,
                          decoration: InputDecoration(
                            hintText: context.l10n.userAccountSearchHint,
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
                          context.l10n.userAccountScreenTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        context.l10n.paginationShowingOfTotal(
                            '${pageUsers.length}', '$totalItems'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageUsers.isEmpty)
                  _buildNoResults(loading: loading)
                else
                  ...pageUsers.map(_buildUserRow),
                if (pageUsers.isNotEmpty)
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
            Icon(Icons.account_box, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchCtl.text.trim().isEmpty
                  ? context.l10n.userAccountEmptyMessage
                  : context.l10n.userAccountNoResultsMessage,
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

  Widget _buildUserRow(UserAccountResponse user) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFF99D267),
                child: Icon(Icons.person, color: Colors.white),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: user.roles
                          .map((r) => Chip(
                                label: Text(
                                  r,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: PosTheme.primaryGreen
                                    .withValues(alpha: 0.12),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              Switch(
                value: user.active,
                activeThumbColor: PosTheme.primaryGreen,
                onChanged: (value) => _toggleActive(user, value),
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
}
