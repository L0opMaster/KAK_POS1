// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// import '../../../core/config/pos_theme.dart';
// import '../../../core/providers/auth_provider.dart';

// /// POS navigation drawer.
// class PosDrawer extends ConsumerWidget {
//   const PosDrawer({super.key});

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     return Drawer(
//       child: Column(
//         children: [
//           // ───────────────── Header ─────────────────
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//                 colors: [
//                   PosTheme.primaryGreen,
//                   PosTheme.primaryGreenDark,
//                 ],
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(4),
//                   decoration: const BoxDecoration(
//                     color: Colors.white24,
//                     shape: BoxShape.circle,
//                   ),
//                   child: const CircleAvatar(
//                     radius: 22,
//                     backgroundColor: Colors.white,
//                     child: Icon(
//                       Icons.point_of_sale,
//                       color: PosTheme.primaryGreen,
//                       size: 28,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 const Text(
//                   'Kaknnea POS',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 22,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Row(
//                   children: [
//                     Container(
//                       width: 8,
//                       height: 8,
//                       decoration: const BoxDecoration(
//                         color: Colors.greenAccent,
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                     const SizedBox(width: 6),
//                     Text(
//                       'Online · Cashier',
//                       style: TextStyle(
//                         color: Colors.white.withOpacity(0.85),
//                         fontSize: 15,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           // ───────────────── Navigation ─────────────────
//           Expanded(
//             child: ListView(
//               padding: EdgeInsets.zero,
//               children: [
//                 const SizedBox(height: 8),

//                 _navTile(
//                   icon: Icons.dashboard_rounded,
//                   title: 'Register',
//                   route: 'pos',
//                   context: context,
//                 ),

//                 _navTile(
//                   icon: Icons.history_rounded,
//                   title: 'Held Tickets',
//                   route: 'open-tickets',
//                   context: context,
//                 ),

//                 _navTile(
//                   icon: Icons.inventory_2_rounded,
//                   title: 'Stock Lookup',
//                   route: 'inventory',
//                   context: context,
//                 ),

//                 _navTile(
//                   icon: Icons.receipt_long_rounded,
//                   title: 'Receipts',
//                   route: 'receipts',
//                   context: context,
//                 ),

//                 // Clicking Reports expands its child menu.
//                 _reportsExpansionMenu(context),

//                 const SizedBox(height: 4),

//                 // Clicking Items expands its child menu.
//                 _itemsExpansionMenu(context),

//                 const SizedBox(height: 8),

//                 const Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 16),
//                   child: Divider(
//                     color: PosTheme.dividerColor,
//                   ),
//                 ),

//                 const SizedBox(height: 8),

//                 _navTile(
//                   icon: Icons.people_outline_rounded,
//                   title: 'Customers',
//                   route: 'customers',
//                   context: context,
//                 ),

//                 _navTile(
//                   icon: Icons.table_restaurant_rounded,
//                   title: 'Tables',
//                   route: 'tables',
//                   context: context,
//                 ),

//                 _navTile(
//                   icon: Icons.schedule_rounded,
//                   title: 'Shifts',
//                   route: 'shifts',
//                   context: context,
//                 ),

//                 const SizedBox(height: 8),

//                 const Padding(
//                   padding: EdgeInsets.symmetric(horizontal: 16),
//                   child: Divider(
//                     color: PosTheme.dividerColor,
//                   ),
//                 ),

//                 const SizedBox(height: 8),

//                 _navTile(
//                   icon: Icons.settings_outlined,
//                   title: 'Settings',
//                   route: 'settings',
//                   context: context,
//                 ),

//                 _logoutTile(context, ref),
//               ],
//             ),
//           ),

//           // ───────────────── Footer ─────────────────
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: const BoxDecoration(
//               border: Border(
//                 top: BorderSide(
//                   color: PosTheme.dividerColor,
//                 ),
//               ),
//             ),
//             child: const Row(
//               children: [
//                 Icon(
//                   Icons.store_outlined,
//                   size: 18,
//                   color: PosTheme.textHint,
//                 ),
//                 SizedBox(width: 8),
//                 Text(
//                   'Kaknnea Store',
//                   style: TextStyle(
//                     fontSize: 14,
//                     color: PosTheme.textHint,
//                   ),
//                 ),
//                 Spacer(),
//                 Text(
//                   'v1.0',
//                   style: TextStyle(
//                     fontSize: 13,
//                     color: PosTheme.textHint,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ───────────────── Reports expandable menu ─────────────────

//   Widget _reportsExpansionMenu(BuildContext context) {
//     return ExpansionTile(
//       key: const PageStorageKey<String>('reports-expansion-menu'),

//       // Reports is collapsed when first displayed.
//       initiallyExpanded: false,

//       leading: const Icon(
//         Icons.trending_up_rounded,
//         color: PosTheme.textPrimary,
//         size: 24,
//       ),

//       title: const Text(
//         'Reports',
//         style: TextStyle(
//           fontSize: 17,
//           fontWeight: FontWeight.w500,
//           color: PosTheme.textPrimary,
//         ),
//       ),

//       iconColor: PosTheme.primaryGreen,
//       collapsedIconColor: PosTheme.textHint,

//       tilePadding: const EdgeInsets.symmetric(
//         horizontal: 16,
//       ),

//       childrenPadding: const EdgeInsets.only(
//         left: 20,
//         right: 4,
//         bottom: 8,
//       ),

//       // Removes the default borders.
//       shape: const Border(),
//       collapsedShape: const Border(),

//       children: [
//         _subNavTile(
//           context: context,
//           icon: Icons.date_range_rounded,
//           title: 'Sales Summary',
//           route: 'report-sales-summary',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.inventory_rounded,
//           title: 'Sales by Item',
//           route: 'report-sales-by-item',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.category_rounded,
//           title: 'Sales by Category',
//           route: 'report-sales-by-category',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.person_rounded,
//           title: 'Sales by Employee',
//           route: 'report-sales-by-employee',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.payment_rounded,
//           title: 'Sales by Payment Type',
//           route: 'report-sales-by-payment-type',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.receipt_long_rounded,
//           title: 'Receipts',
//           route: 'report-receipts',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.tune_rounded,
//           title: 'Sales by Modifier',
//           route: 'report-sales-by-modifier',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.discount_rounded,
//           title: 'Discounts',
//           route: 'report-discounts',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.request_quote_rounded,
//           title: 'Taxes',
//           route: 'report-taxes',
//         ),
//       ],
//     );
//   }

//   // ───────────────── Items expandable menu ─────────────────

//   Widget _itemsExpansionMenu(BuildContext context) {
//     return ExpansionTile(
//       key: const PageStorageKey<String>('items-expansion-menu'),

//       // Items is collapsed when first displayed.
//       initiallyExpanded: false,

//       leading: const Icon(
//         Icons.sell_rounded,
//         color: PosTheme.textPrimary,
//         size: 24,
//       ),

//       title: const Text(
//         'Items',
//         style: TextStyle(
//           fontSize: 17,
//           fontWeight: FontWeight.w500,
//           color: PosTheme.textPrimary,
//         ),
//       ),

//       iconColor: PosTheme.primaryGreen,
//       collapsedIconColor: PosTheme.textHint,

//       tilePadding: const EdgeInsets.symmetric(
//         horizontal: 16,
//       ),

//       childrenPadding: const EdgeInsets.only(
//         left: 20,
//         right: 4,
//         bottom: 8,
//       ),

//       // Removes the default borders.
//       shape: const Border(),
//       collapsedShape: const Border(),

//       children: [
//         _subNavTile(
//           context: context,
//           icon: Icons.list_alt_rounded,
//           title: 'Item List',
//           route: 'items',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.add_box_outlined,
//           title: 'Add Item',
//           route: 'add-item',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.category_outlined,
//           title: 'Categories',
//           route: 'categories',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.tune_rounded,
//           title: 'Modifiers',
//           route: 'modifiers',
//         ),
//         _subNavTile(
//           context: context,
//           icon: Icons.straighten_rounded,
//           title: 'Units',
//           route: 'units',
//         ),
//       ],
//     );
//   }

//   // ───────────────── Normal navigation item ─────────────────

//   Widget _navTile({
//     required IconData icon,
//     required String title,
//     required String route,
//     required BuildContext context,
//     Color? color,
//   }) {
//     final tileColor = color ?? PosTheme.textPrimary;

//     return ListTile(
//       leading: Icon(
//         icon,
//         color: tileColor,
//         size: 24,
//       ),
//       title: Text(
//         title,
//         style: TextStyle(
//           fontSize: 17,
//           fontWeight: FontWeight.w500,
//           color: tileColor,
//         ),
//       ),
//       trailing: const Icon(
//         Icons.chevron_right,
//         size: 20,
//         color: PosTheme.textHint,
//       ),
//       onTap: () {
//         final navigator = Navigator.of(context);

//         // Close the drawer.
//         // navigator.pop();

//         if (route.isNotEmpty) {
//           navigator.pushNamed('/$route');
//         }
//       },
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),
//       contentPadding: const EdgeInsets.symmetric(
//         horizontal: 16,
//       ),
//       horizontalTitleGap: 12,
//       dense: true,
//     );
//   }

//   // child navigation item

//   Widget _subNavTile({
//     required BuildContext context,
//     required IconData icon,
//     required String title,
//     required String route,
//   }) {
//     return ListTile(
//       leading: Icon(
//         icon,
//         size: 21,
//         color: PosTheme.textHint,
//       ),
//       title: Text(
//         title,
//         style: const TextStyle(
//           fontSize: 16,
//           fontWeight: FontWeight.w400,
//           color: PosTheme.textPrimary,
//         ),
//       ),
//       trailing: const Icon(
//         Icons.chevron_right,
//         size: 18,
//         color: PosTheme.textHint,
//       ),
//       dense: true,
//       horizontalTitleGap: 10,
//       contentPadding: const EdgeInsets.only(
//         left: 20,
//         right: 16,
//       ),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),
//       // onTap: () {
//       //   final navigator = Navigator.of(context);

//       //   // Close the drawer.
//       //   navigator.pop();

//       //   // Navigate to the selected child page.
//       //   navigator.pushNamed('/$route');
//       // },

//       onTap: () async {
//         final navigator = Navigator.of(context);

//         // Do not close the drawer here.
//         await navigator.pushNamed('/$route');

//         // After pressing Back, the previous drawer remains open.
//       },
//     );
//   }

//   // ───────────────── Logout ─────────────────

//   Widget _logoutTile(
//     BuildContext context,
//     WidgetRef ref,
//   ) {
//     return ListTile(
//       leading: const Icon(
//         Icons.logout_rounded,
//         color: PosTheme.errorRed,
//         size: 24,
//       ),
//       title: const Text(
//         'Logout',
//         style: TextStyle(
//           fontSize: 17,
//           fontWeight: FontWeight.w500,
//           color: PosTheme.errorRed,
//         ),
//       ),
//       trailing: const Icon(
//         Icons.chevron_right,
//         size: 20,
//         color: PosTheme.textHint,
//       ),
//       onTap: () async {
//         final authNotifier = ref.read(authProvider.notifier);
//         final navigator = Navigator.of(context);

//         final confirmed = await showDialog<bool>(
//           context: context,
//           builder: (dialogContext) {
//             return AlertDialog(
//               title: const Text('Logout'),
//               content: const Text(
//                 'Are you sure you want to logout?',
//               ),
//               actions: [
//                 TextButton(
//                   onPressed: () {
//                     Navigator.of(dialogContext).pop(false);
//                   },
//                   child: const Text('Cancel'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(dialogContext).pop(true);
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: PosTheme.errorRed,
//                     foregroundColor: Colors.white,
//                   ),
//                   child: const Text('Logout'),
//                 ),
//               ],
//             );
//           },
//         );

//         if (confirmed != true) {
//           return;
//         }

//         await authNotifier.logout();

//         if (!navigator.mounted) {
//           return;
//         }

//         navigator.pushNamedAndRemoveUntil(
//           '/login',
//           (route) => false,
//         );
//       },
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),
//       contentPadding: const EdgeInsets.symmetric(
//         horizontal: 16,
//       ),
//       horizontalTitleGap: 12,
//       dense: true,
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/config/currency_utils.dart';
import '../../../core/config/pos_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/company_provider.dart';
import '../../../core/services/printing/a4_report_pdf.dart';
import '../../../core/utils/l10n_extensions.dart';
import '../../reports/models/report_models.dart';
import '../../reports/services/report_service.dart';
import '../services/settings_service.dart';

/// POS navigation drawer.
class PosDrawer extends ConsumerWidget {
  const PosDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      child: Column(
        children: [
          // ───────────────── Header ─────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  PosTheme.primaryGreen,
                  PosTheme.primaryGreenDark,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.point_of_sale,
                      color: PosTheme.primaryGreen,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  // Live business name from Settings → Company Profile —
                  // see core/providers/company_provider.dart. Falls back
                  // to the generic app name while loading/offline/unset.
                  watchCompanyName(ref,
                      fallback:
                          '${context.l10n.appName} ${context.l10n.navPos}'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.posDrawerOnlineStatus,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ───────────────── Navigation ─────────────────
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 8),

                _navTile(
                  icon: Icons.dashboard_rounded,
                  title: context.l10n.posDrawerRegister,
                  route: 'pos',
                  context: context,
                ),

                _navTile(
                  icon: Icons.history_rounded,
                  title: context.l10n.posDrawerHeldTickets,
                  route: 'open-tickets',
                  context: context,
                ),

                // Clicking Inventory Management expands its child menu.
                _inventoryManagementExpansionMenu(context),

                const SizedBox(height: 4),

                _navTile(
                  icon: Icons.receipt_long_rounded,
                  title: context.l10n.navReceipts,
                  route: 'receipts',
                  context: context,
                  // trailingAction: IconButton(
                  //   icon: const Icon(Icons.print_outlined, size: 20),
                  //   tooltip: context.l10n.commonPrint,
                  //   color: PosTheme.textHintOf(context),
                  //   onPressed: () => _quickPrintReceipts(context, ref),
                  // ),
                ),

                // Clicking Reports expands its child menu.
                _reportsExpansionMenu(context),

                const SizedBox(height: 4),

                // Clicking Items expands its child menu.
                _itemsExpansionMenu(context),

                const SizedBox(height: 4),

                _employeesExpansionMenu(context),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: PosTheme.dividerColorOf(context),
                  ),
                ),

                const SizedBox(height: 8),

                // Clicking Customers expands its child menu.
                _customersExpansionMenu(context),

                // _navTile(icon: Icons.emoji_people_sharp, title: 'Employees', route: '', context: context)

                // Clicking Tables expands its child menu.
                _tablesExpansionMenu(context),

                // Clicking Shifts expands its child menu.
                _shiftsExpansionMenu(context),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(
                    color: PosTheme.dividerColorOf(context),
                  ),
                ),

                const SizedBox(height: 8),

                _navTile(
                  icon: Icons.settings_outlined,
                  title: context.l10n.navSettings,
                  route: 'settings',
                  context: context,
                ),

                _logoutTile(context, ref),
              ],
            ),
          ),

          // ───────────────── Footer ─────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: PosTheme.dividerColorOf(context),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.store_outlined,
                  size: 18,
                  color: PosTheme.textHintOf(context),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.posDrawerStoreName,
                  style: TextStyle(
                    fontSize: 14,
                    color: PosTheme.textHintOf(context),
                  ),
                ),
                const Spacer(),
                Text(
                  'v1.0',
                  style: TextStyle(
                    fontSize: 13,
                    color: PosTheme.textHintOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────── Quick print (Receipts) ─────────────────

  /// Print shortcut on the Receipts drawer tile: prints today's receipts as
  /// an A4 PDF directly, without navigating into the full Receipts screen
  /// first. Walks every backend page for the query (see report_service.dart
  /// `fetchAllPages`) instead of trusting a single page of results, for the
  /// same reason SalesReportScreen's own print button does — a report with
  /// more receipts than one backend page must never silently drop rows.
  Future<void> _quickPrintReceipts(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final today = fmt(now);

    try {
      final svc = ref.read(reportServiceProvider);
      final company =
          await ref.read(settingsServiceProvider).getCompanyProfile();
      final cur = currencySymbol(readCurrency(ref));

      SalesReportSummary? summary;
      final allSales = await fetchAllPages<SalesDetail>(
        fetchPage: (page) async {
          final pageData = await svc.salesReport(
            from: today,
            to: today,
            page: page,
            size: reportPrintPageSize,
          );
          summary ??= pageData.summary;
          return (pageData.sales, pageData.salesMeta);
        },
      );

      final rows = allSales
          .map((sale) => [
                sale.saleNumber ?? '#${sale.saleId}',
                sale.saleDate ?? '',
                sale.cashierName ?? '',
                sale.paymentMethod ?? '',
                '$cur${sale.netAmount.toStringAsFixed(2)}',
              ])
          .toList();

      final pdfBytes = await A4ReportPdf.build(
        title: l10n.navReceipts,
        subtitle: today,
        businessName: '${company['businessName'] ?? ''}',
        businessAddress: '${company['address'] ?? ''}',
        businessPhone: '${company['phone'] ?? ''}',
        columns: const ['Receipt #', 'Date', 'Cashier', 'Payment', 'Net'],
        rows: rows,
        columnAlignments: const {4: pw.Alignment.centerRight},
        summary: summary == null
            ? const []
            : [MapEntry('Transactions', '${summary!.totalSalesCount}')],
        generatedAt: now,
        generatedLabel: l10n.reportPdfGeneratedLabel,
        pageLabel: l10n.reportPdfPageLabel,
      );

      await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: 'receipts');
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('${l10n.printerPrintFailed}: $e')));
    }
  }

  // ───────────────── Reports expandable menu ─────────────────

  Widget _reportsExpansionMenu(BuildContext context) {
    return ExpansionTile(
      key: const PageStorageKey<String>('reports-expansion-menu'),

      // Reports is collapsed when first displayed.
      initiallyExpanded: false,

      leading: Icon(
        Icons.trending_up_rounded,
        color: PosTheme.textPrimaryOf(context),
        size: 24,
      ),

      title: Text(
        context.l10n.navReports,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),

      iconColor: PosTheme.primaryGreen,
      collapsedIconColor: PosTheme.textHintOf(context),

      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding: const EdgeInsets.only(
        left: 20,
        right: 4,
        bottom: 8,
      ),

      // Removes the default borders.
      shape: const Border(),
      collapsedShape: const Border(),

      children: [
        _subNavTile(
          context: context,
          icon: Icons.date_range_rounded,
          title: context.l10n.reportsSalesSummary,
          route: 'report-sales-summary',
        ),
        _subNavTile(
          context: context,
          icon: Icons.inventory_rounded,
          title: context.l10n.reportsSalesByItem,
          route: 'report-sales-by-item',
        ),
        _subNavTile(
          context: context,
          icon: Icons.category_rounded,
          title: context.l10n.reportsSalesByCategory,
          route: 'report-sales-by-category',
        ),
        _subNavTile(
          context: context,
          icon: Icons.person_rounded,
          title: context.l10n.posDrawerSalesByCashier,
          route: 'report-sales-by-employee',
        ),
        _subNavTile(
          context: context,
          icon: Icons.payment_rounded,
          title: context.l10n.reportsSalesByPaymentType,
          route: 'report-sales-by-payment-type',
        ),
        _subNavTile(
          context: context,
          icon: Icons.receipt_long_rounded,
          title: context.l10n.navReceipts,
          route: 'report-receipts',
        ),
        _subNavTile(
          context: context,
          icon: Icons.tune_rounded,
          title: context.l10n.posDrawerSalesByModifier,
          route: 'report-sales-by-modifier',
        ),
        _subNavTile(
          context: context,
          icon: Icons.discount_rounded,
          title: context.l10n.reportsDiscounts,
          route: 'report-discounts',
        ),
        _subNavTile(
          context: context,
          icon: Icons.request_quote_rounded,
          title: context.l10n.reportsTaxes,
          route: 'report-taxes',
        ),
      ],
    );
  }

  // ───────────────── Items expandable menu ─────────────────

  Widget _itemsExpansionMenu(BuildContext context) {
    return ExpansionTile(
      key: const PageStorageKey<String>('items-expansion-menu'),

      // Items is collapsed when first displayed.
      initiallyExpanded: false,

      leading: Icon(
        Icons.sell_rounded,
        color: PosTheme.textPrimaryOf(context),
        size: 24,
      ),

      title: Text(
        context.l10n.navItems,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),

      iconColor: PosTheme.primaryGreen,
      collapsedIconColor: PosTheme.textHintOf(context),

      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding: const EdgeInsets.only(
        left: 20,
        right: 4,
        bottom: 8,
      ),

      // Removes the default borders.
      shape: const Border(),
      collapsedShape: const Border(),

      children: [
        _subNavTile(
          context: context,
          icon: Icons.list_alt_rounded,
          title: context.l10n.posDrawerItemList,
          route: 'items',
        ),
        _subNavTile(
          context: context,
          icon: Icons.add_box_outlined,
          title: context.l10n.posDrawerAddItem,
          route: 'add-item',
        ),
        _subNavTile(
          context: context,
          icon: Icons.category_outlined,
          title: context.l10n.navCategories,
          route: 'categories',
        ),
        _subNavTile(
          context: context,
          icon: Icons.tune_rounded,
          title: context.l10n.posDrawerModifiers,
          route: 'modifiers',
        ),
        _subNavTile(
          context: context,
          icon: Icons.straighten_rounded,
          title: context.l10n.posDrawerUnits,
          route: 'units',
        ),
      ],
    );
  }
  //  ───────────────── Customers expandable menu ─────────────────

  Widget _customersExpansionMenu(BuildContext context) {
    return ExpansionTile(
      key: const PageStorageKey<String>('customers-expansion-menu'),
      initiallyExpanded: false,
      leading: Icon(
        Icons.people_outline_rounded,
        color: PosTheme.textPrimaryOf(context),
        size: 24,
      ),
      title: Text(
        context.l10n.navCustomers,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),

      iconColor: PosTheme.primaryGreen,
      collapsedIconColor: PosTheme.textHintOf(context),

      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding: const EdgeInsets.only(
        left: 20,
        right: 4,
        bottom: 8,
      ),

      // Removes the default borders.
      shape: const Border(),
      collapsedShape: const Border(),

      children: [
        _subNavTile(
          context: context,
          icon: Icons.list_alt_rounded,
          title: context.l10n.posDrawerCustomerList,
          route: 'customers',
        ),
        _subNavTile(
          context: context,
          icon: Icons.person_add_alt_1_rounded,
          title: context.l10n.posDrawerAddCustomer,
          route: 'add-customer',
        ),
      ],
    );
  }

  //  ───────────────── Tables expandable menu ─────────────────

  Widget _tablesExpansionMenu(BuildContext context) {
    return ExpansionTile(
      key: const PageStorageKey<String>('tables-expansion-menu'),
      initiallyExpanded: false,
      leading: Icon(
        Icons.table_restaurant_rounded,
        color: PosTheme.textPrimaryOf(context),
        size: 24,
      ),
      title: Text(
        context.l10n.navTables,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),

      iconColor: PosTheme.primaryGreen,
      collapsedIconColor: PosTheme.textHintOf(context),

      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding: const EdgeInsets.only(
        left: 20,
        right: 4,
        bottom: 8,
      ),

      // Removes the default borders.
      shape: const Border(),
      collapsedShape: const Border(),

      children: [
        _subNavTile(
          context: context,
          icon: Icons.list_alt_rounded,
          title: context.l10n.posDrawerTableList,
          route: 'tables',
        ),
        _subNavTile(
          context: context,
          icon: Icons.add_box_outlined,
          title: context.l10n.posDrawerAddTable,
          route: 'add-table',
        ),
      ],
    );
  }

  //  ───────────────── Shifts expandable menu ─────────────────

  Widget _shiftsExpansionMenu(BuildContext context) {
    return ExpansionTile(
      key: const PageStorageKey<String>('shifts-expansion-menu'),
      initiallyExpanded: false,
      leading: Icon(
        Icons.schedule_rounded,
        color: PosTheme.textPrimaryOf(context),
        size: 24,
      ),
      title: Text(
        context.l10n.navShifts,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),

      iconColor: PosTheme.primaryGreen,
      collapsedIconColor: PosTheme.textHintOf(context),

      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding: const EdgeInsets.only(
        left: 20,
        right: 4,
        bottom: 8,
      ),

      // Removes the default borders.
      shape: const Border(),
      collapsedShape: const Border(),

      children: [
        _subNavTile(
          context: context,
          icon: Icons.lock_open_rounded,
          title: context.l10n.posDrawerManageShift,
          route: 'shifts',
        ),
        _subNavTile(
          context: context,
          icon: Icons.history_rounded,
          title: context.l10n.posDrawerShiftHistory,
          route: 'shift-history',
        ),
      ],
    );
  }

  //  ───────────────── Inventory Management expandable menu ─────────────────

  Widget _inventoryManagementExpansionMenu(BuildContext context) {
    return ExpansionTile(
      key: const PageStorageKey<String>('inventory-management-expansion-menu'),
      initiallyExpanded: false,
      leading: Icon(
        Icons.inventory_2_rounded,
        color: PosTheme.textPrimaryOf(context),
        size: 24,
      ),
      title: Text(
        context.l10n.posDrawerInventoryManagement,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),

      iconColor: PosTheme.primaryGreen,
      collapsedIconColor: PosTheme.textHintOf(context),

      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding: const EdgeInsets.only(
        left: 20,
        right: 4,
        bottom: 8,
      ),

      // Removes the default borders.
      shape: const Border(),
      collapsedShape: const Border(),

      children: [
        _subNavTile(
          context: context,
          icon: Icons.search_rounded,
          title: context.l10n.posDrawerStockLookup,
          route: 'inventory',
        ),
        _subNavTile(
          context: context,
          icon: Icons.shopping_cart_outlined,
          title: context.l10n.posDrawerPurchaseOrders,
          route: 'purchase-orders',
        ),
        _subNavTile(
          context: context,
          icon: Icons.swap_horiz_rounded,
          title: context.l10n.posDrawerTransferOrders,
          route: 'transfer-orders',
        ),
        _subNavTile(
          context: context,
          icon: Icons.tune_rounded,
          title: context.l10n.posDrawerStockAdjustments,
          route: 'stock-adjustments',
        ),
        _subNavTile(
          context: context,
          icon: Icons.playlist_add_check_rounded,
          title: context.l10n.posDrawerInventoryCounts,
          route: 'inventory-counts',
        ),
        _subNavTile(
          context: context,
          icon: Icons.precision_manufacturing_outlined,
          title: context.l10n.posDrawerProductions,
          route: 'productions',
        ),
        _subNavTile(
          context: context,
          icon: Icons.local_shipping_outlined,
          title: context.l10n.posDrawerSuppliers,
          route: 'suppliers',
        ),
        _subNavTile(
          context: context,
          icon: Icons.history_rounded,
          title: context.l10n.posDrawerInventoryHistory,
          route: 'inventory-history',
        ),
        _subNavTile(
          context: context,
          icon: Icons.attach_money_rounded,
          title: context.l10n.posDrawerInventoryValuation,
          route: 'inventory-valuation',
        ),
      ],
    );
  }

  //  ───────────────── Employees expandable menu ─────────────────

  Widget _employeesExpansionMenu(BuildContext context) {
    return ExpansionTile(
      key: const PageStorageKey<String>('employees-expansion-menu'),
      initiallyExpanded: false,
      leading: Icon(
        Icons.assignment_ind,
        color: PosTheme.textPrimaryOf(context),
        size: 24,
      ),
      title: Text(
        context.l10n.posDrawerEmployees,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),

      iconColor: PosTheme.primaryGreen,
      collapsedIconColor: PosTheme.textHintOf(context),

      tilePadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),

      childrenPadding: const EdgeInsets.only(
        left: 20,
        right: 4,
        bottom: 8,
      ),

      // Removes the default borders.
      shape: const Border(),
      collapsedShape: const Border(),

      children: [
        _subNavTile(
            icon: Icons.toc_rounded,
            title: context.l10n.posDrawerEmployeesList,
            route: 'employeelist',
            context: context),
        _subNavTile(
            context: context,
            icon: Icons.account_box,
            title: context.l10n.posDrawerUserAccount,
            route: 'useraccount'),
        _subNavTile(
            context: context,
            icon: Icons.accessibility_new,
            title: context.l10n.posDrawerRole,
            route: 'accessRole'),
        _subNavTile(
            context: context,
            icon: Icons.paste_rounded,
            title: context.l10n.posDrawerPermission,
            route: 'permission'),
      ],
    );
  }

  // ───────────────── Normal navigation item ─────────────────

  Widget _navTile({
    required IconData icon,
    required String title,
    required String route,
    required BuildContext context,
    Color? color,
    Widget? trailingAction,
  }) {
    final tileColor = color ?? PosTheme.textPrimaryOf(context);

    return ListTile(
      leading: Icon(
        icon,
        color: tileColor,
        size: 24,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: tileColor,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingAction != null) trailingAction,
          Icon(
            Icons.chevron_right,
            size: 20,
            color: PosTheme.textHintOf(context),
          ),
        ],
      ),
      onTap: () {
        final navigator = Navigator.of(context);

        // Close the drawer.
        navigator.pop();

        if (route.isNotEmpty) {
          navigator.pushNamed('/$route');
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      horizontalTitleGap: 12,
      dense: true,
    );
  }

  // child navigation item

  Widget _subNavTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        size: 21,
        color: PosTheme.textHintOf(context),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: PosTheme.textPrimaryOf(context),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: PosTheme.textHintOf(context),
      ),
      dense: true,
      horizontalTitleGap: 10,
      contentPadding: const EdgeInsets.only(
        left: 20,
        right: 16,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      // onTap: () {
      //   final navigator = Navigator.of(context);

      //   // Close the drawer.
      //   navigator.pop();

      //   // Navigate to the selected child page.
      //   navigator.pushNamed('/$route');
      // },

      onTap: () async {
        final navigator = Navigator.of(context);

        // Do not close the drawer here.
        await navigator.pushNamed('/$route');

        // After pressing Back, the previous drawer remains open.
      },
    );
  }

  // ───────────────── Logout ─────────────────

  Widget _logoutTile(
    BuildContext context,
    WidgetRef ref,
  ) {
    return ListTile(
      leading: const Icon(
        Icons.logout_rounded,
        color: PosTheme.errorRed,
        size: 24,
      ),
      title: Text(
        context.l10n.authLogout,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w500,
          color: PosTheme.errorRed,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: PosTheme.textHintOf(context),
      ),
      onTap: () async {
        final authNotifier = ref.read(authProvider.notifier);
        final navigator = Navigator.of(context);

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(context.l10n.authLogout),
              content: Text(
                context.l10n.posDrawerLogoutConfirm,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: Text(context.l10n.commonCancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PosTheme.errorRed,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(context.l10n.authLogout),
                ),
              ],
            );
          },
        );

        if (confirmed != true) {
          return;
        }

        await authNotifier.logout();

        if (!navigator.mounted) {
          return;
        }

        navigator.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      horizontalTitleGap: 12,
      dense: true,
    );
  }
}
