import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/currency_utils.dart' as currency_utils;
import '../../../core/config/pos_theme.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';
import 'mobile_create_item_screen.dart';

/// Admin item/product-management screen — create/edit/delete the products
/// sold at the POS. Distinct from `product_card.dart`/`product_grid.dart`
/// (display-only, used by `pos_register_screen.dart` to browse/add to
/// cart): this screen is pushed as its own route from the catalog
/// management hub, not a permanent tab body.
///
/// Ported from `frontend-flutter-pos/lib/features/pos/screens/
/// item_management_screen.dart`: loads the entire matching set up front
/// (loops `loadMore()` until `hasMore == false`, same as desktop) then
/// searches/selects client-side. Desktop's `DataTable` + numbered
/// pagination footer becomes a plain scrolling list (mobile UI
/// reimplement) with live client-side search, matching this app's
/// established `mobile_suppliers_screen.dart`/`mobile_table_management_
/// screen.dart` admin-list convention: AppBar title toggles to "N
/// selected", FAB opens the create form, tapping a row opens edit,
/// checkbox multi-select + bulk delete behind an `AlertDialog` confirm.
class MobileItemManagementScreen extends ConsumerStatefulWidget {
  const MobileItemManagementScreen({super.key});

  @override
  ConsumerState<MobileItemManagementScreen> createState() =>
      _MobileItemManagementScreenState();
}

class _MobileItemManagementScreenState
    extends ConsumerState<MobileItemManagementScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final Set<int> _selected = {};
  bool _loadingAll = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loadingAll = true);
    final notifier = ref.read(productsProvider.notifier);
    await notifier.loadProducts();
    while (mounted && ref.read(productsProvider).hasMore) {
      await notifier.loadMore();
    }
    if (mounted) setState(() => _loadingAll = false);
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const MobileCreateItemScreen()),
    );
    if (created == true) _loadAll();
  }

  Future<void> _openEdit(Product product) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MobileCreateItemScreen(initialProduct: product),
      ),
    );
    if (updated == true) _loadAll();
  }

  Future<void> _deleteSelected() async {
    final l10n = context.l10n;
    final count = _selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.itemManagementDeleteItemsTitle),
        content: Text(l10n.itemManagementDeleteItemsMessage('$count')),
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
      final notifier = ref.read(productsProvider.notifier);
      for (final id in ids) {
        await notifier.deleteProduct(id);
      }
      setState(() => _selected.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.itemManagementItemsDeletedSuccess('${ids.length}')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.itemManagementFailedToDeleteItems('$e')),
            backgroundColor: PosTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(productsProvider);
    final query = _searchCtl.text.trim().toLowerCase();
    final currencyCode = currency_utils.watchCurrency(ref);
    final products = query.isEmpty
        ? state.products
        : state.products
            .where(
              (p) =>
                  p.nameEn.toLowerCase().contains(query) ||
                  p.nameKm.toLowerCase().contains(query) ||
                  p.sku.toLowerCase().contains(query) ||
                  p.barcode.toLowerCase().contains(query),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selected.isEmpty
              ? l10n.posDrawerItemList
              : l10n.itemManagementSelectedCount('${_selected.length}'),
        ),
        actions: [
          if (_selected.isNotEmpty)
            IconButton(
              tooltip: l10n.itemManagementDeleteSelectedItemsTooltip,
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected,
            )
          else
            IconButton(
              tooltip: l10n.commonRefresh,
              icon: const Icon(Icons.refresh),
              onPressed: _loadAll,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        tooltip: l10n.itemManagementAddItem,
        child: const Icon(Icons.add),
      ),
      body: Column(
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
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.itemManagementSearchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          if (_loadingAll && state.products.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null && state.products.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(PosTheme.spacingLg),
                  child: Text(
                    '${l10n.commonError}: ${state.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else if (products.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  query.isEmpty
                      ? l10n.itemManagementNoItemsFound
                      : l10n.itemManagementNoItemsFound,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAll,
                child: ListView.builder(
                  padding: const EdgeInsets.all(PosTheme.spacingMd),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final product = products[i];
                    final selected = _selected.contains(product.id);
                    final subtitle = [
                      'SKU: ${product.sku}',
                      product.categoryNameEn ?? l10n.itemManagementNoCategorySet,
                    ].join(' • ');

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
                        onTap: () => _openEdit(product),
                        leading: Checkbox(
                          value: selected,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(product.id);
                            } else {
                              _selected.remove(product.id);
                            }
                          }),
                        ),
                        title: Text(
                          product.nameEn,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: PosTheme.fontSizeXs,
                            color: PosTheme.textSecondaryOf(context),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              currency_utils.formatAmount(product.price, currencyCode),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            if (!product.active) ...[
                              const SizedBox(height: PosTheme.spacingXs),
                              _StatusPill(
                                label: l10n.commonInactive,
                                color: PosTheme.textHintOf(context),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
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
