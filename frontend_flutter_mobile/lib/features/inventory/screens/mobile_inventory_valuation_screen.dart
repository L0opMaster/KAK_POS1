import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../providers/inventory_provider.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// inventory_valuation_screen.dart` — logic COPY/ADAPT NEARLY EXACTLY:
/// same `inventoryValuationProvider`/`loadReport()` data source (reload on
/// open + pull-to-refresh, no store filter — single-store app), same
/// client-side name/SKU search filter. Desktop's paged `DataTable` becomes
/// a plain scrolling list (MOBILE UI REIMPLEMENT). Print/save-PDF deferred
/// to Day 18.
class MobileInventoryValuationScreen extends ConsumerStatefulWidget {
  const MobileInventoryValuationScreen({super.key});

  @override
  ConsumerState<MobileInventoryValuationScreen> createState() =>
      _MobileInventoryValuationScreenState();
}

class _MobileInventoryValuationScreenState
    extends ConsumerState<MobileInventoryValuationScreen> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(inventoryValuationProvider.notifier).loadReport(),
    );
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(inventoryValuationProvider);
    final cur = watchCurrency(ref);
    final query = _searchCtl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.posDrawerInventoryValuation),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(inventoryValuationProvider.notifier).loadReport(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (report) {
          if (report == null) return const SizedBox.shrink();
          final visible = query.isEmpty
              ? report.items
              : report.items
                    .where(
                      (i) =>
                          i.productName.toLowerCase().contains(query) ||
                          i.sku.toLowerCase().contains(query),
                    )
                    .toList();
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(inventoryValuationProvider.notifier).loadReport(),
            child: ListView(
              padding: const EdgeInsets.all(PosTheme.spacingMd),
              children: [
                Container(
                  padding: const EdgeInsets.all(PosTheme.spacingLg),
                  decoration: BoxDecoration(
                    color: PosTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      PosTheme.radiusMedium,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.inventoryValuationTotalValue,
                        style: TextStyle(
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                      Text(
                        formatAmount(report.totalValue, cur),
                        style: const TextStyle(
                          fontSize: PosTheme.fontSizeXxl,
                          fontWeight: FontWeight.bold,
                          color: PosTheme.successGreen,
                        ),
                      ),
                      const SizedBox(height: PosTheme.spacingXs),
                      Text(
                        '${l10n.inventoryValuationProductsLabel}: '
                        '${report.totalProducts}'
                        '${report.valuedAt != null ? ' • ${report.valuedAt}' : ''}',
                        style: TextStyle(
                          fontSize: PosTheme.fontSizeSm,
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: PosTheme.spacingMd),
                TextField(
                  controller: _searchCtl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l10n.commonSearch,
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        PosTheme.radiusMedium,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PosTheme.spacingSm),
                for (final item in visible)
                  Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        PosTheme.radiusMedium,
                      ),
                      side: BorderSide(color: PosTheme.borderColorOf(context)),
                    ),
                    child: ListTile(
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.sku} • ${l10n.inventoryValuationColStock}: '
                        '${item.stock.toStringAsFixed(0)} • '
                        '${formatAmount(item.cost, cur)}',
                        style: TextStyle(
                          fontSize: PosTheme.fontSizeXs,
                          color: PosTheme.textSecondaryOf(context),
                        ),
                      ),
                      trailing: Text(
                        formatAmount(item.totalValue, cur),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: PosTheme.successGreen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
