import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/l10n_extensions.dart';
import 'mobile_company_profile_screen.dart';
import 'mobile_currencies_screen.dart';
import 'mobile_debug_settings_screen.dart';
import 'mobile_general_settings_screen.dart';
import 'mobile_payment_methods_screen.dart';
import 'mobile_pos_settings_screen.dart';
import 'mobile_printer_settings_screen.dart';
import 'mobile_tax_settings_screen.dart';

/// Genuinely new in this port's exact shape — `[OLD/SOURCE]`'s
/// `settings_modules_screen.dart` puts every section (Company Profile,
/// Tax, General incl. Main Color/Dark Mode, Printers incl. the thermal
/// transport config, Payment Methods, Currencies) as cards on ONE long
/// scrolling form, plus a separate `pos_settings_screen.dart` reached via
/// a `ListTile`. This screen is that form's mobile equivalent: a plain
/// menu, one destination per section (MOBILE UI REIMPLEMENT — a
/// screen-per-section navigation instead of one long scroll, matching
/// this port's Day 17/18 convention for "one hub, many destinations").
/// Every section's business logic (validation, save payload shape) is
/// unchanged — see each destination screen's own doc comment.
class MobileSettingsScreen extends StatelessWidget {
  const MobileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final destinations = [
      (
        icon: Icons.storefront_outlined,
        title: l10n.settingsCompanyProfile,
        builder: (BuildContext _) => const MobileCompanyProfileScreen(),
      ),
      (
        icon: Icons.tune_outlined,
        title: l10n.settingsGeneral,
        builder: (BuildContext _) => const MobileGeneralSettingsScreen(),
      ),
      (
        icon: Icons.percent_outlined,
        title: l10n.settingsTax,
        builder: (BuildContext _) => const MobileTaxSettingsScreen(),
      ),
      (
        icon: Icons.print_outlined,
        title: l10n.settingsPrinters,
        builder: (BuildContext _) => const MobilePrinterSettingsScreen(),
      ),
      (
        icon: Icons.payments_outlined,
        title: l10n.settingsPaymentMethods,
        builder: (BuildContext _) => const MobilePaymentMethodsScreen(),
      ),
      (
        icon: Icons.attach_money_outlined,
        title: l10n.settingsCurrencies,
        builder: (BuildContext _) => const MobileCurrenciesScreen(),
      ),
      (
        icon: Icons.point_of_sale_outlined,
        title: l10n.settingsPosSettings,
        builder: (BuildContext _) => const MobilePosSettingsScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
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
          if (kDebugMode) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Debug settings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MobileDebugSettingsScreen(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
