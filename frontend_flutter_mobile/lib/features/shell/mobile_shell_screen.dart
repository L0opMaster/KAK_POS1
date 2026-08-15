import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/pos_theme.dart';
import '../../core/dev/theme_demo_screen.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/utils/l10n_extensions.dart';
import '../pos/screens/customer_picker_screen.dart';
import '../pos/screens/held_tickets_screen.dart';
import '../pos/screens/pos_register_screen.dart';
import '../pos/screens/receipts_screen.dart';
import '../pos/screens/shift_screen.dart';
import '../pos/screens/table_picker_screen.dart';

/// Which bottom-nav tab is currently showing (index into this file's
/// `destinations` list, Register = 0). This is the ONLY correct way for a
/// screen embedded as a tab body (`IndexedStack` child, never itself pushed
/// via `Navigator`) to switch back to another tab — e.g. after restoring a
/// held ticket or selecting a table, jump to the Register tab so the
/// cashier sees the effect immediately. `MobileShellScreen` is the app's
/// `home:` (see `main.dart`), so it's the ONLY route on the root
/// `Navigator` once logged in: a tab body calling
/// `Navigator.of(context).pop()` has nothing beneath it to pop and tears
/// the whole shell down instead (confirmed — see DAY_09.md section 12 for
/// the reproduction). Added Day 9 to fix exactly that bug in
/// `table_picker_screen.dart`/`held_tickets_screen.dart`; any future tab
/// body needing the same "done, show me the result" navigation should use
/// this provider too, not `Navigator.pop()`.
final shellTabIndexProvider = StateProvider<int>((ref) => 0);

/// The mobile app's post-login navigation shell. There is no equivalent
/// `[NEW/MOBILE]` file in `[OLD/SOURCE]` — the desktop app doesn't have a
/// "shell" concept, it has a permanent `Scaffold.drawer`
/// (`features/pos/screens/_pos_drawer.dart`'s `PosDrawer`, ~10 top-level
/// destinations plus several expandable sub-menus, appropriate for a wide
/// desktop/tablet viewport where a drawer can stay reachable via one
/// hamburger tap from any screen) layered under `main.dart`'s flat
/// ~35-entry named `routes` table.
///
/// A drawer with 10+ items and a 35-route flat table is not phone-shaped
/// navigation — this is a deliberate, reported UI adaptation (see
/// DAY_05.md section 10), not an invented pattern: bottom navigation for
/// the handful of destinations a cashier actually uses many times a shift
/// (Register, Tables, Tickets), and a "More" tab standing in for the
/// drawer's overflow items (Customers, Shifts, Settings, ...), which this
/// task and Days 6-10 will fill in incrementally. Destinations not yet
/// built by a completed day render `_ComingSoon`, clearly labelled with
/// which day owns them — never silently faked as finished.
class MobileShellScreen extends ConsumerWidget {
  const MobileShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final index = ref.watch(shellTabIndexProvider);
    final destinations = [
      (
        icon: Icons.point_of_sale_outlined,
        selectedIcon: Icons.point_of_sale,
        label: l10n.posDrawerRegister,
        // MODIFIED Day 6: real product grid/search/category filter (see
        // DAY_06.md). Cart itself (the other half of source's Register
        // screen) is still Day 7 — tapping a product acknowledges the tap
        // rather than actually adding to a cart that doesn't exist yet.
        body: const PosRegisterScreen(),
      ),
      (
        icon: Icons.table_bar_outlined,
        selectedIcon: Icons.table_bar,
        label: l10n.navTables,
        // MODIFIED Day 9: real table search/select (see DAY_09.md).
        body: const TablePickerScreen(),
      ),
      (
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        label: l10n.posDrawerHeldTickets,
        // MODIFIED Day 9: real held-ticket list/resume/delete.
        body: const HeldTicketsScreen(),
      ),
      (
        icon: Icons.more_horiz,
        selectedIcon: Icons.more_horiz,
        label: l10n.navMore,
        body: const _MoreTab(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(destinations[index].label)),
      body: IndexedStack(
        index: index,
        children: [for (final d in destinations) d.body],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) =>
            ref.read(shellTabIndexProvider.notifier).state = i,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

/// The "More" tab — a plain full-screen list, standing in for
/// `[OLD/SOURCE]` `PosDrawer`'s overflow items. Each entry is either a real
/// action (Logout — functional today) or a placeholder pointing at the day
/// that will implement it.
class _MoreTab extends ConsumerWidget {
  const _MoreTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final currentUser = ref.watch(currentUserProvider);

    return ListView(
      children: [
        if (currentUser != null)
          Padding(
            padding: const EdgeInsets.all(PosTheme.spacingLg),
            child: Text(
              currentUser.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: Text(l10n.navCustomers),
          // MODIFIED Day 9: opens the real customer picker.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const CustomerPickerScreen(),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text(l10n.navReceipts),
          // MODIFIED Day 12: opens the real receipt history screen
          // (search, status filters, refund) — reprint/save-PDF/email
          // stay pending until Day 13/15 build the printing pipeline.
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ReceiptsScreen()),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.schedule_outlined),
          title: Text(l10n.navShifts),
          // MODIFIED Day 10: opens the real shift management screen (Manage
          // Shift + Cash In/Out + Close, with Shift History reachable from
          // its AppBar).
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ShiftScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l10n.navSettings),
          subtitle: const Text('Not in this task\'s Day 4-10 scope'),
          onTap: () => _openComingSoon(
            context,
            'a later day (Settings is Day 19 scope)',
            l10n.navSettings,
          ),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: const Text('Theme / language demo'),
          subtitle: const Text('Day 3 verification screen'),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const ThemeDemoScreen()),
          ),
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: PosTheme.errorRed),
          title: Text(
            l10n.authLogout,
            style: TextStyle(color: PosTheme.errorRed),
          ),
          onTap: () => ref.read(authProvider.notifier).logout(),
        ),
      ],
    );
  }

  void _openComingSoon(BuildContext context, String day, String feature) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ComingSoon(day: day, feature: feature),
      ),
    );
  }
}

/// Explicit placeholder for a destination not yet built by an earlier day
/// in this task — never silently rendered as if it were the real screen.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.day, required this.feature});

  final String day;
  final String feature;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(feature)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(PosTheme.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 48,
                color: PosTheme.textHintOf(context),
              ),
              const SizedBox(height: PosTheme.spacingMd),
              Text(
                '$feature is not implemented yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: PosTheme.spacingSm),
              Text(
                'Planned for $day.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PosTheme.textSecondaryOf(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
