import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend_flutter_pos/features/pos/screens/create_modifier.dart';
import 'package:frontend_flutter_pos/features/pos/screens/employee_management_screen.dart';
import 'package:frontend_flutter_pos/features/pos/screens/user_account_screen.dart';
import 'package:frontend_flutter_pos/features/pos/screens/role_management_screen.dart';
import 'package:frontend_flutter_pos/features/pos/screens/permission_screen.dart';
import 'package:frontend_flutter_pos/features/pos/screens/modifier_management.dart';
import 'package:frontend_flutter_pos/features/pos/screens/phone_screen_scan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'core/config/pos_theme.dart';
import 'core/models/auth_models.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/language_provider.dart';
import 'core/providers/main_color_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/services/api_service.dart';
import 'core/utils/khmer_text_scaler.dart';
import 'l10n/generated/app_localizations.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/pos/screens/pos_screen.dart';
import 'features/pos/screens/settings_modules_screen.dart';
import 'features/pos/screens/pos_settings_screen.dart';
import 'features/pos/screens/customer_management_screen.dart';
import 'features/pos/screens/open_ticket_page.dart';
import 'features/pos/screens/receipts_screen.dart';
import 'features/pos/screens/shift_history_screen.dart';
import 'features/pos/screens/shift_screen.dart';
import 'features/pos/screens/table_management_screen.dart';
import 'features/pos/screens/create_table.dart';
import 'features/pos/screens/item_management_screen.dart';
import 'features/pos/screens/category_management_screen.dart';
import 'features/pos/screens/unit_management_screen.dart';
import 'features/inventory/screens/inventory_hub_screen.dart';
import 'features/inventory/screens/purchase_orders_screen.dart';
import 'features/inventory/screens/transfer_orders_screen.dart';
import 'features/inventory/screens/stock_adjustments_screen.dart';
import 'features/inventory/screens/inventory_counts_screen.dart';
import 'features/inventory/screens/productions_screen.dart';
import 'features/inventory/screens/suppliers_screen.dart';
import 'features/inventory/screens/inventory_history_screen.dart';
import 'features/inventory/screens/inventory_valuation_screen.dart';
import 'features/reports/screens/reports_hub_screen.dart';
import 'features/reports/screens/sales_summary_report_screen.dart';
import 'features/reports/screens/sales_by_item_screen.dart';
import 'features/reports/screens/category_performance_screen.dart';
import 'features/reports/screens/cashier_performance_screen.dart';
import 'features/reports/screens/payment_mix_screen.dart';
import 'features/reports/screens/sales_report_screen.dart';
import 'features/reports/screens/sales_by_modifier_screen.dart';
import 'features/reports/screens/discounts_screen.dart';
import 'features/reports/screens/taxes_screen.dart';
import 'features/pos/services/printing/khmer_pdf_font.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  // OFFLINE: pre-warm the SharedPreferences singleton (it's just a cached
  // plugin instance under the hood) so every OFFLINE read that happens
  // during startup — auth_service.dart's session check, cart_provider.dart's
  // restoreCart(), table_selection_provider.dart's load, etc. — is instant
  // instead of paying the first-call initialization cost.
  await SharedPreferences.getInstance();
  // Printing: both of these cache themselves after the first call anyway
  // (KhmerPdfFont.loadTheme's static Font fields; esc_pos_utils_plus's own
  // internal capabilities map) — firing them here, unawaited, moves that
  // one-time cost to app launch instead of the cashier's first Khmer
  // print/receipt of the day. Never awaited and never allowed to throw:
  // printing must still work even if this prewarm fails or is still in
  // flight when the first real print happens (loadTheme/load() just run
  // again on demand in that case).
  unawaited(_prewarmPrinting());
  runApp(const ProviderScope(child: PosApp()));
}

Future<void> _prewarmPrinting() async {
  try {
    await KhmerPdfFont.loadTheme();
    await CapabilityProfile.load();
  } catch (_) {
    // Printing must still work on demand even if this prewarm fails —
    // loadTheme()/load() simply run again the first time a real print
    // needs them.
  }
}

class PosApp extends ConsumerWidget {
  const PosApp({super.key});

  @override
  Widget build(final BuildContext context, final WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // ONLINE-triggered, OFFLINE cleanup: wires up ApiService's 401
    // interceptor (core/services/api_service.dart) — fired whenever any
    // ONLINE request gets rejected by the backend — to authProvider's
    // logout, which clears the OFFLINE cached session (see
    // auth_service.dart's `logout()`) so the app returns to the login
    // screen instead of holding a dead token.
    ApiService.onUnauthorized = () => ref.read(authProvider.notifier).logout();

    // Settings > Main Color: PosTheme.primaryGreen/Dark/Light are computed
    // getters (see pos_theme.dart), not consts — every existing call site
    // across the app reading them picks up this value with no other wiring
    // needed. Applying it here, right before theme construction, on every
    // build (this widget already rebuilds on provider change via the
    // ref.watch below) keeps PosTheme's mutable field and the provider's
    // persisted state in sync with a single, one-directional write.
    PosTheme.applyMainColor(ref.watch(mainColorProvider));
    final isKhmer = ref.watch(appLanguageProvider).isKhmer;

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: PosTheme.lightTheme,
      darkTheme: PosTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider).value,
      locale: ref.watch(appLanguageProvider).toLocale(),
      // Khmer text ~2-3px larger app-wide (see khmer_text_scaler.dart) —
      // applied on top of the platform's existing text-scale setting, and
      // scoped to the Flutter widget tree only, so it can never reach
      // receipt/PDF/thermal print output (a completely separate
      // package:pdf rendering path with its own literal font sizes).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: khmerAwareTextScaler(
            MediaQuery.of(context).textScaler,
            isKhmer: isKhmer,
          ),
        ),
        child: child!,
      ),
      supportedLocales: const [Locale('en'), Locale('km')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routes: <String, WidgetBuilder>{
        '/login': (context) => const LoginScreen(),
        '/pos': (final BuildContext context) => const PosScreen(),
        '/settings': (final BuildContext context) =>
            const SettingsModulesScreen(),
        '/pos-settings': (final BuildContext context) =>
            const PosSettingsScreen(),
        '/customers': (final BuildContext context) =>
            const CustomerManagementScreen(),
        '/add-customer': (final BuildContext context) =>
            const CustomerFormScreen(),
        '/open-tickets': (final BuildContext context) => const OpenTicketPage(),
        '/receipts': (final BuildContext context) => const ReceiptsScreen(),
        '/shifts': (final BuildContext context) => const ShiftScreen(),
        '/shift-history': (final BuildContext context) =>
            const ShiftHistoryScreen(),
        '/tables': (final BuildContext context) =>
            const TableManagementScreen(),
        '/add-table': (final BuildContext context) => const CreateTable(),
        // ── Item management (full CRUD) ──
        '/items': (final BuildContext context) => const ItemManagementScreen(),
        '/add-item': (final BuildContext context) => const ProductFormScreen(
              isEdit: false,
            ),
        '/categories': (final BuildContext context) =>
            const CategoryManagementScreen(),
        '/modifiers': (final BuildContext context) =>
            const ModifierManagement(),
        '/create-modifier': (final BuildContext context) =>
            const CreateModifier(),
        '/units': (final BuildContext context) => const UnitManagementScreen(),
        // ── Inventory Management ──
        '/inventory': (final BuildContext context) =>
            const InventoryHubScreen(),
        '/purchase-orders': (final BuildContext context) =>
            const PurchaseOrdersScreen(),
        '/transfer-orders': (final BuildContext context) =>
            const TransferOrdersScreen(),
        '/stock-adjustments': (final BuildContext context) =>
            const StockAdjustmentsScreen(),
        '/inventory-counts': (final BuildContext context) =>
            const InventoryCountsScreen(),
        '/productions': (final BuildContext context) =>
            const ProductionsScreen(),
        '/suppliers': (final BuildContext context) => const SuppliersScreen(),
        '/inventory-history': (final BuildContext context) =>
            const InventoryHistoryScreen(),
        '/inventory-valuation': (final BuildContext context) =>
            const InventoryValuationScreen(),
        // ── Reports ──
        '/reports': (final BuildContext context) => const ReportsHubScreen(),
        '/report-sales-summary': (final BuildContext context) =>
            const SalesSummaryReportScreen(),
        '/report-sales-by-item': (final BuildContext context) =>
            const SalesByItemScreen(),
        '/report-sales-by-category': (final BuildContext context) =>
            const CategoryPerformanceScreen(),
        '/report-sales-by-employee': (final BuildContext context) =>
            const CashierPerformanceScreen(),
        '/report-sales-by-payment-type': (final BuildContext context) =>
            const PaymentMixScreen(),
        '/report-receipts': (final BuildContext context) =>
            const SalesReportScreen(),
        '/report-sales-by-modifier': (final BuildContext context) =>
            const SalesByModifierScreen(),
        '/report-discounts': (final BuildContext context) =>
            const DiscountsScreen(),
        '/report-taxes': (final BuildContext context) => const TaxesScreen(),

        // --- employee ---
        '/employeelist': (final BuildContext context) =>
            const EmployeeManagementScreen(),
        '/useraccount': (final BuildContext context) =>
            const UserAccountScreen(),
        '/accessRole': (final BuildContext context) =>
            const RoleManagementScreen(),
        '/permission': (final BuildContext context) => const PermissionScreen(),
      },
      // home: const PhoneScannerScreen(),
      home: authState.maybeWhen(
        data: (final User? user) =>
            user != null ? const PosScreen() : const LoginScreen(),
        orElse: () => const LoginScreen(),
      ),
    );
  }
}
