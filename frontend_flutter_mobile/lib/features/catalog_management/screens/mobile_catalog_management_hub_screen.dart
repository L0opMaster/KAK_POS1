import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extensions.dart';
import 'mobile_category_management_screen.dart';
import 'mobile_item_management_screen.dart';
import 'mobile_modifier_management_screen.dart';
import 'mobile_table_management_screen.dart';
import 'mobile_unit_management_screen.dart';

/// Genuinely new in this port — desktop has no single equivalent screen.
/// Its 5 destinations live as separate expandable-drawer sections in
/// `frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart` (Items:
/// Item List/Categories/Modifiers/Units, plus Tables). This screen groups
/// them behind one "Catalog Management" entry in the shell's More tab,
/// mirroring the same hub-of-destinations pattern already used by
/// `mobile_inventory_hub_screen.dart` and `mobile_settings_screen.dart`.
class MobileCatalogManagementHubScreen extends StatelessWidget {
  const MobileCatalogManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (
        icon: Icons.inventory_2_outlined,
        title: l10n.posDrawerItemList,
        builder: (BuildContext _) => const MobileItemManagementScreen(),
      ),
      (
        icon: Icons.category_outlined,
        title: l10n.navCategories,
        builder: (BuildContext _) => const MobileCategoryManagementScreen(),
      ),
      (
        icon: Icons.straighten_outlined,
        title: l10n.posDrawerUnits,
        builder: (BuildContext _) => const MobileUnitManagementScreen(),
      ),
      (
        icon: Icons.tune_rounded,
        title: l10n.posDrawerModifiers,
        builder: (BuildContext _) => const MobileModifierManagementScreen(),
      ),
      (
        icon: Icons.table_restaurant_outlined,
        title: l10n.posDrawerTableList,
        builder: (BuildContext _) => const MobileTableManagementScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navCatalogManagement)),
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
