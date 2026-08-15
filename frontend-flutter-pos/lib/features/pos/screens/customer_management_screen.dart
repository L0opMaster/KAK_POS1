import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/customer_models.dart';
import '../providers/customer_provider.dart';
import '../services/customer_service.dart';

/// Full customer management screen — follows the same list UI as
/// Employees: inline ADD button, checkbox multi-select + bulk delete,
/// search box, and client-side pagination.
///
/// Features:
/// - List/search customers with credit balance indicators
/// - Create / Edit / Delete customers
/// - Tap customer to view detail screen with purchase history & credit ledger
/// - Add customer to current POS sale (via callback)
class CustomerManagementScreen extends ConsumerStatefulWidget {
  /// Optional callback when a customer is selected for the POS sale.
  final void Function(Customer)? onCustomerSelected;

  const CustomerManagementScreen({super.key, this.onCustomerSelected});

  @override
  ConsumerState<CustomerManagementScreen> createState() =>
      _CustomerManagementScreenState();
}

class _CustomerManagementScreenState
    extends ConsumerState<CustomerManagementScreen> {
  static const int _pageSize = 6;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;

  // Selected customer IDs remain selected when changing pages.
  final Set<int> _selectedCustomerIds = {};

  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(customerProvider.notifier).load();
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
        .read(customerProvider.notifier)
        .load(query: _searchCtl.text.trim());
  }

  void _search(String query) {
    ref.read(customerProvider.notifier).load(query: query.trim());
    setState(() => _currentPage = 0);
  }

  Future<void> _openCreateCustomer() async {
    final result = await _showCustomerForm(context);
    if (result == true && mounted) setState(() => _currentPage = 0);
  }

  void _toggleCustomer(int customerId, bool selected) {
    setState(() {
      if (selected) {
        _selectedCustomerIds.add(customerId);
      } else {
        _selectedCustomerIds.remove(customerId);
      }
    });
  }

  void _toggleCurrentPage(List<Customer> pageCustomers) {
    final pageIds = pageCustomers.map((c) => c.id).toSet();
    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedCustomerIds.contains);

    setState(() {
      if (allPageItemsSelected) {
        _selectedCustomerIds.removeAll(pageIds);
      } else {
        _selectedCustomerIds.addAll(pageIds);
      }
    });
  }

  Future<void> _deleteSelectedCustomers() async {
    if (_selectedCustomerIds.isEmpty) return;

    final numberSelected = _selectedCustomerIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.customerManagementDeleteTitle),
          content: Text(
            '${context.l10n.customerManagementDeleteConfirmPrefix} '
            '$numberSelected ${context.l10n.customerManagementDeleteConfirmSuffix}',
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

    final idsToDelete = _selectedCustomerIds.toList();
    final service = ref.read(customerServiceProvider);

    try {
      for (final customerId in idsToDelete) {
        await service.deleteCustomer(customerId);
      }

      await _refresh();

      if (!mounted) return;

      final remaining = ref.read(customerProvider).customers;
      final totalPages =
          remaining.isEmpty ? 1 : (remaining.length / _pageSize).ceil();

      setState(() {
        _selectedCustomerIds.clear();
        if (_currentPage >= totalPages) {
          _currentPage = totalPages - 1;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${idsToDelete.length} ${context.l10n.customerManagementDeletedSuffix}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${context.l10n.customerManagementDeleteFailedPrefix}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.navCustomers),
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
          if (!_hasLoadedOnce) {
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return _buildErrorState(state.error!);
            }
          }

          final isSearching = _searchCtl.text.trim().isNotEmpty;

          if (!state.loading && !isSearching && state.customers.isEmpty) {
            if (state.error != null) {
              return _buildErrorState(state.error!);
            }
            return _buildEmptyState();
          }

          return _buildCustomerList(state.customers, loading: state.loading);
        })),
      ),
    );
  }

  Widget _buildCustomerList(
    List<Customer> allCustomers, {
    required bool loading,
  }) {
    final totalItems = allCustomers.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);

    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageCustomers = allCustomers.sublist(startIndex, endIndex);

    final pageIds = pageCustomers.map((c) => c.id).toSet();
    final allPageItemsSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedCustomerIds.contains);
    final somePageItemsSelected = pageIds.any(_selectedCustomerIds.contains);

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
                        onPressed: _openCreateCustomer,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(180, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.customerManagementAddButton,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: context
                            .l10n.customerManagementDeleteSelectedTooltip,
                        onPressed: _selectedCustomerIds.isEmpty
                            ? null
                            : _deleteSelectedCustomers,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          foregroundColor: Colors.red,
                          disabledForegroundColor: Colors.grey.shade400,
                          side: BorderSide(
                            color: _selectedCustomerIds.isEmpty
                                ? Colors.grey.shade300
                                : Colors.red,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      if (_selectedCustomerIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${_selectedCustomerIds.length} ${context.l10n.customerManagementSelectedSuffix}',
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
                            hintText: context.l10n.customerManagementSearchHint,
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
                          onChanged: (_) => _toggleCurrentPage(pageCustomers),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.navCustomers,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                      Text(
                        '${context.l10n.customerManagementShowingPrefix} ${pageCustomers.length} ${context.l10n.customerManagementOfLabel} $totalItems',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageCustomers.isEmpty)
                  _buildNoResultsRow(loading: loading)
                else
                  ...pageCustomers.map(_buildCustomerRow),
                if (pageCustomers.isNotEmpty)
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
              context.l10n.customerManagementNoResultsTitle,
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

  Widget _buildCustomerRow(Customer customer) {
    final c = customer;
    final selected = _selectedCustomerIds.contains(c.id);
    final hasCredit = c.creditBalance > 0;
    final isOverdue = c.overdue;
    final lang = ref.watch(appLanguageProvider);

    final subtitleParts = [
      if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
      if (c.email != null && c.email!.isNotEmpty) c.email!,
    ];
    final subtitle = subtitleParts.isEmpty
        ? context.l10n.customerManagementNoContactInfo
        : subtitleParts.join(' • ');

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
                  onChanged: (value) => _toggleCustomer(c.id, value ?? false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _openCustomerDetail(c),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: isOverdue
                              ? PosTheme.errorRed
                              : const Color(0xFF99D267),
                          child: Icon(
                            isOverdue ? Icons.warning_amber : Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.localizedName(lang),
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
              if (hasCredit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? PosTheme.errorRed.withValues(alpha: 0.12)
                        : PosTheme.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '\$${c.creditBalance.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isOverdue ? PosTheme.errorRed : PosTheme.warningAmber,
                    ),
                  ),
                ),
              if (widget.onCustomerSelected != null) ...[
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    widget.onCustomerSelected!(c);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    backgroundColor: PosTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
                    ),
                  ),
                  child: Text(context.l10n.commonSelect),
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
            '$firstItem–$lastItem ${context.l10n.customerManagementOfLabel} $totalItems',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(width: 20),
          IconButton(
            tooltip: context.l10n.customerManagementFirstPageTooltip,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: context.l10n.customerManagementPreviousPageTooltip,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(
              '${context.l10n.customerManagementPagePrefix} ${currentPage + 1} ${context.l10n.customerManagementOfLabel} $totalPages',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          IconButton(
            tooltip: context.l10n.customerManagementNextPageTooltip,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: context.l10n.customerManagementLastPageTooltip,
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
                        Icons.people_outline,
                        size: 52,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      context.l10n.navCustomers,
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.customerManagementEmptyDescription,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _openCreateCustomer,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(180, 54),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(
                        context.l10n.customerManagementAddButton,
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

  void _openCustomerDetail(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CustomerDetailScreen(customerId: customer.id),
      ),
    );
  }

  Future<bool?> _showCustomerForm(
    BuildContext context, {
    Customer? customer,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer),
      ),
    );
    if (result == true) await _refresh();
    return result;
  }
}

/// Full-screen customer form (create / edit).
class CustomerFormScreen extends ConsumerStatefulWidget {
  final Customer? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _addressCtl;
  late final TextEditingController _creditCtl;
  late final TextEditingController _notesCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameCtl = TextEditingController(
        text: c?.displayName.isNotEmpty == true
            ? c!.displayName
            : c?.nameEn ?? '');
    _phoneCtl = TextEditingController(text: c?.phone ?? '');
    _emailCtl = TextEditingController(text: c?.email ?? '');
    _addressCtl = TextEditingController(text: c?.address ?? '');
    _creditCtl = TextEditingController(
        text: c != null ? c.creditLimit.toStringAsFixed(2) : '0');
    _notesCtl = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _addressCtl.dispose();
    _creditCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final payload = CreateCustomerRequest(
        nameEn: _nameCtl.text.trim(),
        displayName: _nameCtl.text.trim(),
        phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
        email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
        address:
            _addressCtl.text.trim().isEmpty ? null : _addressCtl.text.trim(),
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
        type: 'WALK_IN',
        status: 'ACTIVE',
        creditLimit: double.tryParse(_creditCtl.text.trim()) ?? 0,
      );
      if (widget.customer == null) {
        await ref.read(customerProvider.notifier).create(payload);
      } else {
        await ref
            .read(customerProvider.notifier)
            .update(widget.customer!.id, payload);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.customer == null
                ? context.l10n.customerManagementCreatedMessage
                : context.l10n.customerManagementUpdatedMessage),
            backgroundColor: PosTheme.successGreen,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${context.l10n.customerManagementSaveFailedPrefix}: $e'),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.customer != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? context.l10n.customerManagementEditTitle
            : context.l10n.customerManagementNewTitle),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonSave),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtl,
              decoration: InputDecoration(
                labelText: context.l10n.customerManagementNameLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? context.l10n.commonRequired
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formPhone,
                hintText: '+855 12 345 678',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formEmail,
                hintText: 'customer@example.com',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtl,
              decoration: InputDecoration(
                labelText: context.l10n.formAddress,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _creditCtl,
              decoration: InputDecoration(
                labelText: context.l10n.customerManagementCreditLimitLabel,
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtl,
              decoration: InputDecoration(
                labelText: context.l10n.customerManagementNotesLabel,
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving
                    ? context.l10n.customerManagementSavingLabel
                    : (isEdit
                        ? context.l10n.customerManagementUpdateButtonLabel
                        : context.l10n.customerManagementCreateButtonLabel)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: PosTheme.primaryGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Customer detail screen with purchase history and credit info.
class _CustomerDetailScreen extends ConsumerStatefulWidget {
  final int customerId;

  const _CustomerDetailScreen({required this.customerId});

  @override
  ConsumerState<_CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends ConsumerState<_CustomerDetailScreen> {
  Customer? _customer;
  List<Map<String, dynamic>> _history = [];
  Map<String, dynamic>? _ledger;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiServiceProvider);
      final c = await api
          .get<Map<String, dynamic>>('/api/customers/${widget.customerId}');
      final h = await api
          .get<List<dynamic>>('/api/customers/${widget.customerId}/history');
      Map<String, dynamic>? l;
      try {
        l = await api.get<Map<String, dynamic>>(
            '/api/customers/${widget.customerId}/credit-ledger');
      } catch (_) {}

      setState(() {
        _customer = Customer.fromJson(c);
        _history = h.cast<Map<String, dynamic>>();
        _ledger = l;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLanguageProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_customer != null
            ? _customer!.localizedName(lang)
            : context.l10n.customerManagementDetailFallbackTitle),
        actions: [
          if (_customer != null)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => CustomerFormScreen(customer: _customer),
                  ),
                );
                if (result == true) _load();
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      if (_ledger != null) _buildCreditCard(),
                      const SizedBox(height: 16),
                      _buildHistorySection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard() {
    final c = _customer!;
    final lang = ref.watch(appLanguageProvider);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PosTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person,
                      color: PosTheme.primaryGreen, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.localizedName(lang),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 18)),
                      if (c.phone != null || c.email != null)
                        Text(
                          [c.phone, c.email].whereType<String>().join(' · '),
                          style: const TextStyle(
                              fontSize: 13, color: PosTheme.textSecondary),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (c.address != null && c.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('📍 ${c.address}',
                  style: const TextStyle(
                      fontSize: 13, color: PosTheme.textSecondary)),
            ],
            if (c.notes != null && c.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('📝 ${c.notes}',
                  style: const TextStyle(
                      fontSize: 13,
                      color: PosTheme.textSecondary,
                      fontStyle: FontStyle.italic)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCard() {
    final balance = (_ledger!['creditBalance'] as num?)?.toDouble() ??
        _customer!.creditBalance;
    final limit = _customer!.creditLimit;
    final usagePercent = limit > 0 ? (balance / limit * 100) : 0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card,
                    size: 20, color: PosTheme.warningAmber),
                const SizedBox(width: 8),
                Text(context.l10n.customerManagementCreditAccountTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l10n.customerManagementBalanceLabel,
                    style: const TextStyle(
                        fontSize: 13, color: PosTheme.textSecondary)),
                Text('\$${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: balance > 0
                          ? (balance > limit * 0.8
                              ? PosTheme.errorRed
                              : PosTheme.warningAmber)
                          : PosTheme.successGreen,
                    )),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    '${context.l10n.customerManagementLimitPrefix} \$${limit.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 12, color: PosTheme.textHint)),
                Text(
                    '${usagePercent.toStringAsFixed(0)}% ${context.l10n.customerManagementUsedSuffix}',
                    style: const TextStyle(
                        fontSize: 12, color: PosTheme.textHint)),
              ],
            ),
            if (limit > 0) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (usagePercent / 100).clamp(0.0, 1.0),
                  backgroundColor: PosTheme.dividerColor,
                  color: usagePercent > 80
                      ? PosTheme.errorRed
                      : usagePercent > 50
                          ? PosTheme.warningAmber
                          : PosTheme.successGreen,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_history.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(context.l10n.customerManagementNoPurchaseHistory,
                style: const TextStyle(color: PosTheme.textSecondary)),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(context.l10n.customerManagementPurchaseHistoryTitle,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        ..._history.map((sale) {
          final id = sale['saleId'] ?? sale['id'];
          final total = (sale['grandTotal'] as num?)?.toDouble() ?? 0;
          final status = sale['status'] as String? ?? '';
          final date = sale['createdAt'] as String? ?? '';
          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosTheme.radiusSmall),
              side: BorderSide(color: PosTheme.borderColor),
            ),
            child: ListTile(
              dense: true,
              title: Text('${context.l10n.customerManagementSalePrefix}$id',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${date.length >= 10 ? date.substring(0, 10) : date} · $status'),
              trailing: Text('\$${total.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PosTheme.primaryGreen)),
            ),
          );
        }),
      ],
    );
  }
}
