import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/customer_models.dart';
import '../../pos/providers/customer_provider.dart';
import 'mobile_create_customer_screen.dart';
import 'mobile_customer_detail_screen.dart';

/// Admin customer-management screen — create/edit/delete customers and see
/// their credit balances. Distinct from `customer_picker_screen.dart` (the
/// screen used mid-sale to attach a customer to the cart): that screen only
/// ever calls `customerProvider.notifier.load()`, which this screen shares,
/// but neither screen calls into the other and this screen owns its own
/// `Scaffold`/`AppBar` (it's pushed as a route, not a permanent tab body).
///
/// Mirrors `mobile_table_management_screen.dart`'s established admin-list
/// pattern: AppBar title toggles to "N selected" during multi-select, FAB
/// opens the create form, checkbox multi-select + bulk delete behind an
/// `AlertDialog` confirm (sequential per-id delete, matching desktop's
/// `CustomerManagementScreen`). Desktop's paged `DataTable` becomes a plain
/// scrolling list (mobile UI reimplement) with server-side search, same as
/// the picker screen.
///
/// Tapping a row opens `MobileCustomerDetailScreen` (purchase history,
/// credit ledger, record-payment flow). Editing is also reachable directly
/// via a trailing pencil icon on each row, without a detail-screen detour.
class MobileCustomerManagementScreen extends ConsumerStatefulWidget {
  const MobileCustomerManagementScreen({super.key});

  @override
  ConsumerState<MobileCustomerManagementScreen> createState() =>
      _MobileCustomerManagementScreenState();
}

class _MobileCustomerManagementScreenState
    extends ConsumerState<MobileCustomerManagementScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final Set<int> _selected = {};
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(customerProvider.notifier).load());
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref
        .read(customerProvider.notifier)
        .load(query: _searchCtl.text.trim());
  }

  void _onSearchChanged(String value) {
    setState(() {}); // refresh the clear-icon/empty-state copy immediately
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(customerProvider.notifier).load(query: value.trim());
    });
  }

  Future<void> _openDetail(Customer customer) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCustomerDetailScreen(customerId: customer.id),
      ),
    );
    if (result == true) _refresh();
  }

  Future<void> _openCreate() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileCreateCustomerScreen()),
    );
  }

  Future<void> _openEdit(Customer customer) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MobileCreateCustomerScreen(initialCustomer: customer),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final l10n = context.l10n;
    final count = _selected.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.customerManagementDeleteTitle),
        content: Text(
          '${l10n.customerManagementDeleteConfirmPrefix} $count '
          '${l10n.customerManagementDeleteConfirmSuffix}',
        ),
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
        await ref.read(customerProvider.notifier).delete(id);
      }
      setState(() => _selected.clear());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ids.length} ${l10n.customerManagementDeletedSuffix}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.customerManagementDeleteFailedPrefix}: $e'),
          backgroundColor: PosTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(customerProvider);
    final cur = watchCurrency(ref);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selected.isEmpty
                ? l10n.navCustomers
                : '${_selected.length} ${l10n.customerManagementSelectedSuffix}',
          ),
          actions: [
            if (_selected.isNotEmpty)
              IconButton(
                tooltip: l10n.customerManagementDeleteSelectedTooltip,
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
          tooltip: l10n.customerManagementAddButton,
          child: const Icon(Icons.add),
        ),
        body: SafeArea(
          child: Column(
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
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: l10n.customerManagementSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        PosTheme.radiusMedium,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildBody(state, cur)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CustomerState state, String currencyCode) {
    final l10n = context.l10n;
    final isSearching = _searchCtl.text.trim().isNotEmpty;

    if (state.error != null && state.customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PosTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: PosTheme.errorRed),
              const SizedBox(height: PosTheme.spacingSm),
              Text(
                '${l10n.commonError}: ${state.error}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PosTheme.spacingMd),
              FilledButton(
                onPressed: _refresh,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.loading && state.customers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.customers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(PosTheme.spacingLg),
          child: Text(
            isSearching
                ? l10n.customerManagementNoResultsTitle
                : l10n.customerManagementEmptyDescription,
            textAlign: TextAlign.center,
            style: TextStyle(color: PosTheme.textSecondaryOf(context)),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(PosTheme.spacingMd),
        itemCount: state.customers.length,
        itemBuilder: (context, i) =>
            _buildCustomerRow(state.customers[i], currencyCode),
      ),
    );
  }

  Widget _buildCustomerRow(Customer c, String currencyCode) {
    final l10n = context.l10n;
    final selected = _selected.contains(c.id);
    final hasCredit = c.creditBalance > 0;
    final isOverdue = c.overdue;

    final subtitleParts = [
      if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
      if (c.email != null && c.email!.isNotEmpty) c.email!,
    ];
    final subtitle = subtitleParts.isEmpty
        ? l10n.customerManagementNoContactInfo
        : subtitleParts.join(' • ');

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
        onTap: () => _openDetail(c),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selected,
              onChanged: (v) => setState(() {
                if (v == true) {
                  _selected.add(c.id);
                } else {
                  _selected.remove(c.id);
                }
              }),
            ),
            CircleAvatar(
              backgroundColor:
                  isOverdue ? PosTheme.errorRed : PosTheme.primaryGreen,
              child: Icon(
                isOverdue ? Icons.warning_amber : Icons.person,
                color: Colors.white,
              ),
            ),
          ],
        ),
        title: Text(
          c.resolvedDisplayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: PosTheme.fontSizeXs,
            color: PosTheme.textSecondaryOf(context),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasCredit) ...[
              _CreditBalancePill(
                label: formatAmount(c.creditBalance, currencyCode),
                overdue: isOverdue,
              ),
              const SizedBox(width: PosTheme.spacingXs),
            ],
            IconButton(
              tooltip: l10n.commonEdit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _openEdit(c),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreditBalancePill extends StatelessWidget {
  const _CreditBalancePill({required this.label, required this.overdue});

  final String label;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final color = overdue ? PosTheme.errorRed : PosTheme.warningAmber;
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
