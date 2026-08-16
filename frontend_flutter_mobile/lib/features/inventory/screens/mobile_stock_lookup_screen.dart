import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';

/// Ported from `frontend-flutter-pos/lib/features/inventory/screens/
/// inventory_hub_screen.dart` — RECREATE USING SAME LOGIC. Despite the
/// source file's name, this is a live stock-lookup/search screen (summary
/// counts + a searchable product list with per-row stock badges), not a
/// navigation hub — see `mobile_inventory_hub_screen.dart`'s doc comment
/// for that distinction. Search/summary logic reuses this project's own
/// `productsProvider` (already loaded — Day 6) rather than source's
/// `productServiceProvider.getProducts()` re-fetch, since a phone-shaped
/// screen reached from "More → Inventory" doesn't need a second full
/// catalog fetch just to look up stock. Low/out-of-stock thresholds
/// (`stock<=lowStockThreshold`, `stock==0`) are `Product`'s own fields,
/// already ported.
class MobileStockLookupScreen extends ConsumerStatefulWidget {
  const MobileStockLookupScreen({super.key});

  @override
  ConsumerState<MobileStockLookupScreen> createState() =>
      _MobileStockLookupScreenState();
}

class _MobileStockLookupScreenState
    extends ConsumerState<MobileStockLookupScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), () {
        setState(() => _query = _searchCtl.text.trim().toLowerCase());
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    final products = ref.watch(productsProvider).products;
    final lowStock = products
        .where((p) => p.trackInventory && !p.outOfStock && p.lowStock)
        .length;
    final outOfStock = products
        .where((p) => p.trackInventory && p.outOfStock)
        .length;
    final visible = _query.isEmpty
        ? products
        : products
              .where((p) => p.localizedName(language).toLowerCase().contains(_query) ||
                  p.sku.toLowerCase().contains(_query) ||
                  p.barcode.toLowerCase().contains(_query))
              .toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.posDrawerStockLookup)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingMd),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: l10n.inventoryHubTotalLabel,
                    value: '${products.length}',
                    color: PosTheme.accentBlue,
                  ),
                ),
                const SizedBox(width: PosTheme.spacingSm),
                Expanded(
                  child: _SummaryCard(
                    label: l10n.inventoryHubLowStockLabel,
                    value: '$lowStock',
                    color: PosTheme.warningAmber,
                  ),
                ),
                const SizedBox(width: PosTheme.spacingSm),
                Expanded(
                  child: _SummaryCard(
                    label: l10n.inventoryHubOutOfStockLabel,
                    value: '$outOfStock',
                    color: PosTheme.errorRed,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PosTheme.spacingMd,
            ),
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                hintText: l10n.commonSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
                ),
              ),
            ),
          ),
          const SizedBox(height: PosTheme.spacingSm),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      l10n.inventoryNoProductsFound,
                      style: TextStyle(color: PosTheme.textSecondaryOf(context)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: PosTheme.spacingMd,
                    ),
                    itemCount: visible.length,
                    itemBuilder: (context, i) =>
                        _StockRow(product: visible[i], language: language),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: PosTheme.spacingMd,
        horizontal: PosTheme.spacingSm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: PosTheme.fontSizeXl,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: PosTheme.fontSizeXs,
              color: PosTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.product, required this.language});

  final Product product;
  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final badgeColor = product.outOfStock
        ? PosTheme.errorRed
        : product.lowStock
        ? PosTheme.warningAmber
        : PosTheme.successGreen;
    final badgeText = product.outOfStock
        ? l10n.inventoryHubOutOfStockLabel
        : product.lowStock
        ? l10n.inventoryHubLowStockLabel
        : product.stock.toStringAsFixed(0);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: PosTheme.spacingSm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosTheme.radiusMedium),
        side: BorderSide(color: PosTheme.borderColorOf(context)),
      ),
      child: ListTile(
        title: Text(product.localizedName(language)),
        subtitle: Text(
          product.sku,
          style: TextStyle(
            fontSize: PosTheme.fontSizeXs,
            color: PosTheme.textSecondaryOf(context),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(PosTheme.radiusPill),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.w600,
              fontSize: PosTheme.fontSizeSm,
            ),
          ),
        ),
      ),
    );
  }
}
