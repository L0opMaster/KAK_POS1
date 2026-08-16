import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extensions.dart';
import 'mobile_inventory_counts_screen.dart';
import 'mobile_inventory_history_screen.dart';
import 'mobile_inventory_valuation_screen.dart';
import 'mobile_productions_screen.dart';
import 'mobile_purchase_orders_screen.dart';
import 'mobile_stock_adjustments_screen.dart';
import 'mobile_stock_lookup_screen.dart';
import 'mobile_suppliers_screen.dart';
import 'mobile_transfer_orders_screen.dart';

/// Genuinely new in this port — `[OLD/SOURCE]` has no equivalent screen.
/// Its 9 inventory destinations live as `_subNavTile` entries inside the
/// desktop's permanent `Scaffold.drawer` (`features/pos/screens/
/// _pos_drawer.dart`'s expandable "Inventory" section) — appropriate for a
/// wide viewport where the drawer stays one hamburger-tap away from any
/// screen. This screen is that section's mobile equivalent: a plain list,
/// same 9 destinations, same icons, same order, reached from the shell's
/// More tab (see `mobile_shell_screen.dart`) instead of a drawer.
///
/// `[OLD/SOURCE]`'s `inventory_hub_screen.dart` file is NOT this screen's
/// counterpart despite the similar name — that file is the "Stock Lookup"
/// destination's content (product search + low/out-of-stock summary
/// cards), ported here as `MobileStockLookupScreen`.
class MobileInventoryHubScreen extends StatelessWidget {
  const MobileInventoryHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (
        icon: Icons.search_rounded,
        title: l10n.posDrawerStockLookup,
        builder: (BuildContext _) => const MobileStockLookupScreen(),
      ),
      (
        icon: Icons.shopping_cart_outlined,
        title: l10n.posDrawerPurchaseOrders,
        builder: (BuildContext _) => const MobilePurchaseOrdersScreen(),
      ),
      (
        icon: Icons.swap_horiz_rounded,
        title: l10n.posDrawerTransferOrders,
        builder: (BuildContext _) => const MobileTransferOrdersScreen(),
      ),
      (
        icon: Icons.tune_rounded,
        title: l10n.posDrawerStockAdjustments,
        builder: (BuildContext _) => const MobileStockAdjustmentsScreen(),
      ),
      (
        icon: Icons.playlist_add_check_rounded,
        title: l10n.posDrawerInventoryCounts,
        builder: (BuildContext _) => const MobileInventoryCountsScreen(),
      ),
      (
        icon: Icons.precision_manufacturing_outlined,
        title: l10n.posDrawerProductions,
        builder: (BuildContext _) => const MobileProductionsScreen(),
      ),
      (
        icon: Icons.local_shipping_outlined,
        title: l10n.posDrawerSuppliers,
        builder: (BuildContext _) => const MobileSuppliersScreen(),
      ),
      (
        icon: Icons.history_rounded,
        title: l10n.posDrawerInventoryHistory,
        builder: (BuildContext _) => const MobileInventoryHistoryScreen(),
      ),
      (
        icon: Icons.attach_money_rounded,
        title: l10n.posDrawerInventoryValuation,
        builder: (BuildContext _) => const MobileInventoryValuationScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.posDrawerInventoryManagement)),
      body: ListView(
        children: [
          for (final d in destinations)
            ListTile(
              leading: Icon(d.icon),
              title: Text(d.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: d.builder)),
            ),
        ],
      ),
    );
  }
}
