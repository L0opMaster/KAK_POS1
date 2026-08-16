import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../../core/utils/receipt_date_format.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import '../providers/inventory_provider.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// inventory_history_screen.dart` — logic COPY/ADAPT NEARLY EXACTLY: same
/// `movementsProvider` data source as Stock Adjustments, but read-only (no
/// create action) and filtered server-side by a single product dropdown
/// (`movementsProvider.notifier.load(productId: ...)`) instead of Stock
/// Adjustments' client-side free-text search — no date-range filter
/// exists in source either. Desktop's paged `DataTable` becomes a plain
/// scrolling list (MOBILE UI REIMPLEMENT). Print/save-PDF deferred to
/// Day 18, same reasoning as Stock Adjustments.
class MobileInventoryHistoryScreen extends ConsumerStatefulWidget {
  const MobileInventoryHistoryScreen({super.key});

  @override
  ConsumerState<MobileInventoryHistoryScreen> createState() =>
      _MobileInventoryHistoryScreenState();
}

class _MobileInventoryHistoryScreenState
    extends ConsumerState<MobileInventoryHistoryScreen> {
  Product? _filterProduct;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(movementsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final products = ref.watch(productsProvider).products;
    final state = ref.watch(movementsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.posDrawerInventoryHistory)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: DropdownButtonFormField<Product?>(
              initialValue: _filterProduct,
              decoration: InputDecoration(
                labelText: l10n.inventoryHistoryFilterByProduct,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.inventoryHistoryAllProducts),
                ),
                for (final p in products)
                  DropdownMenuItem(
                    value: p,
                    child: Text(
                      p.localizedName(language),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (p) {
                setState(() => _filterProduct = p);
                ref.read(movementsProvider.notifier).load(productId: p?.id);
              },
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (movements) {
                if (movements.isEmpty) {
                  return Center(child: Text(l10n.inventoryHistoryNoMovements));
                }
                final sorted = [...movements]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return RefreshIndicator(
                  onRefresh: () => ref
                      .read(movementsProvider.notifier)
                      .load(productId: _filterProduct?.id),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PosTheme.spacingMd,
                    ),
                    itemCount: sorted.length,
                    itemBuilder: (context, i) {
                      final m = sorted[i];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(
                          bottom: PosTheme.spacingSm,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            PosTheme.radiusMedium,
                          ),
                          side: BorderSide(
                            color: PosTheme.borderColorOf(context),
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: PosTheme.accentBlueLight,
                              borderRadius: BorderRadius.circular(
                                PosTheme.radiusPill,
                              ),
                            ),
                            child: Text(
                              m.movementType.replaceAll('_', ' '),
                              style: const TextStyle(
                                fontSize: PosTheme.fontSizeXs,
                                fontWeight: FontWeight.w600,
                                color: PosTheme.accentBlue,
                              ),
                            ),
                          ),
                          title: Text(m.productName),
                          subtitle: Text(
                            [
                              formatReceiptDate(m.createdAt),
                              if (m.reason != null) m.reason!,
                              if (m.createdBy != null) m.createdBy!,
                            ].join(' • '),
                            style: TextStyle(
                              fontSize: PosTheme.fontSizeXs,
                              color: PosTheme.textSecondaryOf(context),
                            ),
                          ),
                          trailing: Text(
                            '${m.quantity >= 0 ? '+' : ''}${m.quantity.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: m.quantity >= 0
                                  ? PosTheme.successGreen
                                  : PosTheme.errorRed,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
