import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extensions.dart';
import 'mobile_employee_management_screen.dart';
import 'mobile_permission_screen.dart';
import 'mobile_role_management_screen.dart';
import 'mobile_user_account_screen.dart';

/// Genuinely new in this port — desktop has no single equivalent screen.
/// Its 4 destinations live as `_subNavTile` entries inside
/// `frontend-flutter-pos/lib/features/pos/screens/_pos_drawer.dart`'s
/// expandable "Employees" drawer section (Employees List, User Account,
/// Role, Permission). This screen groups them behind one "Employees" entry
/// in the shell's More tab, mirroring the same hub-of-destinations pattern
/// already used by `mobile_inventory_hub_screen.dart` and
/// `mobile_catalog_management_hub_screen.dart`.
class MobileAccessManagementHubScreen extends StatelessWidget {
  const MobileAccessManagementHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (
        icon: Icons.badge_outlined,
        title: l10n.posDrawerEmployeesList,
        builder: (BuildContext _) => const MobileEmployeeManagementScreen(),
      ),
      (
        icon: Icons.account_circle_outlined,
        title: l10n.posDrawerUserAccount,
        builder: (BuildContext _) => const MobileUserAccountScreen(),
      ),
      (
        icon: Icons.admin_panel_settings_outlined,
        title: l10n.posDrawerRole,
        builder: (BuildContext _) => const MobileRoleManagementScreen(),
      ),
      (
        icon: Icons.verified_user_outlined,
        title: l10n.posDrawerPermission,
        builder: (BuildContext _) => const MobilePermissionScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.posDrawerEmployees)),
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
