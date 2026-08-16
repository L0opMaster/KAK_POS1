import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extensions.dart';
import 'mobile_cashier_performance_screen.dart';
import 'mobile_category_performance_screen.dart';
import 'mobile_daily_report_screen.dart';
import 'mobile_discounts_screen.dart';
import 'mobile_monthly_sales_screen.dart';
import 'mobile_payment_mix_screen.dart';
import 'mobile_sales_by_item_screen.dart';
import 'mobile_sales_by_modifier_screen.dart';
import 'mobile_sales_report_screen.dart';
import 'mobile_sales_summary_screen.dart';
import 'mobile_stock_movement_screen.dart';
import 'mobile_taxes_screen.dart';
import 'mobile_top_products_screen.dart';

/// Ported from `frontend-flutter-pos/lib/features/reports/screens/
/// reports_hub_screen.dart` — COPY/ADAPT NEARLY EXACTLY for the
/// destination list/grouping/order: 4 sections (Sales Reports / Other
/// Reports / Performance / Inventory), same 12 destinations, same order.
/// Desktop's card-grid layout becomes a plain grouped list (MOBILE UI
/// REIMPLEMENT).
class MobileReportsHubScreen extends StatelessWidget {
  const MobileReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = [
      (
        title: l10n.reportsHubSalesReportsSection,
        items: [
          (
            icon: Icons.summarize_outlined,
            title: l10n.reportsSalesSummary,
            subtitle: l10n.reportsHubSalesSummarySubtitle,
            builder: (BuildContext _) => const MobileSalesSummaryScreen(),
          ),
          (
            icon: Icons.inventory_2_outlined,
            title: l10n.reportsSalesByItem,
            subtitle: l10n.reportsHubSalesByItemSubtitle,
            builder: (BuildContext _) => const MobileSalesByItemScreen(),
          ),
          (
            icon: Icons.category_outlined,
            title: l10n.reportsSalesByCategory,
            subtitle: l10n.reportsHubSalesByCategorySubtitle,
            builder: (BuildContext _) => const MobileCategoryPerformanceScreen(),
          ),
          (
            icon: Icons.person_outline,
            title: l10n.reportsSalesByCashier,
            subtitle: l10n.reportsHubSalesByCashierSubtitle,
            builder: (BuildContext _) => const MobileCashierPerformanceScreen(),
          ),
          (
            icon: Icons.payments_outlined,
            title: l10n.reportsSalesByPaymentType,
            subtitle: l10n.reportsHubPaymentMixSubtitle,
            builder: (BuildContext _) => const MobilePaymentMixScreen(),
          ),
          (
            icon: Icons.receipt_long_outlined,
            title: l10n.navReceipts,
            subtitle: l10n.reportsHubReceiptsSubtitle,
            builder: (BuildContext _) => const MobileSalesReportScreen(),
          ),
          (
            icon: Icons.tune_outlined,
            title: l10n.reportsSalesByModifier,
            subtitle: l10n.reportsHubSalesByModifierSubtitle,
            builder: (BuildContext _) => const MobileSalesByModifierScreen(),
          ),
          (
            icon: Icons.percent_outlined,
            title: l10n.reportsDiscounts,
            subtitle: l10n.reportsHubDiscountsSubtitle,
            builder: (BuildContext _) => const MobileDiscountsScreen(),
          ),
          (
            icon: Icons.account_balance_outlined,
            title: l10n.reportsTaxes,
            subtitle: l10n.reportsHubTaxesSubtitle,
            builder: (BuildContext _) => const MobileTaxesScreen(),
          ),
        ],
      ),
      (
        title: l10n.reportsHubOtherReportsSection,
        items: [
          (
            icon: Icons.today_outlined,
            title: l10n.reportsHubDailyReportTitle,
            subtitle: l10n.reportsHubDailyReportSubtitle,
            builder: (BuildContext _) => const MobileDailyReportScreen(),
          ),
          (
            icon: Icons.star_outline,
            title: l10n.reportsHubTopProductsTitle,
            subtitle: l10n.reportsHubTopProductsSubtitle,
            builder: (BuildContext _) => const MobileTopProductsScreen(),
          ),
        ],
      ),
      (
        title: l10n.reportsHubPerformanceSection,
        items: [
          (
            icon: Icons.show_chart_outlined,
            title: l10n.reportsHubMonthlySalesTitle,
            subtitle: l10n.reportsHubMonthlySalesSubtitle,
            builder: (BuildContext _) => const MobileMonthlySalesScreen(),
          ),
        ],
      ),
      (
        title: l10n.navInventory,
        items: [
          (
            icon: Icons.local_shipping_outlined,
            title: l10n.reportsHubStockMovementsTitle,
            subtitle: l10n.reportsHubStockMovementsSubtitle,
            builder: (BuildContext _) => const MobileStockMovementScreen(),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportsTitle)),
      body: ListView(
        children: [
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                section.title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final item in section.items)
              ListTile(
                leading: Icon(item.icon),
                title: Text(item.title),
                subtitle: Text(item.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: item.builder)),
              ),
          ],
        ],
      ),
    );
  }
}
