import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/pos_theme.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/utils/bilingual.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../pos/models/product_models.dart';
import '../../pos/providers/product_provider.dart';

class InventoryHubScreen extends ConsumerWidget {
  const InventoryHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider).products;
    final language = ref.watch(appLanguageProvider);
    final totalProducts = products.length;
    final lowStockCount =
        products.where((p) => p.stock <= 5 && p.stock > 0).length;
    final outOfStockCount = products.where((p) => p.stock == 0).length;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.inventoryHubTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _SummaryCard(
                    icon: Icons.inventory_2,
                    label: context.l10n.inventoryHubTotalLabel,
                    value: '$totalProducts',
                    color: PosTheme.accentBlue),
                const SizedBox(width: 8),
                _SummaryCard(
                    icon: Icons.warning_amber_rounded,
                    label: context.l10n.inventoryHubLowStockLabel,
                    value: '$lowStockCount',
                    color: PosTheme.warningAmber),
                const SizedBox(width: 8),
                _SummaryCard(
                    icon: Icons.block,
                    label: context.l10n.inventoryHubOutOfStockLabel,
                    value: '$outOfStockCount',
                    color: PosTheme.errorRed),
              ],
            ),
          ),
          const Divider(height: 1, color: PosTheme.dividerColor),
          Expanded(
            child: products.isEmpty
                ? Center(child: Text(context.l10n.inventoryNoProductsFound))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (ctx, i) =>
                        _StockRow(product: products[i], language: language),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style: TextStyle(fontSize: 11, color: color.withOpacity(0.7))),
          ],
        ),
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
    final isLow = product.stock > 0 && product.stock <= 5;
    final isOut = product.stock == 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: PosTheme.dividerColor))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.localizedName(language),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (product.sku.isNotEmpty)
                  Text('${context.l10n.formSku}: ${product.sku}',
                      style: TextStyle(fontSize: 11, color: PosTheme.textHint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOut
                  ? PosTheme.errorRed.withOpacity(0.1)
                  : isLow
                      ? PosTheme.warningAmber.withOpacity(0.15)
                      : PosTheme.primaryGreenLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${product.stock}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isOut
                        ? PosTheme.errorRed
                        : isLow
                            ? PosTheme.warningAmber
                            : PosTheme.primaryGreen)),
          ),
        ],
      ),
    );
  }
}
