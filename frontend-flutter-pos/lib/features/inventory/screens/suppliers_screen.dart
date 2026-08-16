import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';
import 'create_supplier.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  static const int _pageSize = 6;

  final TextEditingController _searchCtl = TextEditingController();
  int _currentPage = 0;
  final Set<int> _selectedIds = {};
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(suppliersProvider.notifier).loadSuppliers();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  List<Supplier> _filtered(List<Supplier> suppliers) {
    final needle = _searchCtl.text.trim().toLowerCase();
    if (needle.isEmpty) return suppliers;
    return suppliers
        .where((s) =>
            s.name.toLowerCase().contains(needle) ||
            (s.contactPerson ?? '').toLowerCase().contains(needle) ||
            (s.phone ?? '').toLowerCase().contains(needle))
        .toList();
  }

  Future<void> _openCreate() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateSupplier()),
    );
    if (result == true && mounted) setState(() => _currentPage = 0);
  }

  Future<void> _openEdit(Supplier supplier) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateSupplier(initialSupplier: supplier),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.suppliersDeleteTitle),
        content: Text(
          context.l10n.suppliersDeleteConfirm('${_selectedIds.length}'),
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
      ),
    );
    if (confirmed != true) return;

    final ids = _selectedIds.toList();
    try {
      for (final id in ids) {
        await ref.read(suppliersProvider.notifier).deleteSupplier(id);
      }
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _currentPage = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.suppliersDeleteSuccess('${ids.length}'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.suppliersDeleteFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(suppliersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.suppliersTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () => ref.read(suppliersProvider.notifier).loadSuppliers(),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (suppliers) {
            final isSearching = _searchCtl.text.trim().isNotEmpty;
            if (!isSearching && suppliers.isEmpty && _hasLoadedOnce) {
              return _buildEmptyState();
            }
            return _buildList(suppliers, loading: false);
          },
          loading: () {
            if (!_hasLoadedOnce) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildList(const [], loading: true);
          },
          error: (e, _) => _buildErrorState('$e'),
        ),
      ),
    );
  }

  Widget _buildList(List<Supplier> allSuppliers, {required bool loading}) {
    final filtered = _filtered(allSuppliers);
    final totalItems = filtered.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageSuppliers = filtered.sublist(startIndex, endIndex);

    final pageIds =
        pageSuppliers.map((s) => s.id).whereType<int>().toSet();
    final allPageSelected =
        pageIds.isNotEmpty && pageIds.every(_selectedIds.contains);
    final somePageSelected = pageIds.any(_selectedIds.contains);

    return RefreshIndicator(
      onRefresh: () => ref.read(suppliersProvider.notifier).loadSuppliers(),
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
                        onPressed: _openCreate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PosTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(170, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: Text(
                          context.l10n.suppliersAddButton,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: context.l10n.suppliersDeleteSelectedTooltip,
                        onPressed: _selectedIds.isEmpty ? null : _deleteSelected,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          foregroundColor: Colors.red,
                          disabledForegroundColor: Colors.grey.shade400,
                          side: BorderSide(
                            color: _selectedIds.isEmpty
                                ? Colors.grey.shade300
                                : Colors.red,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                      if (_selectedIds.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        Text(
                          context.l10n.suppliersSelectedCount('${_selectedIds.length}'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, color: Colors.black54),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: TextField(
                          controller: _searchCtl,
                          onChanged: (_) => setState(() => _currentPage = 0),
                          decoration: InputDecoration(
                            hintText: context.l10n.suppliersSearchHint,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            suffixIcon: _searchCtl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchCtl.clear();
                                      setState(() => _currentPage = 0);
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
                                vertical: 0, horizontal: 12),
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
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 42,
                        child: Checkbox(
                          tristate: true,
                          value: allPageSelected
                              ? true
                              : somePageSelected
                                  ? null
                                  : false,
                          onChanged: (_) {
                            setState(() {
                              if (allPageSelected) {
                                _selectedIds.removeAll(pageIds);
                              } else {
                                _selectedIds.addAll(pageIds);
                              }
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.suppliersTitle,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.black54),
                        ),
                      ),
                      Text(
                        context.l10n.inventoryShowingCount(
                            '${pageSuppliers.length}', '$totalItems'),
                        style: const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageSuppliers.isEmpty)
                  _buildNoResults(loading: loading)
                else
                  ...pageSuppliers.map(_buildRow),
                if (pageSuppliers.isNotEmpty)
                  _buildPagination(
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
            Icon(Icons.local_shipping_outlined, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              _searchCtl.text.trim().isEmpty
                  ? context.l10n.suppliersNoSuppliersFound
                  : context.l10n.suppliersNoMatchingSuppliersFound,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(Supplier supplier) {
    final currencyCode = watchCurrency(ref);
    final selected = supplier.id != null && _selectedIds.contains(supplier.id);

    final subtitleParts = [
      if (supplier.contactPerson != null && supplier.contactPerson!.isNotEmpty)
        supplier.contactPerson!,
      if (supplier.phone != null && supplier.phone!.isNotEmpty) supplier.phone!,
    ];
    final subtitle = subtitleParts.isEmpty
        ? context.l10n.suppliersNoContactSet
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
                  onChanged: supplier.id == null
                      ? null
                      : (value) {
                          setState(() {
                            if (value ?? false) {
                              _selectedIds.add(supplier.id!);
                            } else {
                              _selectedIds.remove(supplier.id!);
                            }
                          });
                        },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => _openEdit(supplier),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Color(0xFF99D267),
                          child: Icon(Icons.local_shipping, color: Colors.white),
                        ),
                        const SizedBox(width: 22),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                supplier.name,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (supplier.openPayable != null && supplier.openPayable! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: PosTheme.warningAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.l10n.suppliersOwedAmount(
                        formatAmount(supplier.openPayable!, currencyCode)),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: PosTheme.warningAmber),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: supplier.active
                      ? PosTheme.successGreen.withValues(alpha: 0.12)
                      : PosTheme.errorRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  supplier.active
                      ? context.l10n.commonActive.toUpperCase()
                      : context.l10n.commonInactive.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: supplier.active ? PosTheme.successGreen : PosTheme.errorRed,
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

  Widget _buildPagination({
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
              context.l10n
                  .inventoryPaginationRange('$firstItem', '$lastItem', '$totalItems'),
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 20),
          IconButton(
            tooltip: context.l10n.inventoryFirstPageTooltip,
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: context.l10n.inventoryPreviousPageTooltip,
            onPressed: currentPage == 0
                ? null
                : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(
                context.l10n.inventoryPaginationPage('${currentPage + 1}', '$totalPages'),
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          IconButton(
            tooltip: context.l10n.inventoryNextPageTooltip,
            onPressed: currentPage >= totalPages - 1
                ? null
                : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: context.l10n.inventoryLastPageTooltip,
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
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 45),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 105,
                      height: 105,
                      decoration:
                          BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                      child: const Icon(Icons.local_shipping_outlined, size: 52, color: Colors.grey),
                    ),
                    const SizedBox(height: 28),
                    Text(context.l10n.suppliersTitle,
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 18),
                    Text(
                      context.l10n.suppliersEmptySubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.black54),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: _openCreate,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(170, 54),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(context.l10n.suppliersAddButton,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
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
              onPressed: () => ref.read(suppliersProvider.notifier).loadSuppliers(),
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
