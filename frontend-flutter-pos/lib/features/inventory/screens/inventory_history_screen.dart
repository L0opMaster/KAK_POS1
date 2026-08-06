import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import '../models/inventory_models.dart';
import '../providers/inventory_provider.dart';

/// Read-only log of every stock movement (sales, purchases, adjustments,
/// transfers, production, returns, ...) — same backend data as Stock
/// Adjustments, presented here as a full audit trail with a product filter
/// instead of a create action.
class InventoryHistoryScreen extends ConsumerStatefulWidget {
  const InventoryHistoryScreen({super.key});

  @override
  ConsumerState<InventoryHistoryScreen> createState() =>
      _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState
    extends ConsumerState<InventoryHistoryScreen> {
  static const int _pageSize = 10;

  int _currentPage = 0;
  int? _productFilterId;
  bool _hasLoadedOnce = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(movementsProvider.notifier).load();
      await ref.read(productsProvider.notifier).loadProducts();
      if (mounted) setState(() => _hasLoadedOnce = true);
    });
  }

  void _applyProductFilter(int? productId) {
    setState(() {
      _productFilterId = productId;
      _currentPage = 0;
    });
    ref.read(movementsProvider.notifier).load(productId: productId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movementsProvider);
    final products = ref.watch(productsProvider).products;
    final lang = ref.watch(appLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.inventoryHistoryTitle),
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.commonRefresh,
            onPressed: () =>
                ref.read(movementsProvider.notifier).load(productId: _productFilterId),
          ),
        ],
      ),
      body: SafeArea(
        child: state.when(
          data: (movements) => _buildList(movements, products, lang, loading: false),
          loading: () {
            if (!_hasLoadedOnce) {
              return const Center(child: CircularProgressIndicator());
            }
            return _buildList(const [], products, lang, loading: true);
          },
          error: (e, _) => _buildErrorState('$e'),
        ),
      ),
    );
  }

  Widget _buildList(
    List<StockMovementEntry> allMovements,
    List<Product> products,
    AppLanguage lang, {
    required bool loading,
  }) {
    final sorted = [...allMovements]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final totalItems = sorted.length;
    final totalPages = math.max(1, (totalItems / _pageSize).ceil());
    final safeCurrentPage = math.min(_currentPage, totalPages - 1);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pageMovements = sorted.sublist(startIndex, endIndex);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(movementsProvider.notifier).load(productId: _productFilterId),
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
                        child: Text(context.l10n.inventoryHistoryTitle,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      SizedBox(
                        width: 260,
                        child: DropdownButtonFormField<int?>(
                          initialValue: _productFilterId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.l10n.inventoryHistoryFilterByProduct,
                            border: const OutlineInputBorder(),
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          items: [
                            DropdownMenuItem<int?>(
                                value: null, child: Text(context.l10n.inventoryHistoryAllProducts)),
                            ...products.map((p) => DropdownMenuItem<int?>(
                                  value: p.id,
                                  child: Text(
                                    p.localizedName(lang),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )),
                          ],
                          onChanged: _applyProductFilter,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(context.l10n.inventoryHistoryMovementsLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                      ),
                      Text(context.l10n.inventoryHistoryShowingCount('${pageMovements.length}', '$totalItems'),
                          style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (pageMovements.isEmpty)
                  _buildNoResults(loading: loading)
                else
                  ...pageMovements.map(_buildRow),
                if (pageMovements.isNotEmpty)
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
              width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(context.l10n.inventoryHistoryNoMovements,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(StockMovementEntry movement) {
    final isPositive = movement.quantity >= 0;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: PosTheme.accentBlue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              movement.movementType.replaceAll('_', ' '),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: PosTheme.accentBlue),
            ),
          ),
          title: Text(movement.productName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text(
            [
              _fmtDate(movement.createdAt),
              if (movement.reason != null && movement.reason!.isNotEmpty) movement.reason!,
              if (movement.createdBy != null) movement.createdBy!,
            ].join(' • '),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          trailing: Text(
            '${isPositive ? '+' : ''}${movement.quantity.toStringAsFixed(movement.quantity.truncateToDouble() == movement.quantity ? 0 : 2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isPositive ? PosTheme.successGreen : PosTheme.errorRed,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
          Text(context.l10n.inventoryHistoryPaginationRange('$firstItem', '$lastItem', '$totalItems'), style: const TextStyle(color: Colors.black54)),
          const SizedBox(width: 20),
          IconButton(
            tooltip: context.l10n.inventoryHistoryFirstPage,
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = 0),
            icon: const Icon(Icons.first_page),
          ),
          IconButton(
            tooltip: context.l10n.inventoryHistoryPrevPage,
            onPressed: currentPage == 0 ? null : () => setState(() => _currentPage = currentPage - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 100),
            alignment: Alignment.center,
            child: Text(context.l10n.inventoryHistoryPageOf('${currentPage + 1}', '$totalPages'),
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          IconButton(
            tooltip: context.l10n.inventoryHistoryNextPage,
            onPressed:
                currentPage >= totalPages - 1 ? null : () => setState(() => _currentPage = currentPage + 1),
            icon: const Icon(Icons.chevron_right),
          ),
          IconButton(
            tooltip: context.l10n.inventoryHistoryLastPage,
            onPressed: currentPage >= totalPages - 1 ? null : () => setState(() => _currentPage = totalPages - 1),
            icon: const Icon(Icons.last_page),
          ),
        ],
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
              onPressed: () => ref.read(movementsProvider.notifier).load(),
              child: Text(context.l10n.commonRetry.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }
}
